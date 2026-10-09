-- Tier upgrades (Bronze -> Silver -> Gold) update the existing badge row, but badges had no
-- UPDATE policy, so upgrades were silently ignored. Allow upgrading tier/category on own rows only.
DROP POLICY IF EXISTS "Users can upgrade their own badges" ON public.badges;
CREATE POLICY "Users can upgrade their own badges" ON public.badges
  FOR UPDATE TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

REVOKE UPDATE ON public.badges FROM authenticated;
GRANT UPDATE (badge_tier, category) ON public.badges TO authenticated;
