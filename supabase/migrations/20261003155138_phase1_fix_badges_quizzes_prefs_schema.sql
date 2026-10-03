-- Phase 1: make badge / quiz / notification-pref writes work against the real schema.
-- (Applied to project psztwkbfhwehmesschbk as version 20261003155138.)

-- 1. badges: one row per (user, badge_name); tier is upgraded in place.
ALTER TABLE public.badges ADD COLUMN IF NOT EXISTS category VARCHAR;
ALTER TABLE public.badges DROP CONSTRAINT IF EXISTS badges_user_id_badge_name_badge_tier_key;
DELETE FROM public.badges a USING public.badges b
  WHERE a.user_id = b.user_id AND a.badge_name = b.badge_name AND a.id > b.id;
ALTER TABLE public.badges DROP CONSTRAINT IF EXISTS badges_user_id_badge_name_key;
ALTER TABLE public.badges ADD CONSTRAINT badges_user_id_badge_name_key UNIQUE (user_id, badge_name);

-- 2. quizzes: defaults so the client-created parent row satisfies NOT NULL columns.
ALTER TABLE public.quizzes ALTER COLUMN topic SET DEFAULT 'Sustainability & Carbon Science';
ALTER TABLE public.quizzes ALTER COLUMN questions SET DEFAULT '[]'::jsonb;
ALTER TABLE public.quizzes ALTER COLUMN start_time SET DEFAULT now();
ALTER TABLE public.quizzes ALTER COLUMN end_time SET DEFAULT (now() + interval '48 hours');

-- 3. notification_preferences: columns for the keys the edge function checks.
ALTER TABLE public.notification_preferences
  ADD COLUMN IF NOT EXISTS final_log_warning BOOLEAN DEFAULT true,
  ADD COLUMN IF NOT EXISTS streak_expiration BOOLEAN DEFAULT true,
  ADD COLUMN IF NOT EXISTS challenge_reminder BOOLEAN DEFAULT true,
  ADD COLUMN IF NOT EXISTS challenge_complete BOOLEAN DEFAULT true,
  ADD COLUMN IF NOT EXISTS leaderboard_overtaken BOOLEAN DEFAULT true;

CREATE OR REPLACE FUNCTION public.sync_notification_pref_aliases()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  IF TG_OP = 'INSERT' OR NEW.streak_warnings IS DISTINCT FROM OLD.streak_warnings THEN
    NEW.final_log_warning := NEW.streak_warnings;
    NEW.streak_expiration := NEW.streak_warnings;
  END IF;
  IF TG_OP = 'INSERT' OR NEW.challenge_reminders IS DISTINCT FROM OLD.challenge_reminders THEN
    NEW.challenge_reminder := NEW.challenge_reminders;
    NEW.challenge_complete := NEW.challenge_reminders;
  END IF;
  IF TG_OP = 'INSERT' OR NEW.leaderboard_overtake IS DISTINCT FROM OLD.leaderboard_overtake THEN
    NEW.leaderboard_overtaken := NEW.leaderboard_overtake;
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_sync_notification_pref_aliases ON public.notification_preferences;
CREATE TRIGGER trg_sync_notification_pref_aliases
  BEFORE INSERT OR UPDATE ON public.notification_preferences
  FOR EACH ROW EXECUTE FUNCTION public.sync_notification_pref_aliases();
