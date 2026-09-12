-- NeutraWise Gamification v2: Challenge Engine & Catalog Migration
-- Migration script 011_challenge_system_v2.sql

-- 1. Ensure user_challenges table supports v2 tracking fields
ALTER TABLE user_challenges ADD COLUMN IF NOT EXISTS days_passed INT DEFAULT 0;
ALTER TABLE user_challenges ADD COLUMN IF NOT EXISTS required_days INT DEFAULT 1;
ALTER TABLE user_challenges ADD COLUMN IF NOT EXISTS consecutive BOOLEAN DEFAULT FALSE;
ALTER TABLE user_challenges ADD COLUMN IF NOT EXISTS strategy VARCHAR DEFAULT 'APP_BEHAVIOR';
ALTER TABLE user_challenges ADD COLUMN IF NOT EXISTS status VARCHAR DEFAULT 'in_progress';
ALTER TABLE user_challenges ADD COLUMN IF NOT EXISTS completion_number INT DEFAULT 1;
ALTER TABLE user_challenges ADD COLUMN IF NOT EXISTS cooldown_ends_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE user_challenges ADD COLUMN IF NOT EXISTS xp_earned INT DEFAULT 0;
ALTER TABLE user_challenges ADD COLUMN IF NOT EXISTS completion_criteria JSONB DEFAULT '{}'::jsonb;

-- 1b. Challenge Daily Progress (Option B Spec: mutable qualification flag per day)
CREATE TABLE IF NOT EXISTS challenge_daily_progress (
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  challenge_id VARCHAR NOT NULL,
  date DATE NOT NULL,
  qualified BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
  PRIMARY KEY (user_id, challenge_id, date)
);

ALTER TABLE challenge_daily_progress ENABLE ROW LEVEL SECURITY;

DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can manage own challenge daily progress') THEN
    CREATE POLICY "Users can manage own challenge daily progress" ON challenge_daily_progress
      FOR ALL USING (auth.uid() = user_id);
  END IF;
END $$;

-- 2. Ensure challenges catalog table exists with complete v2 schema
CREATE TABLE IF NOT EXISTS challenges (
  id VARCHAR PRIMARY KEY,
  name VARCHAR NOT NULL,
  category VARCHAR NOT NULL,
  difficulty VARCHAR NOT NULL,
  duration_days INT NOT NULL DEFAULT 7,
  required_days INT NOT NULL DEFAULT 1,
  consecutive BOOLEAN DEFAULT FALSE,
  xp_reward INT NOT NULL DEFAULT 100,
  strategy VARCHAR NOT NULL DEFAULT 'APP_BEHAVIOR',
  completion_criteria JSONB DEFAULT '{}'::jsonb,
  description TEXT,
  icon_name VARCHAR DEFAULT 'eco',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

ALTER TABLE challenges ADD COLUMN IF NOT EXISTS duration_days INT NOT NULL DEFAULT 7;
ALTER TABLE challenges ADD COLUMN IF NOT EXISTS required_days INT NOT NULL DEFAULT 1;
ALTER TABLE challenges ADD COLUMN IF NOT EXISTS consecutive BOOLEAN DEFAULT FALSE;
ALTER TABLE challenges ADD COLUMN IF NOT EXISTS strategy VARCHAR NOT NULL DEFAULT 'APP_BEHAVIOR';
ALTER TABLE challenges ADD COLUMN IF NOT EXISTS completion_criteria JSONB DEFAULT '{}'::jsonb;
ALTER TABLE challenges ADD COLUMN IF NOT EXISTS icon_name VARCHAR DEFAULT 'eco';

-- Enable RLS on challenges table
ALTER TABLE challenges ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow authenticated read on challenges catalog" ON challenges FOR SELECT USING (auth.role() = 'authenticated');

-- 3. Seed/Upsert the 15 Standard Challenges (Section 6.7)
INSERT INTO challenges (id, name, category, difficulty, duration_days, required_days, consecutive, xp_reward, strategy, completion_criteria, description, icon_name)
VALUES
  ('no_car_day', 'No Car Day', 'Transport', 'Easy', 1, 1, false, 100, 'LOG_FIELD_ZERO', '{"field": "car_km"}'::jsonb, 'Zero car distance logged for 1 day.', 'directions_car'),
  ('no_car_weekend', 'No Car Weekend', 'Transport', 'Easy', 2, 2, true, 100, 'LOG_FIELD_ZERO', '{"field": "car_km", "start_day": "saturday"}'::jsonb, 'Zero car distance on Saturday & Sunday.', 'directions_car'),
  ('walk_7_days', 'Walk 7 Days', 'Transport', 'Easy', 10, 7, false, 100, 'TRANSPORT_ANY_MATCH', '{"accepted_values": ["walking"]}'::jsonb, 'Log walking trip on 7 separate days within 10 days.', 'directions_walk'),
  ('cycle_to_work_week', 'Cycle to Work Week', 'Transport', 'Medium', 7, 5, false, 200, 'TRANSPORT_ANY_MATCH', '{"accepted_values": ["cycling"]}'::jsonb, 'Log cycling trip on 5 days within 7 days.', 'directions_bike'),
  ('no_car_week', 'No Car Week', 'Transport', 'Medium', 10, 7, true, 200, 'LOG_FIELD_ZERO', '{"field": "car_km"}'::jsonb, 'Zero car distance for 7 consecutive days within 10 days.', 'directions_car'),
  ('carpool_champion', 'Carpool Champion', 'Transport', 'Medium', 7, 5, false, 200, 'TRANSPORT_ANY_MATCH', '{"accepted_values": ["rideshare"]}'::jsonb, 'Log rideshare/carpool trip on 5 days within 7 days.', 'directions_car'),
  ('public_transport_month', 'Public Transport Month', 'Transport', 'Hard', 35, 30, true, 400, 'TRANSPORT_ALL_MATCH', '{"accepted_values": ["bus", "train", "metro", "tram", "ferry"]}'::jsonb, 'All transport trips via public transit for 30 consecutive days within 35 days.', 'directions_bus'),
  ('meat_free_day', 'Meat-Free Day', 'Food', 'Easy', 1, 1, false, 100, 'FOOD_NONE_MATCH', '{"excluded_values": ["beef", "pork", "poultry", "chicken", "lamb", "fish", "seafood"]}'::jsonb, 'Zero meat/seafood logged for 1 day.', 'restaurant'),
  ('plant_based_week', 'Plant-Based Week', 'Food', 'Medium', 9, 7, true, 200, 'FOOD_ALL_MATCH', '{"accepted_values": ["vegetables", "legumes", "tofu", "soy", "fruit", "grains", "nuts", "seeds"]}'::jsonb, 'All food entries plant-based for 7 consecutive days within 9 days.', 'restaurant'),
  ('vegan_challenge', 'Vegan Challenge', 'Food', 'Hard', 35, 30, true, 400, 'FOOD_ALL_MATCH', '{"accepted_values": ["vegetables", "legumes", "tofu", "soy", "fruit", "grains", "nuts", "seeds"]}'::jsonb, 'All food entries plant-based for 30 consecutive days within 35 days.', 'restaurant'),
  ('unplug_day', 'Unplug Day', 'Energy', 'Easy', 1, 1, false, 100, 'LOG_TAG_PRESENT', '{"tag": "unplugged_devices"}'::jsonb, 'Log unplugged_devices tag for 1 day.', 'bolt'),
  ('cold_shower_week', 'Cold Shower Week', 'Energy', 'Easy', 10, 7, false, 100, 'LOG_TAG_PRESENT', '{"tag": "cold_shower"}'::jsonb, 'Log cold_shower tag on 7 days within 10 days.', 'shower'),
  ('screen_time_cutback', 'Screen Time Cutback', 'Energy', 'Easy', 10, 7, false, 100, 'LOG_TAG_PRESENT', '{"tag": "low_screen_time"}'::jsonb, 'Log low_screen_time tag on 7 days within 10 days.', 'smartphone'),
  ('no_ac_week', 'No AC Week', 'Energy', 'Medium', 7, 7, true, 200, 'LOG_TAG_ABSENT', '{"tag": "ac_used"}'::jsonb, 'No ac_used tag logged for 7 consecutive days.', 'ac_unit'),
  ('100_day_green_journey', '100-Day Green Journey', 'Nature', 'Hard', 100, 100, true, 400, 'APP_BEHAVIOR', '{"metric": "consecutive_active_days"}'::jsonb, 'Maintain an active daily log for 100 consecutive days.', 'park')
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  category = EXCLUDED.category,
  difficulty = EXCLUDED.difficulty,
  duration_days = EXCLUDED.duration_days,
  required_days = EXCLUDED.required_days,
  consecutive = EXCLUDED.consecutive,
  xp_reward = EXCLUDED.xp_reward,
  strategy = EXCLUDED.strategy,
  completion_criteria = EXCLUDED.completion_criteria,
  description = EXCLUDED.description,
  icon_name = EXCLUDED.icon_name;
