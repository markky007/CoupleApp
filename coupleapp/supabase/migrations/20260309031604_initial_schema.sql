-- ============================================================================
-- Couple Quest Database Schema
-- ============================================================================
-- This migration creates the initial database schema for the Couple Quest app
-- including tables, RLS policies, and helper functions.
-- ============================================================================

-- ============================================================================
-- TABLES
-- ============================================================================

-- Profiles: User profile data linked to auth.users
CREATE TABLE IF NOT EXISTS profiles (
  id UUID REFERENCES auth.users ON DELETE CASCADE PRIMARY KEY,
  display_name TEXT,
  partner_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  total_points INTEGER DEFAULT 0 CHECK (total_points >= 0),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Events: Special dates and anniversaries
CREATE TABLE IF NOT EXISTS events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL CHECK (char_length(title) > 0 AND char_length(title) <= 100),
  event_date DATE NOT NULL,
  is_recurring BOOLEAN DEFAULT FALSE,
  created_by UUID REFERENCES profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Quests: Tasks and chores
CREATE TABLE IF NOT EXISTS quests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL CHECK (char_length(title) > 0 AND char_length(title) <= 200),
  points INTEGER NOT NULL CHECK (points > 0 AND points <= 1000),
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'completed')),
  created_by UUID REFERENCES profiles(id) ON DELETE CASCADE,
  event_id UUID REFERENCES events(id) ON DELETE SET NULL,
  expire_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  completed_at TIMESTAMP WITH TIME ZONE
);

-- Rewards: Redeemable items
CREATE TABLE IF NOT EXISTS rewards (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL CHECK (char_length(title) > 0 AND char_length(title) <= 100),
  points_cost INTEGER NOT NULL CHECK (points_cost > 0 AND points_cost <= 10000),
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Transactions: Point transaction history (immutable audit trail)
CREATE TABLE IF NOT EXISTS transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('earn', 'redeem')),
  amount INTEGER NOT NULL CHECK (amount != 0),
  description TEXT NOT NULL CHECK (char_length(description) > 0 AND char_length(description) <= 200),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- INDEXES
-- ============================================================================

-- Profile indexes
CREATE INDEX IF NOT EXISTS idx_profiles_partner_id ON profiles(partner_id);

-- Quest indexes
CREATE INDEX IF NOT EXISTS idx_quests_created_by ON quests(created_by);
CREATE INDEX IF NOT EXISTS idx_quests_status ON quests(status);
CREATE INDEX IF NOT EXISTS idx_quests_event_id ON quests(event_id);
CREATE INDEX IF NOT EXISTS idx_quests_expire_at ON quests(expire_at);

-- Event indexes
CREATE INDEX IF NOT EXISTS idx_events_created_by ON events(created_by);
CREATE INDEX IF NOT EXISTS idx_events_event_date ON events(event_date);

-- Transaction indexes
CREATE INDEX IF NOT EXISTS idx_transactions_user_id ON transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_transactions_created_at ON transactions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_transactions_type ON transactions(type);

-- ============================================================================
-- FUNCTIONS
-- ============================================================================

-- Function to atomically update user points
-- Ensures points never go negative and provides transaction safety
CREATE OR REPLACE FUNCTION increment_user_points(
  user_id UUID,
  points_delta INTEGER
) RETURNS void AS $$
BEGIN
  UPDATE profiles
  SET 
    total_points = total_points + points_delta,
    updated_at = NOW()
  WHERE id = user_id
  AND total_points + points_delta >= 0;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Insufficient points or user not found';
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- TRIGGERS
-- ============================================================================

-- Trigger to automatically update updated_at on profiles
CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Trigger to automatically update updated_at on events
CREATE TRIGGER update_events_updated_at
  BEFORE UPDATE ON events
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Trigger to automatically update updated_at on rewards
CREATE TRIGGER update_rewards_updated_at
  BEFORE UPDATE ON rewards
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================================

-- Enable RLS on all tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE events ENABLE ROW LEVEL SECURITY;
ALTER TABLE quests ENABLE ROW LEVEL SECURITY;
ALTER TABLE rewards ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- PROFILES POLICIES
-- ============================================================================

-- Users can view their own profile and their partner's profile
CREATE POLICY "Users can view own and partner profile"
  ON profiles FOR SELECT
  USING (
    auth.uid() = id OR 
    auth.uid() = partner_id
  );

-- Users can insert their own profile (during signup)
CREATE POLICY "Users can insert own profile"
  ON profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

-- Users can update their own profile
CREATE POLICY "Users can update own profile"
  ON profiles FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- ============================================================================
-- EVENTS POLICIES
-- ============================================================================

-- Users can view events created by themselves or their partner
CREATE POLICY "Users can view shared events"
  ON events FOR SELECT
  USING (
    auth.uid() = created_by OR
    auth.uid() IN (
      SELECT partner_id FROM profiles WHERE id = created_by
    )
  );

-- Users can create events
CREATE POLICY "Users can create events"
  ON events FOR INSERT
  WITH CHECK (auth.uid() = created_by);

-- Users can update their own events
CREATE POLICY "Users can update own events"
  ON events FOR UPDATE
  USING (auth.uid() = created_by)
  WITH CHECK (auth.uid() = created_by);

-- Users can delete their own events
CREATE POLICY "Users can delete own events"
  ON events FOR DELETE
  USING (auth.uid() = created_by);

-- ============================================================================
-- QUESTS POLICIES
-- ============================================================================

-- Users can view quests created by themselves or their partner
CREATE POLICY "Users can view shared quests"
  ON quests FOR SELECT
  USING (
    auth.uid() = created_by OR
    auth.uid() IN (
      SELECT partner_id FROM profiles WHERE id = created_by
    )
  );

-- Users can create quests
CREATE POLICY "Users can create quests"
  ON quests FOR INSERT
  WITH CHECK (auth.uid() = created_by);

-- Users can update quests (for completion)
-- Only allow status updates to 'completed' for pending quests
CREATE POLICY "Users can complete quests"
  ON quests FOR UPDATE
  USING (
    status = 'pending' AND
    (auth.uid() = created_by OR
     auth.uid() IN (SELECT partner_id FROM profiles WHERE id = created_by))
  )
  WITH CHECK (
    status = 'completed'
  );

-- Users can delete their own quests
CREATE POLICY "Users can delete own quests"
  ON quests FOR DELETE
  USING (auth.uid() = created_by);

-- ============================================================================
-- REWARDS POLICIES
-- ============================================================================

-- All authenticated users can view active rewards
CREATE POLICY "Users can view active rewards"
  ON rewards FOR SELECT
  USING (is_active = true);

-- Only service role can manage rewards (admin function)
-- This policy allows INSERT/UPDATE/DELETE only via service role key
CREATE POLICY "Service role can manage rewards"
  ON rewards FOR ALL
  USING (auth.jwt()->>'role' = 'service_role');

-- ============================================================================
-- TRANSACTIONS POLICIES
-- ============================================================================

-- Users can view their own transactions
CREATE POLICY "Users can view own transactions"
  ON transactions FOR SELECT
  USING (auth.uid() = user_id);

-- Users can view their partner's transactions
CREATE POLICY "Users can view partner transactions"
  ON transactions FOR SELECT
  USING (
    auth.uid() IN (
      SELECT partner_id FROM profiles WHERE id = user_id
    )
  );

-- Only system can insert transactions (via functions)
-- This prevents direct manipulation of transaction history
CREATE POLICY "System can insert transactions"
  ON transactions FOR INSERT
  WITH CHECK (auth.jwt()->>'role' = 'service_role');

-- Transactions are immutable - no updates or deletes allowed
-- (No UPDATE or DELETE policies = no one can modify/delete)

-- ============================================================================
-- INITIAL DATA (Optional)
-- ============================================================================

-- Insert some sample rewards for testing
INSERT INTO rewards (title, points_cost, is_active) VALUES
  ('Movie Night', 50, true),
  ('Dinner Date', 100, true),
  ('Weekend Getaway', 500, true),
  ('Spa Day', 200, true),
  ('Concert Tickets', 300, true)
ON CONFLICT DO NOTHING;