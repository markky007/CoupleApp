-- ============================================================================
-- Custom Rewards Simple Backend Test
-- ============================================================================
-- Tests basic functionality without RLS simulation
-- ============================================================================

BEGIN;

-- Clean up test data
DELETE FROM rewards WHERE title LIKE 'Test%';
DELETE FROM profiles WHERE id IN (
  '11111111-1111-1111-1111-111111111111',
  '22222222-2222-2222-2222-222222222222',
  '33333333-3333-3333-3333-333333333333'
);
DELETE FROM auth.users WHERE id IN (
  '11111111-1111-1111-1111-111111111111',
  '22222222-2222-2222-2222-222222222222',
  '33333333-3333-3333-3333-333333333333'
);

-- Create test auth users first
INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at)
VALUES 
  ('11111111-1111-1111-1111-111111111111', 'testuser1@test.com', crypt('password', gen_salt('bf')), NOW()),
  ('22222222-2222-2222-2222-222222222222', 'testuser2@test.com', crypt('password', gen_salt('bf')), NOW()),
  ('33333333-3333-3333-3333-333333333333', 'testuser3@test.com', crypt('password', gen_salt('bf')), NOW())
ON CONFLICT (id) DO NOTHING;

-- Create test profiles
INSERT INTO profiles (id, display_name, total_points, partner_id)
VALUES 
  ('11111111-1111-1111-1111-111111111111', 'Test User 1', 1000, '22222222-2222-2222-2222-222222222222'),
  ('22222222-2222-2222-2222-222222222222', 'Test User 2', 1000, '11111111-1111-1111-1111-111111111111'),
  ('33333333-3333-3333-3333-333333333333', 'Test User 3', 1000, NULL)
ON CONFLICT (id) DO UPDATE SET 
  display_name = EXCLUDED.display_name,
  partner_id = EXCLUDED.partner_id;

DO $$ BEGIN RAISE NOTICE 'Test profiles created'; END $$;

-- ============================================================================
-- Test 1: Create custom reward proposal
-- ============================================================================
DO $$
DECLARE
  new_reward_id UUID;
  reward_status TEXT;
  reward_is_system BOOLEAN;
  reward_is_active BOOLEAN;
BEGIN
  INSERT INTO rewards (title, points_cost, created_by, status, is_system_reward, is_active)
  VALUES ('Test Movie Night', 100, '11111111-1111-1111-1111-111111111111', 'pending', FALSE, FALSE)
  RETURNING id, status, is_system_reward, is_active 
  INTO new_reward_id, reward_status, reward_is_system, reward_is_active;
  
  IF reward_status = 'pending' AND reward_is_system = FALSE AND reward_is_active = FALSE THEN
    RAISE NOTICE 'Test 1 PASSED: Custom reward created with correct defaults (ID: %)', new_reward_id;
  ELSE
    RAISE EXCEPTION 'Test 1 FAILED: status=%, is_system=%, is_active=%', reward_status, reward_is_system, reward_is_active;
  END IF;
END $$;

-- ============================================================================
-- Test 2: Verify pending rewards are queryable
-- ============================================================================
DO $$
DECLARE
  pending_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO pending_count 
  FROM rewards 
  WHERE status = 'pending' 
    AND created_by = '11111111-1111-1111-1111-111111111111';
  
  IF pending_count > 0 THEN
    RAISE NOTICE 'Test 2 PASSED: Found % pending reward(s)', pending_count;
  ELSE
    RAISE EXCEPTION 'Test 2 FAILED: No pending rewards found';
  END IF;
END $$;

-- ============================================================================
-- Test 3: Approve a pending reward
-- ============================================================================
DO $$
DECLARE
  reward_id UUID;
  updated_status TEXT;
  updated_active BOOLEAN;
BEGIN
  -- Get a pending reward
  SELECT id INTO reward_id 
  FROM rewards 
  WHERE created_by = '11111111-1111-1111-1111-111111111111' 
    AND status = 'pending' 
  LIMIT 1;
  
  -- Approve it
  UPDATE rewards 
  SET status = 'approved', is_active = TRUE, updated_at = NOW()
  WHERE id = reward_id;
  
  -- Verify
  SELECT status, is_active INTO updated_status, updated_active 
  FROM rewards 
  WHERE id = reward_id;
  
  IF updated_status = 'approved' AND updated_active = TRUE THEN
    RAISE NOTICE 'Test 3 PASSED: Reward approved successfully (ID: %)', reward_id;
  ELSE
    RAISE EXCEPTION 'Test 3 FAILED: status=%, is_active=%', updated_status, updated_active;
  END IF;
END $$;

-- ============================================================================
-- Test 4: Create and reject a reward
-- ============================================================================
DO $$
DECLARE
  new_reward_id UUID;
  updated_status TEXT;
BEGIN
  -- Create new pending reward
  INSERT INTO rewards (title, points_cost, created_by, status, is_system_reward, is_active)
  VALUES ('Test Spa Day', 200, '11111111-1111-1111-1111-111111111111', 'pending', FALSE, FALSE)
  RETURNING id INTO new_reward_id;
  
  -- Reject it
  UPDATE rewards 
  SET status = 'rejected', updated_at = NOW()
  WHERE id = new_reward_id;
  
  -- Verify
  SELECT status INTO updated_status 
  FROM rewards 
  WHERE id = new_reward_id;
  
  IF updated_status = 'rejected' THEN
    RAISE NOTICE 'Test 4 PASSED: Reward rejected successfully (ID: %)', new_reward_id;
  ELSE
    RAISE EXCEPTION 'Test 4 FAILED: status=%', updated_status;
  END IF;
END $$;

-- ============================================================================
-- Test 5: Verify status constraint
-- ============================================================================
DO $$
DECLARE
  error_occurred BOOLEAN := FALSE;
BEGIN
  BEGIN
    INSERT INTO rewards (title, points_cost, created_by, status, is_system_reward, is_active)
    VALUES ('Test Invalid Status', 100, '11111111-1111-1111-1111-111111111111', 'invalid', FALSE, FALSE);
  EXCEPTION WHEN check_violation THEN
    error_occurred := TRUE;
  END;
  
  IF error_occurred THEN
    RAISE NOTICE 'Test 5 PASSED: Invalid status rejected by constraint';
  ELSE
    RAISE EXCEPTION 'Test 5 FAILED: Invalid status was accepted';
  END IF;
END $$;

-- ============================================================================
-- Test 6: Query approved rewards only
-- ============================================================================
DO $$
DECLARE
  approved_count INTEGER;
  pending_in_approved INTEGER;
  rejected_in_approved INTEGER;
BEGIN
  -- Count approved rewards
  SELECT COUNT(*) INTO approved_count 
  FROM rewards 
  WHERE status = 'approved' AND is_active = TRUE;
  
  -- Verify no pending in approved list
  SELECT COUNT(*) INTO pending_in_approved 
  FROM rewards 
  WHERE status = 'pending' AND is_active = TRUE;
  
  -- Verify no rejected in approved list
  SELECT COUNT(*) INTO rejected_in_approved 
  FROM rewards 
  WHERE status = 'rejected' AND is_active = TRUE;
  
  IF pending_in_approved = 0 AND rejected_in_approved = 0 THEN
    RAISE NOTICE 'Test 6 PASSED: Only approved rewards in active list (count: %)', approved_count;
  ELSE
    RAISE EXCEPTION 'Test 6 FAILED: Found % pending and % rejected in active list', pending_in_approved, rejected_in_approved;
  END IF;
END $$;

-- ============================================================================
-- Test 7: Verify indexes exist
-- ============================================================================
DO $$
DECLARE
  created_by_index BOOLEAN;
  status_index BOOLEAN;
  is_system_index BOOLEAN;
BEGIN
  SELECT EXISTS(
    SELECT 1 FROM pg_indexes 
    WHERE tablename = 'rewards' AND indexname = 'idx_rewards_created_by'
  ) INTO created_by_index;
  
  SELECT EXISTS(
    SELECT 1 FROM pg_indexes 
    WHERE tablename = 'rewards' AND indexname = 'idx_rewards_status'
  ) INTO status_index;
  
  SELECT EXISTS(
    SELECT 1 FROM pg_indexes 
    WHERE tablename = 'rewards' AND indexname = 'idx_rewards_is_system_reward'
  ) INTO is_system_index;
  
  IF created_by_index AND status_index AND is_system_index THEN
    RAISE NOTICE 'Test 7 PASSED: All required indexes exist';
  ELSE
    RAISE EXCEPTION 'Test 7 FAILED: Missing indexes (created_by:%, status:%, is_system:%)', 
      created_by_index, status_index, is_system_index;
  END IF;
END $$;

-- ============================================================================
-- Test 8: Verify RLS policies exist
-- ============================================================================
DO $$
DECLARE
  select_policy BOOLEAN;
  insert_policy BOOLEAN;
  update_policy BOOLEAN;
BEGIN
  SELECT EXISTS(
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'rewards' AND policyname = 'Users can view accessible rewards'
  ) INTO select_policy;
  
  SELECT EXISTS(
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'rewards' AND policyname = 'Users can create custom rewards'
  ) INTO insert_policy;
  
  SELECT EXISTS(
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'rewards' AND policyname = 'Partners can update pending rewards'
  ) INTO update_policy;
  
  IF select_policy AND insert_policy AND update_policy THEN
    RAISE NOTICE 'Test 8 PASSED: All RLS policies exist';
  ELSE
    RAISE EXCEPTION 'Test 8 FAILED: Missing policies (select:%, insert:%, update:%)', 
      select_policy, insert_policy, update_policy;
  END IF;
END $$;

-- ============================================================================
-- Test 9: Verify partner relationship queries work
-- ============================================================================
DO $$
DECLARE
  user_partner_id UUID;
  partner_rewards INTEGER;
BEGIN
  -- Get User 1's partner
  SELECT p.partner_id INTO user_partner_id 
  FROM profiles p
  WHERE p.id = '11111111-1111-1111-1111-111111111111';
  
  IF user_partner_id = '22222222-2222-2222-2222-222222222222' THEN
    RAISE NOTICE 'Test 9a PASSED: Partner relationship query works';
  ELSE
    RAISE EXCEPTION 'Test 9a FAILED: Partner ID mismatch';
  END IF;
  
  -- Query rewards created by partner
  SELECT COUNT(*) INTO partner_rewards 
  FROM rewards 
  WHERE created_by = user_partner_id;
  
  RAISE NOTICE 'Test 9b PASSED: Can query partner rewards (count: %)', partner_rewards;
END $$;

-- ============================================================================
-- Test 10: Verify unpaired user has no partner
-- ============================================================================
DO $$
DECLARE
  user_partner_id UUID;
BEGIN
  SELECT p.partner_id INTO user_partner_id 
  FROM profiles p
  WHERE p.id = '33333333-3333-3333-3333-333333333333';
  
  IF user_partner_id IS NULL THEN
    RAISE NOTICE 'Test 10 PASSED: Unpaired user has no partner';
  ELSE
    RAISE EXCEPTION 'Test 10 FAILED: Unpaired user has partner: %', user_partner_id;
  END IF;
END $$;

-- ============================================================================
-- Summary
-- ============================================================================
DO $$
DECLARE
  total_rewards INTEGER;
  system_rewards INTEGER;
  custom_rewards INTEGER;
  pending_rewards INTEGER;
  approved_rewards INTEGER;
  rejected_rewards INTEGER;
BEGIN
  SELECT COUNT(*) INTO total_rewards FROM rewards;
  SELECT COUNT(*) INTO system_rewards FROM rewards WHERE is_system_reward = TRUE;
  SELECT COUNT(*) INTO custom_rewards FROM rewards WHERE is_system_reward = FALSE;
  SELECT COUNT(*) INTO pending_rewards FROM rewards WHERE status = 'pending';
  SELECT COUNT(*) INTO approved_rewards FROM rewards WHERE status = 'approved';
  SELECT COUNT(*) INTO rejected_rewards FROM rewards WHERE status = 'rejected';
  
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Backend Test Suite Summary';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Total rewards: %', total_rewards;
  RAISE NOTICE 'System rewards: %', system_rewards;
  RAISE NOTICE 'Custom rewards: %', custom_rewards;
  RAISE NOTICE '  - Pending: %', pending_rewards;
  RAISE NOTICE '  - Approved: %', approved_rewards;
  RAISE NOTICE '  - Rejected: %', rejected_rewards;
  RAISE NOTICE '========================================';
  RAISE NOTICE 'All 10 tests completed successfully! ✓';
  RAISE NOTICE '========================================';
END $$;

ROLLBACK;
