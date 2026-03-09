-- ============================================================================
-- Custom Rewards Backend Test Suite
-- ============================================================================
-- Tests for partner-approved rewards feature including:
-- - Custom reward creation
-- - RLS policy enforcement
-- - Approval/rejection workflow
-- - Privacy controls
-- ============================================================================

BEGIN;

-- Create test users
INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, raw_user_meta_data)
VALUES 
  ('11111111-1111-1111-1111-111111111111', 'user1@test.com', crypt('password123', gen_salt('bf')), NOW(), '{"display_name": "User One"}'),
  ('22222222-2222-2222-2222-222222222222', 'user2@test.com', crypt('password123', gen_salt('bf')), NOW(), '{"display_name": "User Two"}'),
  ('33333333-3333-3333-3333-333333333333', 'user3@test.com', crypt('password123', gen_salt('bf')), NOW(), '{"display_name": "User Three"}')
ON CONFLICT (id) DO NOTHING;

-- Create profiles for test users
INSERT INTO profiles (id, display_name, total_points)
VALUES 
  ('11111111-1111-1111-1111-111111111111', 'User One', 1000),
  ('22222222-2222-2222-2222-222222222222', 'User Two', 1000),
  ('33333333-3333-3333-3333-333333333333', 'User Three', 1000)
ON CONFLICT (id) DO UPDATE SET display_name = EXCLUDED.display_name;

-- Pair User 1 and User 2 as partners
UPDATE profiles SET partner_id = '22222222-2222-2222-2222-222222222222' WHERE id = '11111111-1111-1111-1111-111111111111';
UPDATE profiles SET partner_id = '11111111-1111-1111-1111-111111111111' WHERE id = '22222222-2222-2222-2222-222222222222';

-- User 3 remains unpaired

-- ============================================================================
-- Test 1: System rewards are visible to all users
-- ============================================================================
DO $$
DECLARE
  user1_count INTEGER;
  user2_count INTEGER;
  user3_count INTEGER;
BEGIN
  -- Count system rewards visible to each user
  SET LOCAL role = 'authenticated';
  
  SET LOCAL request.jwt.claims = json_build_object('sub', '11111111-1111-1111-1111-111111111111')::text;
  SELECT COUNT(*) INTO user1_count FROM rewards WHERE is_system_reward = TRUE;
  
  SET LOCAL request.jwt.claims = json_build_object('sub', '22222222-2222-2222-2222-222222222222')::text;
  SELECT COUNT(*) INTO user2_count FROM rewards WHERE is_system_reward = TRUE;
  
  SET LOCAL request.jwt.claims = json_build_object('sub', '33333333-3333-3333-3333-333333333333')::text;
  SELECT COUNT(*) INTO user3_count FROM rewards WHERE is_system_reward = TRUE;
  
  RESET role;
  
  IF user1_count = user2_count AND user2_count = user3_count THEN
    RAISE NOTICE 'Test 1 PASSED: All users see same system rewards (count: %)', user1_count;
  ELSE
    RAISE EXCEPTION 'Test 1 FAILED: System reward counts differ (%, %, %)', user1_count, user2_count, user3_count;
  END IF;
END $$;

-- ============================================================================
-- Test 2: User can create custom reward proposal
-- ============================================================================
DO $$
DECLARE
  new_reward_id UUID;
  reward_status TEXT;
  reward_is_system BOOLEAN;
BEGIN
  SET LOCAL role = 'authenticated';
  SET LOCAL request.jwt.claims = json_build_object('sub', '11111111-1111-1111-1111-111111111111')::text;
  
  -- User 1 creates a custom reward
  INSERT INTO rewards (title, points_cost, created_by, status, is_system_reward, is_active)
  VALUES ('Movie Night', 100, '11111111-1111-1111-1111-111111111111', 'pending', FALSE, FALSE)
  RETURNING id, status, is_system_reward INTO new_reward_id, reward_status, reward_is_system;
  
  RESET role;
  
  IF reward_status = 'pending' AND reward_is_system = FALSE THEN
    RAISE NOTICE 'Test 2 PASSED: Custom reward created with pending status (ID: %)', new_reward_id;
  ELSE
    RAISE EXCEPTION 'Test 2 FAILED: Reward status=% is_system=%', reward_status, reward_is_system;
  END IF;
END $$;

-- ============================================================================
-- Test 3: Partner can see pending reward in approval queue
-- ============================================================================
DO $$
DECLARE
  pending_count INTEGER;
BEGIN
  SET LOCAL role = 'authenticated';
  SET LOCAL request.jwt.claims = json_build_object('sub', '22222222-2222-2222-2222-222222222222')::text;
  
  -- User 2 (partner) checks pending rewards created by User 1
  SELECT COUNT(*) INTO pending_count 
  FROM rewards 
  WHERE status = 'pending' 
    AND created_by = '11111111-1111-1111-1111-111111111111';
  
  RESET role;
  
  IF pending_count > 0 THEN
    RAISE NOTICE 'Test 3 PASSED: Partner can see % pending reward(s)', pending_count;
  ELSE
    RAISE EXCEPTION 'Test 3 FAILED: Partner cannot see pending rewards';
  END IF;
END $$;

-- ============================================================================
-- Test 4: Non-partner cannot see custom reward
-- ============================================================================
DO $$
DECLARE
  visible_count INTEGER;
BEGIN
  SET LOCAL role = 'authenticated';
  SET LOCAL request.jwt.claims = json_build_object('sub', '33333333-3333-3333-3333-333333333333')::text;
  
  -- User 3 (not partner) tries to see User 1's custom rewards
  SELECT COUNT(*) INTO visible_count 
  FROM rewards 
  WHERE created_by = '11111111-1111-1111-1111-111111111111'
    AND is_system_reward = FALSE;
  
  RESET role;
  
  IF visible_count = 0 THEN
    RAISE NOTICE 'Test 4 PASSED: Non-partner cannot see custom rewards';
  ELSE
    RAISE EXCEPTION 'Test 4 FAILED: Non-partner can see % custom reward(s)', visible_count;
  END IF;
END $$;

-- ============================================================================
-- Test 5: Partner can approve pending reward
-- ============================================================================
DO $$
DECLARE
  reward_id UUID;
  updated_status TEXT;
  updated_active BOOLEAN;
BEGIN
  -- Get a pending reward created by User 1
  SELECT id INTO reward_id 
  FROM rewards 
  WHERE created_by = '11111111-1111-1111-1111-111111111111' 
    AND status = 'pending' 
  LIMIT 1;
  
  SET LOCAL role = 'authenticated';
  SET LOCAL request.jwt.claims = json_build_object('sub', '22222222-2222-2222-2222-222222222222')::text;
  
  -- User 2 (partner) approves the reward
  UPDATE rewards 
  SET status = 'approved', is_active = TRUE 
  WHERE id = reward_id;
  
  RESET role;
  
  -- Verify the update
  SELECT status, is_active INTO updated_status, updated_active 
  FROM rewards 
  WHERE id = reward_id;
  
  IF updated_status = 'approved' AND updated_active = TRUE THEN
    RAISE NOTICE 'Test 5 PASSED: Partner approved reward (ID: %)', reward_id;
  ELSE
    RAISE EXCEPTION 'Test 5 FAILED: Approval failed (status=%, active=%)', updated_status, updated_active;
  END IF;
END $$;

-- ============================================================================
-- Test 6: Approved custom reward is visible to both partners
-- ============================================================================
DO $$
DECLARE
  user1_sees BOOLEAN;
  user2_sees BOOLEAN;
  reward_id UUID;
BEGIN
  -- Get an approved custom reward
  SELECT id INTO reward_id 
  FROM rewards 
  WHERE created_by = '11111111-1111-1111-1111-111111111111' 
    AND status = 'approved' 
    AND is_system_reward = FALSE
  LIMIT 1;
  
  SET LOCAL role = 'authenticated';
  
  -- Check if User 1 can see it
  SET LOCAL request.jwt.claims = json_build_object('sub', '11111111-1111-1111-1111-111111111111')::text;
  SELECT EXISTS(SELECT 1 FROM rewards WHERE id = reward_id) INTO user1_sees;
  
  -- Check if User 2 can see it
  SET LOCAL request.jwt.claims = json_build_object('sub', '22222222-2222-2222-2222-222222222222')::text;
  SELECT EXISTS(SELECT 1 FROM rewards WHERE id = reward_id) INTO user2_sees;
  
  RESET role;
  
  IF user1_sees AND user2_sees THEN
    RAISE NOTICE 'Test 6 PASSED: Both partners can see approved custom reward';
  ELSE
    RAISE EXCEPTION 'Test 6 FAILED: User1 sees=%, User2 sees=%', user1_sees, user2_sees;
  END IF;
END $$;

-- ============================================================================
-- Test 7: Non-partner cannot approve reward
-- ============================================================================
DO $$
DECLARE
  reward_id UUID;
  error_occurred BOOLEAN := FALSE;
BEGIN
  -- Create a new pending reward by User 1
  INSERT INTO rewards (title, points_cost, created_by, status, is_system_reward, is_active)
  VALUES ('Spa Day', 200, '11111111-1111-1111-1111-111111111111', 'pending', FALSE, FALSE)
  RETURNING id INTO reward_id;
  
  SET LOCAL role = 'authenticated';
  SET LOCAL request.jwt.claims = json_build_object('sub', '33333333-3333-3333-3333-333333333333')::text;
  
  -- User 3 (not partner) tries to approve
  BEGIN
    UPDATE rewards 
    SET status = 'approved', is_active = TRUE 
    WHERE id = reward_id;
    
    -- If we get here, the update succeeded (should not happen)
    error_occurred := FALSE;
  EXCEPTION WHEN OTHERS THEN
    error_occurred := TRUE;
  END;
  
  RESET role;
  
  IF error_occurred THEN
    RAISE NOTICE 'Test 7 PASSED: Non-partner cannot approve reward';
  ELSE
    RAISE EXCEPTION 'Test 7 FAILED: Non-partner was able to approve reward';
  END IF;
END $$;

-- ============================================================================
-- Test 8: Partner can reject pending reward
-- ============================================================================
DO $$
DECLARE
  reward_id UUID;
  updated_status TEXT;
BEGIN
  -- Get a pending reward
  SELECT id INTO reward_id 
  FROM rewards 
  WHERE created_by = '11111111-1111-1111-1111-111111111111' 
    AND status = 'pending' 
  LIMIT 1;
  
  SET LOCAL role = 'authenticated';
  SET LOCAL request.jwt.claims = json_build_object('sub', '22222222-2222-2222-2222-222222222222')::text;
  
  -- User 2 (partner) rejects the reward
  UPDATE rewards 
  SET status = 'rejected' 
  WHERE id = reward_id;
  
  RESET role;
  
  -- Verify the update
  SELECT status INTO updated_status 
  FROM rewards 
  WHERE id = reward_id;
  
  IF updated_status = 'rejected' THEN
    RAISE NOTICE 'Test 8 PASSED: Partner rejected reward (ID: %)', reward_id;
  ELSE
    RAISE EXCEPTION 'Test 8 FAILED: Rejection failed (status=%)', updated_status;
  END IF;
END $$;

-- ============================================================================
-- Test 9: Rejected rewards are hidden from active rewards list
-- ============================================================================
DO $$
DECLARE
  active_rejected_count INTEGER;
BEGIN
  SET LOCAL role = 'authenticated';
  SET LOCAL request.jwt.claims = json_build_object('sub', '11111111-1111-1111-1111-111111111111')::text;
  
  -- Count rejected rewards in active list
  SELECT COUNT(*) INTO active_rejected_count 
  FROM rewards 
  WHERE status = 'rejected' AND is_active = TRUE;
  
  RESET role;
  
  IF active_rejected_count = 0 THEN
    RAISE NOTICE 'Test 9 PASSED: No rejected rewards in active list';
  ELSE
    RAISE EXCEPTION 'Test 9 FAILED: Found % rejected rewards in active list', active_rejected_count;
  END IF;
END $$;

-- ============================================================================
-- Test 10: Unpaired user cannot approve any rewards
-- ============================================================================
DO $$
DECLARE
  pending_visible INTEGER;
BEGIN
  SET LOCAL role = 'authenticated';
  SET LOCAL request.jwt.claims = json_build_object('sub', '33333333-3333-3333-3333-333333333333')::text;
  
  -- User 3 (unpaired) checks for pending rewards they can approve
  SELECT COUNT(*) INTO pending_visible 
  FROM rewards 
  WHERE status = 'pending' 
    AND created_by IN (
      SELECT partner_id FROM profiles WHERE id = '33333333-3333-3333-3333-333333333333'
    );
  
  RESET role;
  
  IF pending_visible = 0 THEN
    RAISE NOTICE 'Test 10 PASSED: Unpaired user sees no pending approvals';
  ELSE
    RAISE EXCEPTION 'Test 10 FAILED: Unpaired user sees % pending approvals', pending_visible;
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
  RAISE NOTICE 'Test Suite Summary';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Total rewards: %', total_rewards;
  RAISE NOTICE 'System rewards: %', system_rewards;
  RAISE NOTICE 'Custom rewards: %', custom_rewards;
  RAISE NOTICE '  - Pending: %', pending_rewards;
  RAISE NOTICE '  - Approved: %', approved_rewards;
  RAISE NOTICE '  - Rejected: %', rejected_rewards;
  RAISE NOTICE '========================================';
  RAISE NOTICE 'All tests completed successfully! ✓';
  RAISE NOTICE '========================================';
END $$;

ROLLBACK;
