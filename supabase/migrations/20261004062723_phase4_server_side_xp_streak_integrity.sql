-- Phase 4: server-side XP / streak integrity.
-- XP, level, streak and CO2-saved columns on public.users can no longer be written
-- directly by clients. They change only through the SECURITY DEFINER functions below,
-- which validate inputs, use the server date, and make every award idempotent.

-- 1. XP ledger: one row per award (idempotency + audit trail).
CREATE TABLE IF NOT EXISTS public.xp_ledger (
  id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id     uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  source      text NOT NULL CHECK (source IN ('daily_log','streak_milestone','quiz','challenge')),
  source_key  text NOT NULL,
  amount      integer NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, source, source_key)
);
CREATE INDEX IF NOT EXISTS idx_xp_ledger_user ON public.xp_ledger (user_id, created_at DESC);
ALTER TABLE public.xp_ledger ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users view own xp ledger" ON public.xp_ledger;
CREATE POLICY "Users view own xp ledger" ON public.xp_ledger
  FOR SELECT TO authenticated USING (auth.uid() = user_id);
REVOKE ALL ON public.xp_ledger FROM anon, PUBLIC, authenticated;
GRANT SELECT ON public.xp_ledger TO authenticated;

-- Backfill existing daily-log XP so re-saving an old log does not double count.
INSERT INTO public.xp_ledger (user_id, source, source_key, amount)
SELECT user_id, 'daily_log', (date::date)::text, COALESCE(xp_earned, 0)
FROM public.daily_logs
ON CONFLICT (user_id, source, source_key) DO NOTHING;

-- 2. Level thresholds (mirror GamificationEngine.xpThresholds).
CREATE OR REPLACE FUNCTION public._level_for_xp(p_xp int)
RETURNS int LANGUAGE sql IMMUTABLE SET search_path = public AS $$
  SELECT COUNT(*)::int FROM unnest(ARRAY[0,500,1500,3000,5000,8000,12000,17000,23000,31000]) t
  WHERE t <= GREATEST(COALESCE(p_xp, 0), 0);
$$;

-- 3. Internal: apply an XP award idempotently. Not callable by clients.
CREATE OR REPLACE FUNCTION public._apply_xp(
  p_user uuid, p_source text, p_key text, p_amount int, p_replace boolean
) RETURNS int LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_old int; v_delta int;
BEGIN
  SELECT amount INTO v_old FROM public.xp_ledger
   WHERE user_id = p_user AND source = p_source AND source_key = p_key FOR UPDATE;
  IF NOT FOUND THEN
    INSERT INTO public.xp_ledger (user_id, source, source_key, amount)
    VALUES (p_user, p_source, p_key, p_amount);
    v_delta := p_amount;
  ELSIF p_replace THEN
    UPDATE public.xp_ledger SET amount = p_amount, updated_at = now()
     WHERE user_id = p_user AND source = p_source AND source_key = p_key;
    v_delta := p_amount - v_old;
  ELSE
    RETURN 0;
  END IF;

  IF v_delta <> 0 THEN
    UPDATE public.users u
       SET lifetime_xp = n.v,
           xp          = n.v,
           monthly_xp  = GREATEST(0, COALESCE(u.monthly_xp, 0) + v_delta),
           level       = public._level_for_xp(n.v),
           updated_at  = now()
      FROM (
        SELECT GREATEST(0, (CASE WHEN COALESCE(lifetime_xp, 0) > 0 THEN lifetime_xp ELSE COALESCE(xp, 0) END) + v_delta) AS v
          FROM public.users WHERE id = p_user
      ) n
     WHERE u.id = p_user;
  END IF;
  RETURN v_delta;
END $$;
REVOKE ALL ON FUNCTION public._apply_xp(uuid, text, text, int, boolean) FROM PUBLIC, anon, authenticated;

-- 4. Daily log rewards: log XP + streak + milestones + CO2 saved, atomically.
CREATE OR REPLACE FUNCTION public.submit_log_rewards(
  p_date date, p_is_full_log boolean, p_log_xp int, p_co2_saved_delta numeric DEFAULT 0
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_uid uuid := auth.uid();
  u public.users%ROWTYPE;
  v_cap int; v_gap int;
  v_streak int; v_full int; v_held boolean; v_queued boolean;
  v_used boolean := false; v_inc boolean := false; v_awarded_freeze boolean := false;
  v_log_delta int; v_milestone_xp int := 0; v_milestone_amt int; v_applied int;
  v_last date; v_days_active int;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'not authenticated' USING ERRCODE = '28000'; END IF;
  IF p_date IS NULL OR p_date < current_date - 1 OR p_date > current_date + 1 THEN
    RAISE EXCEPTION 'log date out of range' USING ERRCODE = '22023';
  END IF;
  v_cap := CASE WHEN p_is_full_log THEN 130 ELSE 24 END;
  IF p_log_xp IS NULL OR p_log_xp < 0 OR p_log_xp > v_cap THEN
    RAISE EXCEPTION 'log xp out of range' USING ERRCODE = '22023';
  END IF;
  IF abs(COALESCE(p_co2_saved_delta, 0)) > 200 THEN
    RAISE EXCEPTION 'co2 delta out of range' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO u FROM public.users WHERE id = v_uid FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'profile not found' USING ERRCODE = 'P0002'; END IF;

  v_streak := CASE WHEN COALESCE(u.streak_days, 0) > 0 THEN u.streak_days ELSE COALESCE(u.current_streak, 0) END;
  v_full   := COALESCE(u.full_log_streak_days, 0);
  v_held   := COALESCE(u.streak_freeze_held, false);
  v_queued := COALESCE(u.streak_freeze_queued, false);
  v_last   := u.last_log_date;

  IF u.last_log_date IS NULL THEN
    -- First ever log: the streak begins on the second consecutive day.
    v_streak := 0;
    v_full := CASE WHEN p_is_full_log THEN 1 ELSE 0 END;
    v_last := p_date;
  ELSIF p_date < u.last_log_date THEN
    NULL; -- late sync of an older day: streak untouched
  ELSE
    v_gap := p_date - u.last_log_date;
    IF v_gap = 0 THEN
      NULL; -- re-saving today's log
    ELSIF v_gap = 1 THEN
      v_streak := v_streak + 1; v_inc := true;
      IF p_is_full_log THEN v_full := v_full + 1; END IF;
    ELSIF v_gap = 2 AND v_held THEN
      -- A freeze protects exactly one missed day.
      v_used := true; v_held := false;
      v_streak := v_streak + 1; v_inc := true;
      IF p_is_full_log THEN v_full := v_full + 1; END IF;
    ELSE
      v_streak := 0;
      v_full := CASE WHEN p_is_full_log THEN 1 ELSE 0 END;
    END IF;
    v_last := p_date;
  END IF;

  v_days_active := GREATEST(1, (p_date - COALESCE(u.created_at::date, p_date)) + 1);

  UPDATE public.users SET
    current_streak = v_streak, streak_days = v_streak,
    full_log_streak_days = v_full,
    longest_streak = GREATEST(COALESCE(longest_streak, 0), v_streak),
    last_log_date = v_last,
    streak_freeze_held = v_held, streak_freeze_queued = v_queued,
    days_active = v_days_active,
    total_co2_saved = COALESCE(total_co2_saved, 0) + COALESCE(p_co2_saved_delta, 0),
    updated_at = now()
  WHERE id = v_uid;

  v_log_delta := public._apply_xp(v_uid, 'daily_log', p_date::text, p_log_xp, true);

  IF v_inc THEN
    v_milestone_amt := CASE v_streak WHEN 3 THEN 25 WHEN 7 THEN 75 WHEN 14 THEN 150
                                     WHEN 30 THEN 300 WHEN 60 THEN 600 WHEN 100 THEN 1000 ELSE 0 END;
    IF v_milestone_amt > 0 THEN
      v_applied := public._apply_xp(v_uid, 'streak_milestone', v_streak::text, v_milestone_amt, false);
      IF v_applied > 0 THEN
        v_milestone_xp := v_applied;
        IF v_streak = 30 THEN
          IF public._level_for_xp((SELECT lifetime_xp FROM public.users WHERE id = v_uid)) >= 4 THEN
            v_held := true; v_awarded_freeze := true;
          ELSE
            v_queued := true;
          END IF;
        END IF;
      END IF;
    END IF;
  END IF;

  IF v_queued AND (SELECT level FROM public.users WHERE id = v_uid) >= 4 THEN
    v_held := true; v_queued := false; v_awarded_freeze := true;
  END IF;
  UPDATE public.users SET streak_freeze_held = v_held, streak_freeze_queued = v_queued WHERE id = v_uid;

  SELECT * INTO u FROM public.users WHERE id = v_uid;
  RETURN jsonb_build_object(
    'lifetime_xp', u.lifetime_xp, 'monthly_xp', u.monthly_xp, 'level', u.level,
    'current_streak', u.current_streak, 'full_log_streak_days', u.full_log_streak_days,
    'longest_streak', u.longest_streak, 'last_log_date', u.last_log_date,
    'days_active', u.days_active, 'total_co2_saved', u.total_co2_saved,
    'streak_freeze_held', u.streak_freeze_held, 'streak_freeze_queued', u.streak_freeze_queued,
    'freeze_used', v_used, 'freeze_awarded', v_awarded_freeze,
    'streak_increased', v_inc, 'milestone_xp', v_milestone_xp, 'log_xp_delta', v_log_delta
  );
END $$;
REVOKE ALL ON FUNCTION public.submit_log_rewards(date, boolean, int, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_log_rewards(date, boolean, int, numeric) TO authenticated;

-- 5. Quiz / challenge XP: validated, one award per quiz / per challenge completion.
CREATE OR REPLACE FUNCTION public.award_xp(p_source text, p_key text, p_amount int)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_uid uuid := auth.uid(); v_applied int; u public.users%ROWTYPE;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'not authenticated' USING ERRCODE = '28000'; END IF;
  IF p_key IS NULL OR length(p_key) = 0 OR length(p_key) > 120 THEN
    RAISE EXCEPTION 'invalid key' USING ERRCODE = '22023';
  END IF;
  IF p_source = 'quiz' THEN
    IF p_amount IS NULL OR p_amount < 0 OR p_amount > 130 THEN
      RAISE EXCEPTION 'quiz xp out of range' USING ERRCODE = '22023';
    END IF;
  ELSIF p_source = 'challenge' THEN
    IF p_amount IS NULL OR p_amount < 0 OR p_amount > 400 THEN
      RAISE EXCEPTION 'challenge xp out of range' USING ERRCODE = '22023';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.user_challenges
                    WHERE user_id = v_uid AND challenge_id = split_part(p_key, ':', 1)
                      AND status = 'completed') THEN
      RAISE EXCEPTION 'challenge not completed' USING ERRCODE = '22023';
    END IF;
  ELSE
    RAISE EXCEPTION 'unsupported source' USING ERRCODE = '22023';
  END IF;

  PERFORM 1 FROM public.users WHERE id = v_uid FOR UPDATE;
  v_applied := public._apply_xp(v_uid, p_source, p_key, p_amount, false);
  SELECT * INTO u FROM public.users WHERE id = v_uid;
  RETURN jsonb_build_object('awarded', v_applied > 0, 'xp_delta', v_applied,
    'lifetime_xp', u.lifetime_xp, 'monthly_xp', u.monthly_xp, 'level', u.level);
END $$;
REVOKE ALL ON FUNCTION public.award_xp(text, text, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.award_xp(text, text, int) TO authenticated;

-- 6. Lock down direct writes: clients may edit profile fields only, never XP/streak columns.
REVOKE INSERT, UPDATE ON public.users FROM authenticated;
GRANT INSERT (id, name, email, city, country_code, avatar_url, primary_transport, fuel_type,
  engine_size, vehicle_age, vehicle_model, avg_daily_km, transport_factor, home_type, residents,
  heating_type, has_solar, daily_energy_baseline_kwh, daily_heating_baseline_co2,
  daily_energy_baseline_co2, grid_intensity, dietary_preference, daily_food_baseline_co2,
  total_daily_baseline_co2, dark_mode_enabled, notifications_enabled, quiet_hours_start,
  quiet_hours_end, created_at, updated_at) ON public.users TO authenticated;
GRANT UPDATE (name, email, city, country_code, avatar_url, primary_transport, fuel_type,
  engine_size, vehicle_age, vehicle_model, avg_daily_km, transport_factor, home_type, residents,
  heating_type, has_solar, daily_energy_baseline_kwh, daily_heating_baseline_co2,
  daily_energy_baseline_co2, grid_intensity, dietary_preference, daily_food_baseline_co2,
  total_daily_baseline_co2, dark_mode_enabled, notifications_enabled, quiet_hours_start,
  quiet_hours_end, created_at, updated_at) ON public.users TO authenticated;
