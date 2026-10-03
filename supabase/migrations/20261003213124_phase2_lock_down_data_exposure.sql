-- Phase 2: stop exposing every user's profile/logs; add leaderboard RPC; tighten privileges.
-- (Applied to project psztwkbfhwehmesschbk as phase2_lock_down_data_exposure.)

-- 1. Leaderboard RPC: returns only public leaderboard fields (name, avatar, xp, level, rank).
CREATE OR REPLACE FUNCTION public.get_leaderboard(
  p_type  text DEFAULT 'global',
  p_city  text DEFAULT NULL,
  p_limit int  DEFAULT 100
)
RETURNS TABLE (id uuid, name text, avatar_url text, xp int, level int, rank int)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  WITH lim AS (SELECT LEAST(GREATEST(COALESCE(p_limit, 100), 1), 100) AS n)
  SELECT * FROM (
    -- global
    SELECT u.id, u.name::text, u.avatar_url::text, COALESCE(u.xp, 0)::int AS xp,
           COALESCE(u.level, 1)::int AS level,
           (ROW_NUMBER() OVER (ORDER BY COALESCE(u.xp, 0) DESC, u.id))::int AS rank
    FROM public.users u
    WHERE auth.uid() IS NOT NULL AND COALESCE(p_type, 'global') = 'global'
    UNION ALL
    -- city
    SELECT u.id, u.name::text, u.avatar_url::text, COALESCE(u.xp, 0)::int,
           COALESCE(u.level, 1)::int,
           (ROW_NUMBER() OVER (ORDER BY COALESCE(u.xp, 0) DESC, u.id))::int
    FROM public.users u
    WHERE auth.uid() IS NOT NULL AND p_type = 'city'
      AND NULLIF(btrim(p_city), '') IS NOT NULL
      AND lower(btrim(u.city)) = lower(btrim(p_city))
    UNION ALL
    -- weekly sprint (XP earned from logs since Monday)
    SELECT u.id, u.name::text, u.avatar_url::text, s.week_xp::int,
           COALESCE(u.level, 1)::int,
           (ROW_NUMBER() OVER (ORDER BY s.week_xp DESC, u.id))::int
    FROM (
      SELECT l.user_id, SUM(COALESCE(l.xp_earned, 0)) AS week_xp
      FROM public.daily_logs l
      WHERE l.date::date >= date_trunc('week', current_date)::date
      GROUP BY l.user_id
    ) s
    JOIN public.users u ON u.id = s.user_id
    WHERE auth.uid() IS NOT NULL AND p_type = 'weekly_sprint'
  ) ranked
  ORDER BY ranked.rank
  LIMIT (SELECT n FROM lim);
$$;

REVOKE ALL ON FUNCTION public.get_leaderboard(text, text, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_leaderboard(text, text, int) TO authenticated;

-- 2. users / daily_logs: own rows only.
DROP POLICY IF EXISTS "Anyone can view user profiles" ON public.users;
CREATE POLICY "Users can view their own record" ON public.users
  FOR SELECT TO authenticated USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update their own record" ON public.users;
CREATE POLICY "Users can update their own record" ON public.users
  FOR UPDATE TO authenticated USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Users can insert their own record" ON public.users;
CREATE POLICY "Users can insert their own record" ON public.users
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = id);

-- Account deletion previously matched no policy and silently did nothing.
DROP POLICY IF EXISTS "Users can delete their own record" ON public.users;
CREATE POLICY "Users can delete their own record" ON public.users
  FOR DELETE TO authenticated USING (auth.uid() = id);

DROP POLICY IF EXISTS "Anyone can view daily logs" ON public.daily_logs;
CREATE POLICY "Users can view their own logs" ON public.daily_logs
  FOR SELECT TO authenticated USING (auth.uid() = user_id);

-- 3. Catalog / reporting tables: authenticated read only.
DROP POLICY IF EXISTS "Anyone can view challenges catalog" ON public.challenges;
DROP POLICY IF EXISTS "Public can view leaderboard rankings" ON public.leaderboard_rankings;
CREATE POLICY "Authenticated can view leaderboard rankings" ON public.leaderboard_rankings
  FOR SELECT TO authenticated USING (true);

-- 4. Privileges: anon gets nothing on app tables; authenticated loses TRUNCATE/REFERENCES/TRIGGER
--    everywhere and all writes on read-only catalog tables.
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon;
REVOKE TRUNCATE, REFERENCES, TRIGGER ON ALL TABLES IN SCHEMA public FROM authenticated;
REVOKE INSERT, UPDATE, DELETE ON
  public.badge_catalog, public.challenges, public.pakistani_foods,
  public.question_bank, public.quiz_questions, public.leaderboard_rankings
FROM authenticated;
