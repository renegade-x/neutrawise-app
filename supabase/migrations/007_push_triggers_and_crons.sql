-- Trigger: Send push notification on challenge completion
CREATE OR REPLACE FUNCTION notify_challenge_complete()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.completed_at IS NOT NULL AND (OLD.completed_at IS NULL OR OLD.completed_at != NEW.completed_at) THEN
    IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'net') THEN
      BEGIN
        EXECUTE 'SELECT net.http_post(
          url := $1,
          payload := $2,
          headers := $3
        )' USING
          'https://your-project.supabase.co/functions/v1/schedule_push_notification',
          json_build_object(
            'type', 'challenge_complete',
            'user_id', NEW.user_id,
            'data', json_build_object(
              'challenge_name', NEW.challenge_name,
              'xp', NEW.xp_reward
            )
          )::text,
          json_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || current_setting('app.jwt_secret', true)
          );
      EXCEPTION WHEN OTHERS THEN
        NULL;
      END;
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_challenge_complete ON user_challenges;
CREATE TRIGGER on_challenge_complete
AFTER UPDATE OR INSERT ON user_challenges
FOR EACH ROW
EXECUTE FUNCTION notify_challenge_complete();

-- Trigger: Send push notification on streak milestones (7, 14, 30, 60, 100 days)
CREATE OR REPLACE FUNCTION notify_streak_milestone()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.current_streak IN (7, 14, 30, 60, 100) AND (OLD.current_streak IS NULL OR OLD.current_streak < NEW.current_streak) THEN
    IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'net') THEN
      BEGIN
        EXECUTE 'SELECT net.http_post(
          url := $1,
          payload := $2,
          headers := $3
        )' USING
          'https://your-project.supabase.co/functions/v1/schedule_push_notification',
          json_build_object(
            'type', 'streak_milestone',
            'user_id', NEW.id,
            'data', json_build_object(
              'streak_days', NEW.current_streak,
              'xp', 50
            )
          )::text,
          json_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || current_setting('app.jwt_secret', true)
          );
      EXCEPTION WHEN OTHERS THEN
        NULL;
      END;
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_streak_milestone ON users;
CREATE TRIGGER on_streak_milestone
AFTER UPDATE ON users
FOR EACH ROW
WHEN (NEW.current_streak > OLD.current_streak)
EXECUTE FUNCTION notify_streak_milestone();

-- Scheduled Cron Jobs (Requires pg_cron extension)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'cron') THEN
    -- 1. Daily Log Reminder (8:00 PM Daily)
    PERFORM cron.schedule('daily_log_reminder_job', '0 20 * * *', $$
      SELECT net.http_post(
        url := 'https://your-project.supabase.co/functions/v1/schedule_push_notification',
        payload := json_build_object(
          'type', 'daily_log_reminder',
          'user_id', u.id
        )::text,
        headers := json_build_object('Content-Type', 'application/json')
      )
      FROM users u
      WHERE NOT EXISTS (
        SELECT 1 FROM daily_logs
        WHERE user_id = u.id AND date = CURRENT_DATE
      );
    $$);

    -- 2. Final Log Warning (10:30 PM Daily for active streaks)
    PERFORM cron.schedule('final_log_warning_job', '30 22 * * *', $$
      SELECT net.http_post(
        url := 'https://your-project.supabase.co/functions/v1/schedule_push_notification',
        payload := json_build_object(
          'type', 'final_log_warning',
          'user_id', u.id,
          'data', json_build_object('streak', u.current_streak)
        )::text,
        headers := json_build_object('Content-Type', 'application/json')
      )
      FROM users u
      WHERE u.current_streak > 0
        AND NOT EXISTS (
          SELECT 1 FROM daily_logs
          WHERE user_id = u.id AND date = CURRENT_DATE
        );
    $$);

    -- 3. Weekly Summary (6:00 PM Sunday)
    PERFORM cron.schedule('weekly_summary_job', '0 18 * * 0', $$
      SELECT net.http_post(
        url := 'https://your-project.supabase.co/functions/v1/schedule_push_notification',
        payload := json_build_object(
          'type', 'weekly_summary',
          'user_id', u.id,
          'data', json_build_object('co2_saved', u.total_co2_saved, 'streak', u.current_streak)
        )::text,
        headers := json_build_object('Content-Type', 'application/json')
      )
      FROM users u;
    $$);
  END IF;
END $$;
