-- Migration 009: Live Content Tables (Question Bank, Challenges Catalog, Badge Catalog)

-- 1. Question Bank Table
CREATE TABLE IF NOT EXISTS question_bank (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  topic TEXT NOT NULL,
  text TEXT NOT NULL,
  options JSONB NOT NULL,
  correct_index INT NOT NULL,
  explanation TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Challenges Catalog Table
CREATE TABLE IF NOT EXISTS challenges (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  category TEXT NOT NULL,
  difficulty TEXT NOT NULL,
  duration_days INT NOT NULL,
  co2_reduction_estimate NUMERIC NOT NULL,
  xp_reward INT NOT NULL,
  icon_name TEXT DEFAULT 'eco',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Badge Catalog Table
CREATE TABLE IF NOT EXISTS badge_catalog (
  id TEXT PRIMARY KEY,
  badge_name TEXT NOT NULL,
  category TEXT NOT NULL,
  description TEXT NOT NULL,
  icon_name TEXT DEFAULT 'stars',
  is_special BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE question_bank ENABLE ROW LEVEL SECURITY;
ALTER TABLE challenges ENABLE ROW LEVEL SECURITY;
ALTER TABLE badge_catalog ENABLE ROW LEVEL SECURITY;

-- Public read policies
DROP POLICY IF EXISTS "Anyone can view question bank" ON question_bank;
CREATE POLICY "Anyone can view question bank" ON question_bank
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Anyone can view challenges catalog" ON challenges;
CREATE POLICY "Anyone can view challenges catalog" ON challenges
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Anyone can view badge catalog" ON badge_catalog;
CREATE POLICY "Anyone can view badge catalog" ON badge_catalog
  FOR SELECT USING (true);

-- Seed Initial Challenges Catalog
INSERT INTO challenges (id, name, description, category, difficulty, duration_days, co2_reduction_estimate, xp_reward, icon_name)
VALUES
  ('car_free_week', 'Car-Free Week', 'Commute via public transport, walking, or cycling for 7 consecutive days.', 'Transport', 'Medium', 7, 15.0, 300, 'directions_car'),
  ('meatless_mondays', 'Meatless Mondays', 'Eat plant-based meals every Monday for 4 consecutive weeks.', 'Food', 'Easy', 30, 8.0, 200, 'restaurant'),
  ('zero_vampire_draw', 'Zero Vampire Draw', 'Unplug all unused appliances and electronics every night for 14 days.', 'Energy', 'Easy', 14, 5.0, 150, 'bolt'),
  ('vegan_month', '30-Day Vegan Challenge', 'Adopt a complete plant-based diet for 30 consecutive days.', 'Food', 'Hard', 30, 45.0, 500, 'restaurant')
ON CONFLICT (id) DO NOTHING;

-- Seed Initial Badge Catalog
INSERT INTO badge_catalog (id, badge_name, category, description, icon_name, is_special)
VALUES
  ('b1', 'Green Commuter', 'Transport', 'Logged 10 low-carbon transport journeys', 'directions_car', FALSE),
  ('b2', 'Plant Powered', 'Food', 'Logged 14 plant-based meals', 'restaurant', FALSE),
  ('b3', 'Energy Saver', 'Energy', 'Confirmed household energy deviations 7 times', 'bolt', FALSE),
  ('b4', 'Eco Citizen', 'General', 'Logged activities consistently for 14 days', 'eco', FALSE),
  ('b5', 'Zero Waste Hero', 'Consumption', 'Completed 3 recycling/reuse challenges', 'shopping_bag', FALSE),
  ('s1', 'Week Warrior ⚔️', 'Special', 'Maintained a 7-day logging streak', 'local_fire_department', TRUE),
  ('s2', 'Monthly Maven 📅', 'Special', 'Maintained a 30-day logging streak', 'calendar_today', TRUE),
  ('s3', 'Century Eco 💯', 'Special', 'Saved 100 kg total CO₂', 'workspace_premium', TRUE),
  ('s4', 'Quiz Whiz 🧠', 'Special', 'Scored 5 perfect quiz attempts', 'psychology', TRUE),
  ('s5', 'All-Rounder 🌟', 'Special', 'Logged in all categories within a single week', 'star', TRUE),
  ('s6', 'Carbon Neutral 🌳', 'Special', 'Offset 100% of weekly baseline emissions', 'park', TRUE),
  ('s7', 'Leaderboard Leader 👑', 'Special', 'Reached #1 on the Global Leaderboard', 'emoji_events', TRUE),
  ('s8', 'Streak Saver 🛡️', 'Special', 'Used a streak freeze to preserve a streak', 'shield', TRUE)
ON CONFLICT (id) DO NOTHING;

-- Seed Initial Question Bank
INSERT INTO question_bank (topic, text, options, correct_index, explanation)
VALUES
  ('Transport', 'Which vehicle type produces the least CO₂ per km?', '["Petrol car", "Diesel car", "Electric vehicle", "Motorcycle"]'::jsonb, 2, 'EVs emit 0 direct tailpipe emissions and significantly lower lifecycle CO₂.'),
  ('Food', 'Which food has the highest carbon footprint per 100g?', '["Lentils", "Chicken", "Beef", "Tofu"]'::jsonb, 2, 'Beef generates over 20-30x more greenhouse gases per 100g than plant proteins.'),
  ('Energy', 'What does "phantom load" mean in household energy?', '["Energy lost in transmission", "Electricity consumed by devices on standby", "Peak usage during hot days", "Solar inverter loss"]'::jsonb, 1, 'Standby power draw from plugged-in appliances accounts for up to 10% of home energy.'),
  ('Climate Science', 'What is the primary greenhouse gas emitted by human activities?', '["Oxygen", "Methane", "Carbon Dioxide (CO₂)", "Nitrogen"]'::jsonb, 2, 'CO₂ makes up over 75% of global human-caused greenhouse gas emissions.'),
  ('Energy', 'Lowering your thermostat by 1°C can reduce heating bills by approx:', '["0.5%", "10%", "30%", "50%"]'::jsonb, 1, 'Each 1°C reduction saves approximately 10% on annual space heating emissions and costs.')
ON CONFLICT DO NOTHING;
