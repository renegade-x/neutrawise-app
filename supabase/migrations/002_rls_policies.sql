-- Enable RLS on all user-specific tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE badges ENABLE ROW LEVEL SECURITY;
ALTER TABLE streaks ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_challenges ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_preferences ENABLE ROW LEVEL SECURITY;

-- users table
CREATE POLICY "Users see only their own record" ON users
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update their own record" ON users
  FOR UPDATE USING (auth.uid() = id);

-- daily_logs table (most restrictive)
CREATE POLICY "Users see only their own logs" ON daily_logs
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own logs" ON daily_logs
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own logs" ON daily_logs
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own logs" ON daily_logs
  FOR DELETE USING (auth.uid() = user_id);

-- badges
CREATE POLICY "Users see only their own badges" ON badges
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own badges" ON badges
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- streaks
CREATE POLICY "Users see only their own streaks" ON streaks
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own streaks" ON streaks
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own streaks" ON streaks
  FOR UPDATE USING (auth.uid() = user_id);

-- user_challenges
CREATE POLICY "Users see only their own challenges" ON user_challenges
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own challenges" ON user_challenges
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own challenges" ON user_challenges
  FOR UPDATE USING (auth.uid() = user_id);

-- leaderboard_rankings is readable by anyone (public)
ALTER TABLE leaderboard_rankings DISABLE ROW LEVEL SECURITY;

-- notification_preferences
CREATE POLICY "Users manage their own preferences" ON notification_preferences
  FOR ALL USING (auth.uid() = user_id);
