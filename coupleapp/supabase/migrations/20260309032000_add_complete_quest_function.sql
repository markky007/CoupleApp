-- ============================================================================
-- Add atomic quest completion function
-- ============================================================================
-- This migration adds a PostgreSQL function to handle quest completion
-- atomically, ensuring all operations succeed or rollback together.
-- ============================================================================

-- Function to atomically complete a quest
-- Performs: quest status update, point award, and transaction record creation
-- All operations succeed together or rollback on any failure
CREATE OR REPLACE FUNCTION complete_quest_atomic(
  p_quest_id UUID,
  p_user_id UUID
) RETURNS jsonb AS $$
DECLARE
  v_quest RECORD;
  v_transaction_id UUID;
BEGIN
  -- Step 1: Fetch and validate quest (with row lock)
  SELECT * INTO v_quest
  FROM quests
  WHERE id = p_quest_id
  FOR UPDATE;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Quest not found';
  END IF;
  
  -- Validate quest status
  IF v_quest.status != 'pending' THEN
    RAISE EXCEPTION 'Quest already completed';
  END IF;
  
  -- Validate quest not expired
  IF v_quest.expire_at IS NOT NULL AND v_quest.expire_at < NOW() THEN
    RAISE EXCEPTION 'Quest has expired';
  END IF;
  
  -- Step 2: Update quest status to completed
  UPDATE quests
  SET 
    status = 'completed',
    completed_at = NOW()
  WHERE id = p_quest_id;
  
  -- Step 3: Award points to user (atomic via increment_user_points)
  PERFORM increment_user_points(p_user_id, v_quest.points);
  
  -- Step 4: Create transaction record
  INSERT INTO transactions (user_id, type, amount, description)
  VALUES (
    p_user_id,
    'earn',
    v_quest.points,
    'Completed quest: ' || v_quest.title
  )
  RETURNING id INTO v_transaction_id;
  
  -- Return success with details
  RETURN jsonb_build_object(
    'success', true,
    'quest_id', p_quest_id,
    'points_awarded', v_quest.points,
    'transaction_id', v_transaction_id
  );
  
EXCEPTION
  WHEN OTHERS THEN
    -- Any error will cause automatic rollback
    RAISE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

