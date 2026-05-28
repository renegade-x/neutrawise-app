-- Trigger: Send push when user levels up
CREATE OR REPLACE FUNCTION notify_level_up()
RETURNS TRIGGER AS $$
DECLARE
  level_title TEXT;
BEGIN
  IF NEW.level > OLD.level THEN
    -- In a real scenario we could lookup from a titles table, here we just use generic
    level_title := 'Level ' || NEW.level;
    
    SELECT net.http_post(
      url := 'https://your-project.supabase.co/functions/v1/schedule_push_notification',
      payload := json_build_object(
        'type', 'level_up',
        'user_id', NEW.id,
        'data', json_build_object(
          'new_level', NEW.level,
          'level_title', level_title
        )
      )::text,
      headers := json_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || current_setting('app.jwt_secret', true)
      )
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_level_up
AFTER UPDATE ON users
FOR EACH ROW
WHEN (NEW.level > OLD.level)
EXECUTE FUNCTION notify_level_up();

-- Trigger: Send push when badge earned
CREATE OR REPLACE FUNCTION notify_badge_earned()
RETURNS TRIGGER AS $$
BEGIN
  SELECT net.http_post(
    url := 'https://your-project.supabase.co/functions/v1/schedule_push_notification',
    payload := json_build_object(
      'type', 'badge_earned',
      'user_id', NEW.user_id,
      'data', json_build_object('badge_name', NEW.badge_name)
    )::text,
    headers := json_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('app.jwt_secret', true)
    )
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_badge_earned
AFTER INSERT ON badges
FOR EACH ROW
EXECUTE FUNCTION notify_badge_earned();

-- We can also add cron jobs here if pg_cron is enabled
-- SELECT cron.schedule('daily_log_reminder', '0 20 * * *', $$ ... $$);
