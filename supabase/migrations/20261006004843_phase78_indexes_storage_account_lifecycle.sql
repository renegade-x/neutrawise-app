-- Phase 7+8: performance indexes, avatar storage, account deletion / data export,
-- and a fix so streak warnings are not sent for streaks that already expired.

-- 1. Indexes used by the leaderboard function and weekly sprint.
CREATE INDEX IF NOT EXISTS idx_users_xp ON public.users (xp DESC);
CREATE INDEX IF NOT EXISTS idx_users_city_lower ON public.users (lower(btrim(city)));
CREATE INDEX IF NOT EXISTS idx_daily_logs_date ON public.daily_logs (date);

-- 2. Avatar storage (replaces base64 images stored in users.avatar_url).
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('avatars', 'avatars', true, 524288, ARRAY['image/jpeg', 'image/png', 'image/webp'])
ON CONFLICT (id) DO UPDATE
  SET public = true, file_size_limit = 524288,
      allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp'];

DROP POLICY IF EXISTS "avatars_select_own" ON storage.objects;
CREATE POLICY "avatars_select_own" ON storage.objects FOR SELECT TO authenticated
  USING (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text);
DROP POLICY IF EXISTS "avatars_insert_own" ON storage.objects;
CREATE POLICY "avatars_insert_own" ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text);
DROP POLICY IF EXISTS "avatars_update_own" ON storage.objects;
CREATE POLICY "avatars_update_own" ON storage.objects FOR UPDATE TO authenticated
  USING (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text)
  WITH CHECK (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text);
DROP POLICY IF EXISTS "avatars_delete_own" ON storage.objects;
CREATE POLICY "avatars_delete_own" ON storage.objects FOR DELETE TO authenticated
  USING (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text);

-- 3. Account deletion: removes the sign-in account; every app table cascades from it.
CREATE OR REPLACE FUNCTION public.delete_my_account() RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not authenticated' USING ERRCODE = '28000'; END IF;
  DELETE FROM auth.users WHERE id = auth.uid();
END $$;
REVOKE ALL ON FUNCTION public.delete_my_account() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.delete_my_account() TO authenticated;

-- 4. Data export: everything the app stores about the signed-in user, as JSON.
CREATE OR REPLACE FUNCTION public.export_my_data() RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'not authenticated' USING ERRCODE = '28000'; END IF;
  RETURN jsonb_build_object(
    'exported_at', now(),
    'profile', (SELECT to_jsonb(u) FROM public.users u WHERE u.id = v_uid),
    'daily_logs', COALESCE((SELECT jsonb_agg(to_jsonb(l) ORDER BY l.date) FROM public.daily_logs l WHERE l.user_id = v_uid), '[]'::jsonb),
    'badges', COALESCE((SELECT jsonb_agg(to_jsonb(b)) FROM public.badges b WHERE b.user_id = v_uid), '[]'::jsonb),
    'challenges', COALESCE((SELECT jsonb_agg(to_jsonb(c)) FROM public.user_challenges c WHERE c.user_id = v_uid), '[]'::jsonb),
    'challenge_completions', COALESCE((SELECT jsonb_agg(to_jsonb(cc)) FROM public.challenge_completions cc WHERE cc.user_id = v_uid), '[]'::jsonb),
    'quiz_attempts', COALESCE((SELECT jsonb_agg(to_jsonb(q)) FROM public.user_quizzes q WHERE q.user_id = v_uid), '[]'::jsonb),
    'xp_ledger', COALESCE((SELECT jsonb_agg(to_jsonb(x) ORDER BY x.created_at) FROM public.xp_ledger x WHERE x.user_id = v_uid), '[]'::jsonb),
    'notification_preferences', (SELECT to_jsonb(n) FROM public.notification_preferences n WHERE n.user_id = v_uid)
  );
END $$;
REVOKE ALL ON FUNCTION public.export_my_data() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.export_my_data() TO authenticated;

-- 5. Streak warning only while the streak is still alive (last log today or yesterday;
--    two days back if a streak freeze is held). Everything else is unchanged.
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
             COALESCE(NULLIF(u.streak_days, 0), u.current_streak, 0) AS streak,
             u.last_log_date AS last_log, COALESCE(u.streak_freeze_held, false) AS frozen
        FROM public.users u
       WHERE COALESCE(u.notifications_enabled, true)
    ), c AS (
      SELECT id, lt, qs, qe, streak, last_log, frozen, lt::date AS ld,
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
       AND c.last_log IS NOT NULL
       AND c.last_log >= c.ld - CASE WHEN c.frozen THEN 2 ELSE 1 END
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
