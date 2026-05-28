-- Users (extends auth.users)
CREATE TABLE users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  email TEXT UNIQUE,
  city TEXT,
  country_code CHAR(2),
  avatar_url TEXT,
  
  -- Transport profile
  primary_transport TEXT CHECK (primary_transport IN ('car', 'ev', 'motorcycle', 'bus', 'train', 'metro', 'bicycle', 'walking', 'ferry', 'taxi', 'rideshare')),
  fuel_type TEXT,
  engine_size TEXT,
  vehicle_age TEXT,
  vehicle_model TEXT,
  avg_daily_km NUMERIC,
  transport_factor NUMERIC,
  
  -- Energy profile
  home_type TEXT,
  residents INT,
  heating_type TEXT,
  has_solar BOOLEAN,
  daily_energy_baseline_kwh NUMERIC,
  daily_heating_baseline_co2 NUMERIC,
  daily_energy_baseline_co2 NUMERIC,
  grid_intensity NUMERIC,
  
  -- Food profile
  dietary_preference TEXT,
  daily_food_baseline_co2 NUMERIC,
  
  -- Aggregate baseline
  total_daily_baseline_co2 NUMERIC,
  
  -- Gamification
  xp INT DEFAULT 0,
  level INT DEFAULT 1,
  current_streak INT DEFAULT 0,
  longest_streak INT DEFAULT 0,
  days_active INT DEFAULT 0,
  streak_freeze_count INT DEFAULT 0,
  
  -- Progress
  total_co2_saved NUMERIC DEFAULT 0,
  
  -- Settings
  dark_mode_enabled BOOLEAN DEFAULT FALSE,
  notifications_enabled BOOLEAN DEFAULT TRUE,
  quiet_hours_start TIME,
  quiet_hours_end TIME,
  
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Daily logs (activity submissions)
CREATE TABLE daily_logs (
  id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  date DATE NOT NULL,
  
  -- Transport entries (JSON array)
  transport_entries JSONB,
  transport_co2 NUMERIC,
  
  -- Food entries (JSON array)
  food_entries JSONB,
  food_co2 NUMERIC,
  
  -- Energy deviations (JSON)
  energy_deviations JSONB,
  energy_co2 NUMERIC,
  
  -- Results
  total_daily_co2 NUMERIC,
  baseline_co2 NUMERIC,
  co2_saved_vs_baseline NUMERIC,
  percent_vs_baseline NUMERIC,
  xp_earned INT,
  emission_factor_version VARCHAR,
  
  client_timestamp TIMESTAMP,
  server_timestamp TIMESTAMP DEFAULT NOW(),

  created_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(user_id, date)
);

-- Streaks (track streaks per user)
CREATE TABLE streaks (
  id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  current_streak INT DEFAULT 0,
  longest_streak INT DEFAULT 0,
  last_log_date DATE,
  streak_freeze_used_at TIMESTAMP,
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Badges earned
CREATE TABLE badges (
  id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  badge_name VARCHAR NOT NULL,
  badge_tier VARCHAR, -- 'bronze', 'silver', 'gold', or null for special badges
  earned_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(user_id, badge_name, badge_tier)
);

-- Active challenges
CREATE TABLE user_challenges (
  id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  challenge_id VARCHAR NOT NULL, -- reference to challenge library
  challenge_name VARCHAR NOT NULL,
  category VARCHAR NOT NULL,
  difficulty VARCHAR NOT NULL,
  duration_days INT,
  completion_criteria JSONB,
  xp_reward INT,
  started_at TIMESTAMP DEFAULT NOW(),
  completed_at TIMESTAMP,
  progress_percent INT DEFAULT 0,
  UNIQUE(user_id, challenge_id)
);

-- Leaderboard rankings (reporting table)
CREATE TABLE leaderboard_rankings (
  id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  xp INT NOT NULL,
  level INT NOT NULL,
  global_rank INT,
  city_rank INT,
  weekly_rank INT,
  leaderboard_type VARCHAR NOT NULL, -- 'global', 'city', 'weekly_sprint'
  period_start DATE NOT NULL,
  period_end DATE NOT NULL,
  updated_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(user_id, leaderboard_type, period_start)
);

-- Social graph (friendships; empty in v1)
CREATE TABLE user_relations (
  id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  related_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  relation_type VARCHAR CHECK (relation_type IN ('friend', 'blocked')),
  created_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(user_id, related_user_id),
  CHECK(user_id != related_user_id)
);

-- Push notification preferences
CREATE TABLE notification_preferences (
  id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  daily_log_reminder BOOLEAN DEFAULT TRUE,
  streak_warnings BOOLEAN DEFAULT TRUE,
  challenge_reminders BOOLEAN DEFAULT TRUE,
  leaderboard_overtake BOOLEAN DEFAULT TRUE,
  quiz_available BOOLEAN DEFAULT TRUE,
  badge_earned BOOLEAN DEFAULT TRUE,
  level_up BOOLEAN DEFAULT TRUE,
  weekly_summary BOOLEAN DEFAULT TRUE,
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Indices for common queries
CREATE INDEX idx_daily_logs_user_date ON daily_logs(user_id, date DESC);
CREATE INDEX idx_badges_user ON badges(user_id);
CREATE INDEX idx_user_challenges_user ON user_challenges(user_id, completed_at);
CREATE INDEX idx_user_relations ON user_relations(user_id, relation_type);
