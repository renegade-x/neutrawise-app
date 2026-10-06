-- NeutraWise database regression suite.
--
-- Covers the security / integrity rules added in the fix phases (RLS, forged XP,
-- idempotent rewards, push secret, account deletion, avatar storage).
-- Creates its own throwaway users and ALWAYS rolls back.
--
-- Run against a local or branch database (never needs real user data):
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/regression.sql
-- Exit code is non-zero if any assertion fails.

BEGIN;

CREATE FUNCTION pg_temp.t_ok(p_cond boolean, p_msg text) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  IF p_cond IS NOT TRUE THEN RAISE EXCEPTION 'REGRESSION FAILED: %', p_msg; END IF;
END $$;

CREATE FUNCTION pg_temp.t_denied(p_sql text, p_msg text) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  BEGIN
    EXECUTE p_sql;
  EXCEPTION WHEN OTHERS THEN
    RETURN;
  END;
  RAISE EXCEPTION 'REGRESSION FAILED (should have been rejected): %', p_msg;
END $$;

DO $$
DECLARE
  a uuid := gen_random_uuid();
  b uuid := gen_random_uuid();
  r jsonb;
  n int;
BEGIN
  -- Fixtures (as the owner role).
  INSERT INTO auth.users (id, email, aud, role)
  VALUES (a, 'reg-a-' || a || '@example.test', 'authenticated', 'authenticated'),
         (b, 'reg-b-' || b || '@example.test', 'authenticated', 'authenticated');
  INSERT INTO public.users (id, name, email, city, country_code)
  VALUES (a, 'Reg A', 'reg-a-' || a || '@example.test', 'Lahore', 'PK'),
         (b, 'Reg B', 'reg-b-' || b || '@example.test', 'Lahore', 'PK');
  INSERT INTO public.daily_logs (user_id, date) VALUES (b, current_date);

  -- ---- Signed in as user A ----
  PERFORM set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  SET LOCAL ROLE authenticated;

  -- RLS: own rows only
  SELECT count(*) INTO n FROM public.users;
  PERFORM pg_temp.t_ok(n = 1, 'user can read only their own users row');
  SELECT count(*) INTO n FROM public.daily_logs WHERE user_id = b;
  PERFORM pg_temp.t_ok(n = 0, 'user cannot read another user''s daily logs');

  -- Forged progression is rejected, normal edits still work
  PERFORM pg_temp.t_denied('UPDATE public.users SET xp = 999999 WHERE id = ''' || a || '''', 'direct xp update');
  PERFORM pg_temp.t_denied('UPDATE public.users SET current_streak = 99 WHERE id = ''' || a || '''', 'direct streak update');
  UPDATE public.users SET city = 'Karachi' WHERE id = a;

  -- Catalog / privileged objects
  PERFORM pg_temp.t_denied('TRUNCATE public.badges', 'truncate');
  PERFORM pg_temp.t_denied('INSERT INTO public.challenges (id) VALUES (gen_random_uuid())', 'catalog write');
  PERFORM pg_temp.t_denied('SELECT public.send_push(''level_up'', ''' || a || ''')', 'send_push from client');
  PERFORM pg_temp.t_denied('SELECT public.verify_push_secret(''x'')', 'verify_push_secret from client');
  PERFORM pg_temp.t_denied('SELECT public._apply_xp(''' || a || ''', ''quiz'', ''k'', 100, false)', '_apply_xp from client');

  -- Leaderboard exposes both users but no private columns
  SELECT count(*) INTO n FROM public.get_leaderboard('global', NULL, 100) WHERE id IN (a, b);
  PERFORM pg_temp.t_ok(n = 2, 'leaderboard lists both users');

  -- Daily rewards: first log, same-day re-save, milestone idempotency
  r := public.submit_log_rewards(current_date, true, 50, 2.5);
  PERFORM pg_temp.t_ok((r->>'current_streak')::int = 0 AND (r->>'lifetime_xp')::int = 50, 'first log: streak 0, 50 xp');
  r := public.submit_log_rewards(current_date, true, 60, 1.0);
  PERFORM pg_temp.t_ok((r->>'lifetime_xp')::int = 60 AND (r->>'log_xp_delta')::int = 10, 're-save replaces log xp');
  r := public.submit_log_rewards(current_date, true, 60, 0);
  PERFORM pg_temp.t_ok((r->>'log_xp_delta')::int = 0, 'identical re-save is a no-op');
  PERFORM pg_temp.t_denied('SELECT public.submit_log_rewards(current_date - 5, true, 50, 0)', 'old log date');
  PERFORM pg_temp.t_denied('SELECT public.submit_log_rewards(current_date, false, 130, 0)', 'partial log xp above cap');
  PERFORM pg_temp.t_denied('SELECT public.submit_log_rewards(current_date, true, 50, 5000)', 'absurd co2 delta');

  RESET ROLE;
  UPDATE public.users SET streak_days = 2, current_streak = 2, last_log_date = current_date - 1 WHERE id = a;
  DELETE FROM public.xp_ledger WHERE user_id = a AND source = 'daily_log';
  SET LOCAL ROLE authenticated;
  r := public.submit_log_rewards(current_date, true, 50, 0);
  PERFORM pg_temp.t_ok((r->>'current_streak')::int = 3 AND (r->>'milestone_xp')::int = 25, '3-day milestone pays 25 xp');
  r := public.submit_log_rewards(current_date, true, 50, 0);
  PERFORM pg_temp.t_ok((r->>'milestone_xp')::int = 0 AND (r->>'streak_increased')::boolean IS FALSE, 'milestone is not paid twice');

  -- Streak freeze covers exactly one missed day
  RESET ROLE;
  UPDATE public.users SET streak_days = 5, current_streak = 5, streak_freeze_held = true, last_log_date = current_date - 2 WHERE id = a;
  SET LOCAL ROLE authenticated;
  r := public.submit_log_rewards(current_date, false, 20, 0);
  PERFORM pg_temp.t_ok((r->>'current_streak')::int = 6 AND (r->>'freeze_used')::boolean, 'freeze bridges one missed day');
  RESET ROLE;
  UPDATE public.users SET streak_days = 5, current_streak = 5, streak_freeze_held = true, last_log_date = current_date - 3 WHERE id = a;
  SET LOCAL ROLE authenticated;
  r := public.submit_log_rewards(current_date, false, 20, 0);
  PERFORM pg_temp.t_ok((r->>'current_streak')::int = 0 AND NOT (r->>'freeze_used')::boolean, 'freeze does not bridge two missed days');

  -- Quiz / challenge XP
  r := public.award_xp('quiz', 'quiz-1', 100);
  PERFORM pg_temp.t_ok((r->>'awarded')::boolean, 'quiz xp awarded once');
  r := public.award_xp('quiz', 'quiz-1', 100);
  PERFORM pg_temp.t_ok(NOT (r->>'awarded')::boolean, 'quiz xp not awarded twice');
  PERFORM pg_temp.t_denied('SELECT public.award_xp(''quiz'', ''quiz-2'', 5000)', 'oversized quiz xp');
  PERFORM pg_temp.t_denied('SELECT public.award_xp(''challenge'', ''no_car_day:1'', 100)', 'xp for unfinished challenge');
  PERFORM pg_temp.t_denied('SELECT public.award_xp(''daily_log'', ''x'', 50)', 'unsupported xp source');

  -- Badges: one row per badge name
  INSERT INTO public.badges (user_id, badge_name, badge_tier, category) VALUES (a, 'Reg Badge', 'Bronze', 'Nature');
  UPDATE public.badges SET badge_tier = 'Silver' WHERE user_id = a AND badge_name = 'Reg Badge';
  SELECT count(*) INTO n FROM public.badges WHERE user_id = a AND badge_name = 'Reg Badge' AND badge_tier = 'Silver';
  PERFORM pg_temp.t_ok(n = 1, 'badge tier upgrade is applied in place');
  PERFORM pg_temp.t_denied('INSERT INTO public.badges (user_id, badge_name, badge_tier) VALUES (''' || a || ''', ''Reg Badge'', ''Gold'')', 'duplicate badge row');
  PERFORM pg_temp.t_denied('UPDATE public.badges SET earned_at = now() - interval ''1 year'' WHERE user_id = ''' || a || '''', 'editing badge earned_at');

  -- Data export contains only the caller's data
  r := public.export_my_data();
  PERFORM pg_temp.t_ok((r->'profile'->>'id')::uuid = a, 'export contains own profile');
  PERFORM pg_temp.t_ok(jsonb_array_length(r->'daily_logs') = (SELECT count(*) FROM public.daily_logs WHERE user_id = a), 'export contains only own logs');

  -- Avatar storage: own folder only
  INSERT INTO storage.objects (bucket_id, name, owner) VALUES ('avatars', a || '/avatar.jpg', a);
  PERFORM pg_temp.t_denied('INSERT INTO storage.objects (bucket_id, name, owner) VALUES (''avatars'', ''' || b || '/avatar.jpg'', ''' || a || ''')', 'upload into another user''s folder');

  -- ---- Anonymous ----
  RESET ROLE;
  SET LOCAL ROLE anon;
  PERFORM pg_temp.t_denied('SELECT count(*) FROM public.users', 'anon read users');
  PERFORM pg_temp.t_denied('SELECT public.get_leaderboard()', 'anon leaderboard');
  PERFORM pg_temp.t_denied('SELECT public.award_xp(''quiz'', ''k'', 10)', 'anon award_xp');
  RESET ROLE;

  -- Push secret: wrong secret rejected (owner role may call it)
  PERFORM pg_temp.t_ok(public.verify_push_secret('not-the-secret') IS FALSE, 'wrong push secret rejected');

  -- ---- Account deletion as user B ----
  PERFORM set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  PERFORM public.delete_my_account();
  RESET ROLE;
  SELECT count(*) INTO n FROM public.users WHERE id = b;
  PERFORM pg_temp.t_ok(n = 0, 'deleted account removes profile row');
  SELECT count(*) INTO n FROM public.daily_logs WHERE user_id = b;
  PERFORM pg_temp.t_ok(n = 0, 'deleted account cascades to logs');
  SELECT count(*) INTO n FROM auth.users WHERE id = b;
  PERFORM pg_temp.t_ok(n = 0, 'deleted account removes the sign-in user');

  RAISE NOTICE 'REGRESSION SUITE PASSED';
END $$;

ROLLBACK;
