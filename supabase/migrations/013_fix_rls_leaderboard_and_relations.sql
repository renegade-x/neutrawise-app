-- 013_fix_rls_leaderboard_and_relations.sql
-- Enable RLS and apply secure policies to leaderboard_rankings and user_relations

-- 1. leaderboard_rankings
ALTER TABLE public.leaderboard_rankings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public can view leaderboard rankings" ON public.leaderboard_rankings;
CREATE POLICY "Public can view leaderboard rankings" ON public.leaderboard_rankings
  FOR SELECT TO authenticated, anon
  USING (true);

DROP POLICY IF EXISTS "Service role manages leaderboard rankings" ON public.leaderboard_rankings;
CREATE POLICY "Service role manages leaderboard rankings" ON public.leaderboard_rankings
  FOR ALL TO service_role
  USING (true)
  WITH CHECK (true);

-- 2. user_relations
ALTER TABLE public.user_relations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own relations" ON public.user_relations;
CREATE POLICY "Users can view their own relations" ON public.user_relations
  FOR SELECT TO authenticated
  USING (auth.uid() = user_id OR auth.uid() = related_user_id);

DROP POLICY IF EXISTS "Users can insert their own relations" ON public.user_relations;
CREATE POLICY "Users can insert their own relations" ON public.user_relations
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own relations" ON public.user_relations;
CREATE POLICY "Users can update their own relations" ON public.user_relations
  FOR UPDATE TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own relations" ON public.user_relations;
CREATE POLICY "Users can delete their own relations" ON public.user_relations
  FOR DELETE TO authenticated
  USING (auth.uid() = user_id);

