-- Phase 6: working push-notification infrastructure.
-- Replaces the placeholder-URL / missing-extension setup from migrations 003, 006 and 007.
-- Flow: DB trigger or pg_cron job -> public.send_push() -> pg_net -> edge function
-- `schedule_push_notification` (checks a shared secret kept in Vault) -> OneSignal.

CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- 1. Shared secret (generated inside the database, never leaves it except in the
--    request header to our own edge function).
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM vault.secrets WHERE name = 'push_webhook_secret') THEN
    PERFORM vault.create_secret(
      replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', ''),
      'push_webhook_secret',
      'Shared secret for database -> schedule_push_notification calls');
  END IF;
END $$;

-- Used by the edge function (service role only) to authenticate callers.
CREATE OR REPLACE FUNCTION public.verify_push_secret(p_secret text)
RETURNS boolean LANGUAGE sql SECURITY DEFINER SET search_path = public, vault AS $$
  SELECT p_secret IS NOT NULL AND length(p_secret) >= 32 AND EXISTS (
    SELECT 1 FROM vault.decrypted_secrets
     WHERE name = 'push_webhook_secret' AND decrypted_secret = p_secret);
$$;
REVOKE ALL ON FUNCTION public.verify_push_secret(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.verify_push_secret(text) TO service_role;

-- 2. Single outbound helper. Failures never break the calling transaction.
CREATE OR REPLACE FUNCTION public.send_push(p_type text, p_user uuid, p_data jsonb DEFAULT '{}'::jsonb)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, vault AS $$
DECLARE v_secret text;
BEGIN
  SELECT decrypted_secret INTO v_secret FROM vault.decrypted_secrets WHERE name = 'push_webhook_secret';
  IF v_secret IS NULL THEN RETURN; END IF;
  PERFORM net.http_post(
    url := 'https://psztwkbfhwehmesschbk.supabase.co/functions/v1/schedule_push_notification',
    body := jsonb_build_object('type', p_type, 'user_id', p_user, 'data', COALESCE(p_data, '{}'::jsonb)),
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-push-secret', v_secret),
    timeout_milliseconds := 5000);
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'send_push(%) failed: %', p_type, SQLERRM;
END $$;
REVOKE ALL ON FUNCTION public.send_push(text, uuid, jsonb) FROM PUBLIC, anon, authenticated;

-- 3. Event triggers (fixed URL, no app.jwt_secret, pinned search_path, correct pg_net args).
CREATE OR REPLACE FUNCTION public.notify_level_up() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_titles text[] := ARRAY['Eco Newcomer','Green Sprout','Eco Explorer','Sustainability Seeker',
  'Eco Advocate','Climate Champion','Green Guardian','Eco Hero','Carbon Crusader','Carbon Neutral'];
BEGIN
  PERFORM public.send_push('level_up', NEW.id, jsonb_build_object(
    'new_level', NEW.level,
    'level_title', v_titles[LEAST(GREATEST(NEW.level, 1), 10)]));
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS on_level_up ON public.users;
CREATE TRIGGER on_level_up AFTER UPDATE OF level ON public.users
  FOR EACH ROW WHEN (NEW.level > OLD.level) EXECUTE FUNCTION public.notify_level_up();

CREATE OR REPLACE FUNCTION public.notify_badge_earned() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  PERFORM public.send_push('badge_earned', NEW.user_id, jsonb_build_object('badge_name', NEW.badge_name));
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS on_badge_earned ON public.badges;
CREATE TRIGGER on_badge_earned AFTER INSERT ON public.badges
  FOR EACH ROW EXECUTE FUNCTION public.notify_badge_earned();

CREATE OR REPLACE FUNCTION public.notify_challenge_complete() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  PERFORM public.send_push('challenge_complete', NEW.user_id, jsonb_build_object(
    'challenge_name', NEW.challenge_name,
    'xp', COALESCE(NULLIF(NEW.xp_earned, 0), NEW.xp_reward, 100)));
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS on_challenge_complete ON public.user_challenges;
CREATE TRIGGER on_challenge_complete AFTER UPDATE ON public.user_challenges
  FOR EACH ROW WHEN (NEW.completed_at IS NOT NULL AND OLD.completed_at IS DISTINCT FROM NEW.completed_at)
  EXECUTE FUNCTION public.notify_challenge_complete();

CREATE OR REPLACE FUNCTION public.notify_streak_milestone() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  PERFORM public.send_push('streak_milestone', NEW.id, jsonb_build_object(
    'streak_days', NEW.current_streak,
    'xp', CASE NEW.current_streak WHEN 7 THEN 75 WHEN 14 THEN 150 WHEN 30 THEN 300 WHEN 60 THEN 600 ELSE 1000 END));
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS on_streak_milestone ON public.users;
CREATE TRIGGER on_streak_milestone AFTER UPDATE OF current_streak ON public.users
  FOR EACH ROW WHEN (NEW.current_streak > OLD.current_streak AND NEW.current_streak IN (7, 14, 30, 60, 100))
  EXECUTE FUNCTION public.notify_streak_milestone();

-- 4. User-local scheduling support. The app reports its UTC offset (minutes).
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS utc_offset_minutes smallint;

CREATE OR REPLACE FUNCTION public.set_my_utc_offset(p_minutes int) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not authenticated' USING ERRCODE = '28000'; END IF;
  IF p_minutes IS NULL OR p_minutes < -840 OR p_minutes > 840 THEN
    RAISE EXCEPTION 'offset out of range' USING ERRCODE = '22023';
  END IF;
  UPDATE public.users SET utc_offset_minutes = p_minutes WHERE id = auth.uid() AND utc_offset_minutes IS DISTINCT FROM p_minutes;
END $$;
REVOKE ALL ON FUNCTION public.set_my_utc_offset(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_my_utc_offset(int) TO authenticated;

-- 5. De-duplication log and leaderboard snapshot (server-only tables).
CREATE TABLE IF NOT EXISTS public.push_log (
  id        bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id   uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  type      text NOT NULL,
  slot_key  text NOT NULL,
  sent_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, type, slot_key)
);
CREATE INDEX IF NOT EXISTS idx_push_log_sent_at ON public.push_log (sent_at);
ALTER TABLE public.push_log ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.push_log FROM PUBLIC, anon, authenticated;

CREATE TABLE IF NOT EXISTS public.leaderboard_snapshot (
  user_id    uuid PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  rank       integer NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.leaderboard_snapshot ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.leaderboard_snapshot FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public._in_quiet_hours(p_local time, p_start time, p_end time)
RETURNS boolean LANGUAGE sql IMMUTABLE SET search_path = public AS $$
  SELECT CASE
    WHEN p_start IS NULL OR p_end IS NULL OR p_start = p_end THEN false
    WHEN p_start < p_end THEN p_local >= p_start AND p_local < p_end
    ELSE p_local >= p_start OR p_local < p_end END;
$$;
REVOKE ALL ON FUNCTION public._in_quiet_hours(time, time, time) FROM PUBLIC, anon, authenticated;

-- 6. Scheduled notifications, evaluated in each user's local time. Runs every 15 minutes;
--    each reminder has a 60-minute window and is sent at most once per local day.
CREATE OR REPLACE FUNCTION public.dispatch_scheduled_push() RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE r record; v_sent int := 0; v_ins int;
BEGIN
  FOR r IN
    WITH base AS (
      SELECT u.id,
             (now() AT TIME ZONE 'UTC') + make_interval(mins =>
               COALESCE(u.utc_offset_minutes, CASE WHEN btrim(u.country_code) = 'PK' THEN 300 ELSE 0 END)::int) AS lt,
             u.quiet_hours_start AS qs, u.quiet_hours_end AS qe,
             COALESCE(NULLIF(u.streak_days, 0), u.current_streak, 0) AS streak
        FROM public.users u
       WHERE COALESCE(u.notifications_enabled, true)
    ), c AS (
      SELECT id, lt, qs, qe, streak, lt::date AS ld,
             (extract(hour FROM lt) * 60 + extract(minute FROM lt))::int AS m,
             extract(dow FROM lt)::int AS dow
        FROM base
    )
    SELECT c.id, 'daily_log_reminder'::text AS type, c.ld::text AS slot_key, '{}'::jsonb AS data,
           false AS urgent, c.lt, c.qs, c.qe
      FROM c WHERE c.m BETWEEN 1200 AND 1259
       AND NOT EXISTS (SELECT 1 FROM public.daily_logs l WHERE l.user_id = c.id AND l.date = c.ld)
    UNION ALL
    SELECT c.id, 'final_log_warning', c.ld::text, jsonb_build_object('streak', c.streak), true, c.lt, c.qs, c.qe
      FROM c WHERE c.m BETWEEN 1350 AND 1409 AND c.streak > 0
       AND NOT EXISTS (SELECT 1 FROM public.daily_logs l WHERE l.user_id = c.id AND l.date = c.ld)
    UNION ALL
    SELECT c.id, 'challenge_reminder', c.ld::text,
           jsonb_build_object('day', GREATEST(1, (c.ld - uc.started_at::date) + 1), 'challenge_name', uc.challenge_name),
           false, c.lt, c.qs, c.qe
      FROM c
      JOIN LATERAL (SELECT x.challenge_name, x.started_at FROM public.user_challenges x
                     WHERE x.user_id = c.id AND x.status = 'in_progress' AND x.completed_at IS NULL
                     ORDER BY x.started_at LIMIT 1) uc ON true
     WHERE c.m BETWEEN 720 AND 779
       AND NOT EXISTS (SELECT 1 FROM public.daily_logs l WHERE l.user_id = c.id AND l.date = c.ld)
    UNION ALL
    SELECT c.id, 'weekly_summary', c.ld::text,
           jsonb_build_object('co2_saved', ROUND(COALESCE((SELECT SUM(l.co2_saved_vs_baseline) FROM public.daily_logs l
                                WHERE l.user_id = c.id AND l.date > c.ld - 7 AND l.date <= c.ld), 0)::numeric, 1),
                              'streak', c.streak),
           false, c.lt, c.qs, c.qe
      FROM c WHERE c.dow = 0 AND c.m BETWEEN 1080 AND 1139
    UNION ALL
    SELECT c.id, 'quiz_available', c.ld::text, '{"xp":130}'::jsonb, false, c.lt, c.qs, c.qe
      FROM c WHERE c.dow IN (2, 5) AND c.m BETWEEN 540 AND 599
  LOOP
    IF NOT r.urgent AND public._in_quiet_hours(r.lt::time, r.qs, r.qe) THEN CONTINUE; END IF;
    INSERT INTO public.push_log (user_id, type, slot_key) VALUES (r.id, r.type, r.slot_key)
      ON CONFLICT (user_id, type, slot_key) DO NOTHING;
    GET DIAGNOSTICS v_ins = ROW_COUNT;
    IF v_ins > 0 THEN
      PERFORM public.send_push(r.type, r.id, r.data);
      v_sent := v_sent + 1;
    END IF;
  END LOOP;

  DELETE FROM public.push_log WHERE sent_at < now() - interval '60 days';
  RETURN v_sent;
END $$;
REVOKE ALL ON FUNCTION public.dispatch_scheduled_push() FROM PUBLIC, anon, authenticated;

-- 7. Leaderboard overtakes: compare current global ranks with the last snapshot (max 3 per day).
CREATE OR REPLACE FUNCTION public.dispatch_leaderboard_overtakes() RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE r record; v_sent int := 0; v_today int;
BEGIN
  FOR r IN
    WITH cur AS (
      SELECT u.id, u.name, (ROW_NUMBER() OVER (ORDER BY COALESCE(u.xp, 0) DESC, u.id))::int AS rk,
             (now() AT TIME ZONE 'UTC') + make_interval(mins =>
               COALESCE(u.utc_offset_minutes, CASE WHEN btrim(u.country_code) = 'PK' THEN 300 ELSE 0 END)::int) AS lt,
             u.quiet_hours_start AS qs, u.quiet_hours_end AS qe,
             COALESCE(u.notifications_enabled, true) AS en
        FROM public.users u WHERE COALESCE(u.xp, 0) > 0
    )
    SELECT cur.id, cur.rk, above.name AS overtaker, cur.lt, cur.qs, cur.qe
      FROM cur
      JOIN public.leaderboard_snapshot s ON s.user_id = cur.id AND cur.rk > s.rank
      LEFT JOIN cur above ON above.rk = cur.rk - 1
     WHERE cur.en
  LOOP
    IF public._in_quiet_hours(r.lt::time, r.qs, r.qe) THEN CONTINUE; END IF;
    SELECT count(*) INTO v_today FROM public.push_log
     WHERE user_id = r.id AND type = 'leaderboard_overtaken' AND sent_at >= date_trunc('day', now());
    IF v_today >= 3 THEN CONTINUE; END IF;
    INSERT INTO public.push_log (user_id, type, slot_key) VALUES (r.id, 'leaderboard_overtaken', gen_random_uuid()::text);
    PERFORM public.send_push('leaderboard_overtaken', r.id,
      jsonb_build_object('overtaker_name', COALESCE(r.overtaker, 'Someone'), 'rank', r.rk));
    v_sent := v_sent + 1;
  END LOOP;

  INSERT INTO public.leaderboard_snapshot (user_id, rank)
  SELECT u.id, (ROW_NUMBER() OVER (ORDER BY COALESCE(u.xp, 0) DESC, u.id))::int
    FROM public.users u WHERE COALESCE(u.xp, 0) > 0
  ON CONFLICT (user_id) DO UPDATE SET rank = EXCLUDED.rank, updated_at = now();
  RETURN v_sent;
END $$;
REVOKE ALL ON FUNCTION public.dispatch_leaderboard_overtakes() FROM PUBLIC, anon, authenticated;

-- 8. Cron: replace the old placeholder jobs with one 15-minute dispatcher.
DO $$
DECLARE j text;
BEGIN
  FOREACH j IN ARRAY ARRAY['daily_log_reminder_job','final_log_warning_job','weekly_summary_job','push_dispatch_15min'] LOOP
    IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = j) THEN PERFORM cron.unschedule(j); END IF;
  END LOOP;
  PERFORM cron.schedule('push_dispatch_15min', '*/15 * * * *',
    'SELECT public.dispatch_scheduled_push(); SELECT public.dispatch_leaderboard_overtakes();');
END $$;

-- 9. Realtime: the dashboard subscribes to new badges, but no table was published.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime'
                  AND schemaname = 'public' AND tablename = 'badges') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.badges;
  END IF;
END $$;
