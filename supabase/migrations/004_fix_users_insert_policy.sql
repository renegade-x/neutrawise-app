-- Fix RLS: Allow users to insert their own profile during onboarding
CREATE POLICY "Users can insert their own record" ON users
  FOR INSERT WITH CHECK (auth.uid() = id);
