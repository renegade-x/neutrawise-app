-- =======================================================================
-- NEUTRAWISE DATABASE STABILIZATION SCRIPT
-- Run this in your Supabase SQL Editor to resolve RLS policies and trigger issues.
-- =======================================================================

-- 1. FIX LEADERBOARD VISIBILITY (RLS Policies)
-- Allow all authenticated users to read profiles and daily logs so the leaderboard works.
DROP POLICY IF EXISTS "Users see only their own record" ON users;
DROP POLICY IF EXISTS "Users see only their own logs" ON daily_logs;

CREATE POLICY "Anyone can view user profiles" ON users
  FOR SELECT USING (true);

CREATE POLICY "Anyone can view daily logs" ON daily_logs
  FOR SELECT USING (true);

-- 2. FIX PUSH NOTIFICATION TRIGGERS (Schema net check & exception handling)
-- Prevents level-up and badge earning updates from crashing when pg_net/net schema is missing or remote functions fail.
DROP TRIGGER IF EXISTS on_level_up ON users;
DROP TRIGGER IF EXISTS on_badge_earned ON badges;

-- Recreate notify_level_up function with dynamic schema check and error handling
CREATE OR REPLACE FUNCTION notify_level_up()
RETURNS TRIGGER AS $$
DECLARE
  level_title TEXT;
BEGIN
  IF NEW.level > OLD.level THEN
    level_title := 'Level ' || NEW.level;
    
    -- Only attempt to call pg_net HTTP functions if schema 'net' exists
    IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'net') THEN
      BEGIN
        EXECUTE 'SELECT net.http_post(
          url := $1,
          payload := $2,
          headers := $3
        )' USING 
          'https://psztwkbfhwehmesschbk.supabase.co/functions/v1/schedule_push_notification',
          json_build_object(
            'type', 'level_up',
            'user_id', NEW.id,
            'data', json_build_object(
              'new_level', NEW.level,
              'level_title', level_title
            )
          )::text,
          json_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || current_setting('app.jwt_secret', true)
          );
      EXCEPTION WHEN OTHERS THEN
        -- Silently handle any execution errors (e.g. offline, connection failure)
        NULL;
      END;
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Recreate notify_badge_earned function with dynamic schema check and error handling
CREATE OR REPLACE FUNCTION notify_badge_earned()
RETURNS TRIGGER AS $$
BEGIN
  -- Only attempt to call pg_net HTTP functions if schema 'net' exists
  IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'net') THEN
    BEGIN
      EXECUTE 'SELECT net.http_post(
        url := $1,
        payload := $2,
        headers := $3
      )' USING
        'https://psztwkbfhwehmesschbk.supabase.co/functions/v1/schedule_push_notification',
        json_build_object(
          'type', 'badge_earned',
          'user_id', NEW.user_id,
          'data', json_build_object('badge_name', NEW.badge_name)
        )::text,
        json_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || current_setting('app.jwt_secret', true)
        );
    EXCEPTION WHEN OTHERS THEN
      -- Silently handle any execution errors
      NULL;
    END;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Re-establish the triggers
CREATE TRIGGER on_level_up
  AFTER UPDATE ON users
  FOR EACH ROW
  WHEN (NEW.level > OLD.level)
  EXECUTE FUNCTION notify_level_up();

CREATE TRIGGER on_badge_earned
  AFTER INSERT ON badges
  FOR EACH ROW
  EXECUTE FUNCTION notify_badge_earned();
