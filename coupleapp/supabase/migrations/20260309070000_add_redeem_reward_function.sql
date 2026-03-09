-- ============================================================================
-- Add atomic reward redemption function
-- ============================================================================
-- This migration adds a PostgreSQL function to handle reward redemption
-- atomically, ensuring all operations succeed or rollback together.
-- ============================================================================

-- Function to atomically redeem a reward
-- Performs: balance validation, point deduction, and transaction record creation
-- All operations succeed together or rollback on any failure
CREATE OR REPLACE FUNCTION redeem_reward_atomic(
  p_reward_id UUID,
  p_user_id UUID
) RETURNS jsonb AS $$
DECLARE
  v_reward RECORD;
  v_profile RECORD;
  v_transaction_id UUID;
BEGIN
  -- Step 1: Fetch and validate reward
  SELECT * INTO v_reward
  FROM rewards
  WHERE id = p_reward_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Reward not found';
  END IF;
  
  -- Validate reward is active
  IF v_reward.is_active != true THEN
    RAISE EXCEPTION 'Reward is not active';
  END IF;
  
  -- Step 2: Fetch user profile and check balance (with row lock)
  SELECT * INTO v_profile
  FROM profiles
  WHERE id = p_user_id
  FOR UPDATE;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'User profile not found';
  END IF;
  
  -- Validate sufficient balance
  IF v_profile.total_points < v_reward.points_cost THEN
    RAISE EXCEPTION 'Insufficient points. Required: %, Available: %', 
      v_reward.points_cost, v_profile.total_points;
  END IF;
  
  -- Step 3: Deduct points from user (atomic via increment_user_points)
  PERFORM increment_user_points(p_user_id, -v_reward.points_cost);
  
  -- Step 4: Create transaction record
  INSERT INTO transactions (user_id, type, amount, description)
  VALUES (
    p_user_id,
    'redeem',
    -v_reward.points_cost,
    'Redeemed: ' || v_reward.title
  )
  RETURNING id INTO v_transaction_id;
  
  -- Return success with details
  RETURN jsonb_build_object(
    'success', true,
    'reward_id', p_reward_id,
    'points_deducted', v_reward.points_cost,
    'transaction_id', v_transaction_id
  );
  
EXCEPTION
  WHEN OTHERS THEN
    -- Any error will cause automatic rollback
    RAISE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
