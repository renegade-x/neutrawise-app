-- Phase 3: support for reliable challenge auditing and completion history.
-- (Applied to project psztwkbfhwehmesschbk as phase3_challenge_completion_support.)

ALTER TABLE public.user_challenges ADD COLUMN IF NOT EXISTS last_audited_date date;

CREATE TABLE IF NOT EXISTS public.challenge_completions (
  id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id       uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  challenge_id  varchar NOT NULL,
  completed_at  timestamptz NOT NULL DEFAULT now(),
  xp_awarded    integer NOT NULL DEFAULT 0,
  completion_num integer NOT NULL DEFAULT 1
);
CREATE INDEX IF NOT EXISTS idx_challenge_completions_user ON public.challenge_completions (user_id, completed_at DESC);

ALTER TABLE public.challenge_completions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users view own challenge completions" ON public.challenge_completions;
CREATE POLICY "Users view own challenge completions" ON public.challenge_completions
  FOR SELECT TO authenticated USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users insert own challenge completions" ON public.challenge_completions;
CREATE POLICY "Users insert own challenge completions" ON public.challenge_completions
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);

REVOKE ALL ON public.challenge_completions FROM anon, PUBLIC;
GRANT SELECT, INSERT ON public.challenge_completions TO authenticated;
