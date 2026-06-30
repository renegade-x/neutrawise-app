-- Drop restrictive SELECT policies
DROP POLICY IF EXISTS "Users see only their own record" ON users;
DROP POLICY IF EXISTS "Users see only their own logs" ON daily_logs;

-- Create public/authenticated SELECT policies for leaderboard visibility
CREATE POLICY "Anyone can view user profiles" ON users
  FOR SELECT USING (true);

CREATE POLICY "Anyone can view daily logs" ON daily_logs
  FOR SELECT USING (true);
