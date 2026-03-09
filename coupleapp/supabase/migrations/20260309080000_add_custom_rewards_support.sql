-- ============================================================================
-- Add Custom Rewards Support with Partner Approval Workflow
-- ============================================================================
-- This migration extends the rewards table to support user-generated custom
-- rewards that require partner approval before becoming active.
-- ============================================================================

-- Add new columns to rewards table
ALTER TABLE rewards 
  ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES profiles(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'approved' CHECK (status IN ('pending', 'approved', 'rejected')),
  ADD COLUMN IF NOT EXISTS is_system_reward BOOLEAN DEFAULT FALSE;

-- Create indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_rewards_created_by ON rewards(created_by);
CREATE INDEX IF NOT EXISTS idx_rewards_status ON rewards(status);
CREATE INDEX IF NOT EXISTS idx_rewards_is_system_reward ON rewards(is_system_reward);

-- ============================================================================
-- Set default values for existing rewards
-- ============================================================================
-- Mark all existing rewards as system rewards with approved status
UPDATE rewards 
SET 
  status = 'approved',
  is_system_reward = TRUE,
  created_by = NULL
WHERE is_system_reward IS NULL OR is_system_reward = FALSE;

-- ============================================================================
-- Row Level Security Policies
-- ============================================================================

-- Enable RLS on rewards table
ALTER TABLE rewards ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS "Users can view accessible rewards" ON rewards;
DROP POLICY IF EXISTS "Users can create custom rewards" ON rewards;
DROP POLICY IF EXISTS "Partners can update pending rewards" ON rewards;

-- Policy 1: Users can view system rewards and their own custom rewards
-- System rewards are visible to all users
-- Custom rewards are only visible to creator and their partner
CREATE POLICY "Users can view accessible rewards"
  ON rewards FOR SELECT
  USING (
    is_system_reward = TRUE OR
    auth.uid() = created_by OR
    auth.uid() IN (
      SELECT partner_id 
      FROM profiles 
      WHERE id = created_by AND partner_id IS NOT NULL
    )
  );

-- Policy 2: Users can create custom rewards
-- Only authenticated users can create rewards
-- Custom rewards must have status='pending' and is_system_reward=false
CREATE POLICY "Users can create custom rewards"
  ON rewards FOR INSERT
  WITH CHECK (
    auth.uid() = created_by AND
    is_system_reward = FALSE AND
    status = 'pending'
  );

-- Policy 3: Partners can approve or reject pending rewards
-- Only the partner of the creator can update pending rewards
-- Can only change status from 'pending' to 'approved' or 'rejected'
CREATE POLICY "Partners can update pending rewards"
  ON rewards FOR UPDATE
  USING (
    status = 'pending' AND
    auth.uid() IN (
      SELECT partner_id 
      FROM profiles 
      WHERE id = created_by AND partner_id IS NOT NULL
    )
  )
  WITH CHECK (
    status IN ('approved', 'rejected')
  );

-- ============================================================================
-- Verification
-- ============================================================================

DO $$
DECLARE
  total_rewards INTEGER;
  system_rewards INTEGER;
  custom_rewards INTEGER;
BEGIN
  SELECT COUNT(*) INTO total_rewards FROM rewards;
  SELECT COUNT(*) INTO system_rewards FROM rewards WHERE is_system_reward = TRUE;
  SELECT COUNT(*) INTO custom_rewards FROM rewards WHERE is_system_reward = FALSE;
  
  RAISE NOTICE 'Total rewards: %', total_rewards;
  RAISE NOTICE 'System rewards: %', system_rewards;
  RAISE NOTICE 'Custom rewards: %', custom_rewards;
  RAISE NOTICE 'Custom rewards support migration completed successfully ✓';
END $$;
