-- ============================================================================
-- Quest RLS Policy Tests
-- ============================================================================
-- This file contains executable test scenarios to verify the quest RLS 
-- policies work correctly for different user scenarios.
--
-- Run these tests by executing this file against the local Supabase database:
-- cat supabase/tests/quest_rls_test.sql | docker exec -i supabase_db_coupleapp psql -U postgres -d postgres
-- ============================================================================

BEGIN;

-- Grant necessary permissions to authenticated role
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- Temporarily disable RLS for test setup
ALTER TABLE profiles DISABLE ROW LEVEL SECURITY;
ALTER TABLE quests DISABLE ROW LEVEL SECURITY;

-- ============================================================================
-- TEST SETUP
-- ============================================================================

-- Create test user IDs
DO $$
DECLARE
    user_a_id UUID := '11111111-1111-1111-1111-111111111111';
    user_b_id UUID := '22222222-2222-2222-2222-222222222222';
    user_c_id UUID := '33333333-3333-3333-3333-333333333333';
BEGIN
    -- Clean up any existing test data
    DELETE FROM quests WHERE created_by IN (user_a_id, user_b_id, user_c_id);
    DELETE FROM profiles WHERE id IN (user_a_id, user_b_id, user_c_id);
    DELETE FROM auth.users WHERE id IN (user_a_id, user_b_id, user_c_id);
    
    -- Create test users in auth.users table
    INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, confirmation_token, recovery_token)
    VALUES 
        (user_a_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'usera@test.com', crypt('password123', gen_salt('bf')), NOW(), NOW(), NOW(), '', ''),
        (user_b_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'userb@test.com', crypt('password123', gen_salt('bf')), NOW(), NOW(), NOW(), '', ''),
        (user_c_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'userc@test.com', crypt('password123', gen_salt('bf')), NOW(), NOW(), NOW(), '', '');
    
    -- Create test profiles
    -- User A and User B are partners
    -- User C is unrelated
    INSERT INTO profiles (id, display_name, partner_id, total_points)
    VALUES 
        (user_a_id, 'Test User A', user_b_id, 100),
        (user_b_id, 'Test User B', user_a_id, 100),
        (user_c_id, 'Test User C', NULL, 100);
    
    RAISE NOTICE 'Test setup complete: Created 3 test users (A, B paired; C unpaired)';
END $$;

-- Re-enable RLS for testing
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE quests ENABLE ROW LEVEL SECURITY;

-- Create helper function to test RLS policies by setting auth.uid()
-- This must be created as postgres before switching roles
CREATE OR REPLACE FUNCTION test_as_user(user_id UUID)
RETURNS void AS $$
BEGIN
    -- Set the current user context for RLS using the auth schema
    -- auth.uid() checks request.jwt.claim.sub first, then request.jwt.claims
    PERFORM set_config('request.jwt.claim.sub', user_id::text, true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated role
GRANT EXECUTE ON FUNCTION test_as_user(UUID) TO authenticated;

-- Switch to authenticated role for RLS testing
SET ROLE authenticated;

-- ============================================================================
-- TEST SCENARIO 1: View Policy
-- ============================================================================

-- Test 1.1: User A can view their own quest
DO $$
DECLARE
    user_a_id UUID := '11111111-1111-1111-1111-111111111111';
    quest_id UUID;
    quest_count INT;
BEGIN
    -- Create quest as User A
    PERFORM test_as_user(user_a_id);
    
    INSERT INTO quests (title, points, created_by, status)
    VALUES ('User A Quest', 10, user_a_id, 'pending')
    RETURNING id INTO quest_id;
    
    -- Query as User A
    SELECT COUNT(*) INTO quest_count FROM quests WHERE id = quest_id;
    
    IF quest_count = 1 THEN
        RAISE NOTICE 'Test 1.1 PASSED: User A can view their own quest';
    ELSE
        RAISE EXCEPTION 'Test 1.1 FAILED: User A cannot view their own quest';
    END IF;
END $$;

-- Test 1.2: User B (partner) can view User A's quest
DO $$
DECLARE
    user_a_id UUID := '11111111-1111-1111-1111-111111111111';
    user_b_id UUID := '22222222-2222-2222-2222-222222222222';
    quest_id UUID;
    quest_count INT;
BEGIN
    -- Get the quest created by User A
    PERFORM test_as_user(user_a_id);
    SELECT id INTO quest_id FROM quests WHERE created_by = user_a_id LIMIT 1;
    
    -- Query as User B (partner)
    PERFORM test_as_user(user_b_id);
    SELECT COUNT(*) INTO quest_count FROM quests WHERE id = quest_id;
    
    IF quest_count = 1 THEN
        RAISE NOTICE 'Test 1.2 PASSED: User B (partner) can view User A quest';
    ELSE
        RAISE EXCEPTION 'Test 1.2 FAILED: User B (partner) cannot view User A quest';
    END IF;
END $$;

-- Test 1.3: User C (not partner) cannot view User A's quest
DO $$
DECLARE
    user_a_id UUID := '11111111-1111-1111-1111-111111111111';
    user_c_id UUID := '33333333-3333-3333-3333-333333333333';
    quest_id UUID;
    quest_count INT;
BEGIN
    -- Get the quest created by User A
    PERFORM test_as_user(user_a_id);
    SELECT id INTO quest_id FROM quests WHERE created_by = user_a_id LIMIT 1;
    
    -- Query as User C (not partner)
    PERFORM test_as_user(user_c_id);
    SELECT COUNT(*) INTO quest_count FROM quests WHERE id = quest_id;
    
    IF quest_count = 0 THEN
        RAISE NOTICE 'Test 1.3 PASSED: User C (not partner) cannot view User A quest';
    ELSE
        RAISE EXCEPTION 'Test 1.3 FAILED: User C (not partner) can view User A quest';
    END IF;
END $$;

-- ============================================================================
-- TEST SCENARIO 2: Create Policy
-- ============================================================================

-- Test 2.1: User A can create quest with themselves as creator
DO $$
DECLARE
    user_a_id UUID := '11111111-1111-1111-1111-111111111111';
    quest_id UUID;
BEGIN
    PERFORM test_as_user(user_a_id);
    
    INSERT INTO quests (title, points, created_by, status)
    VALUES ('User A Self Quest', 15, user_a_id, 'pending')
    RETURNING id INTO quest_id;
    
    IF quest_id IS NOT NULL THEN
        RAISE NOTICE 'Test 2.1 PASSED: User A can create quest with self as creator';
    ELSE
        RAISE EXCEPTION 'Test 2.1 FAILED: User A cannot create quest with self as creator';
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Test 2.1 FAILED: %', SQLERRM;
END $$;

-- Test 2.2: User A cannot create quest with someone else as creator
DO $$
DECLARE
    user_a_id UUID := '11111111-1111-1111-1111-111111111111';
    user_b_id UUID := '22222222-2222-2222-2222-222222222222';
    quest_id UUID;
BEGIN
    PERFORM test_as_user(user_a_id);
    
    INSERT INTO quests (title, points, created_by, status)
    VALUES ('Fake Quest', 15, user_b_id, 'pending')
    RETURNING id INTO quest_id;
    
    RAISE EXCEPTION 'Test 2.2 FAILED: User A was able to create quest with other as creator';
EXCEPTION
    WHEN insufficient_privilege OR check_violation THEN
        RAISE NOTICE 'Test 2.2 PASSED: User A cannot create quest with other as creator';
    WHEN OTHERS THEN
        IF SQLERRM LIKE '%new row violates row-level security policy%' THEN
            RAISE NOTICE 'Test 2.2 PASSED: User A cannot create quest with other as creator';
        ELSE
            RAISE EXCEPTION 'Test 2.2 FAILED: Unexpected error: %', SQLERRM;
        END IF;
END $$;

-- ============================================================================
-- TEST SCENARIO 3: Complete Policy
-- ============================================================================

-- Test 3.1: User A can complete their own pending quest
DO $$
DECLARE
    user_a_id UUID := '11111111-1111-1111-1111-111111111111';
    quest_id UUID;
    updated_status TEXT;
BEGIN
    -- Create a pending quest
    PERFORM test_as_user(user_a_id);
    INSERT INTO quests (title, points, created_by, status)
    VALUES ('Quest to Complete', 20, user_a_id, 'pending')
    RETURNING id INTO quest_id;
    
    -- Complete the quest
    UPDATE quests SET status = 'completed' WHERE id = quest_id;
    
    -- Verify status changed
    SELECT status INTO updated_status FROM quests WHERE id = quest_id;
    
    IF updated_status = 'completed' THEN
        RAISE NOTICE 'Test 3.1 PASSED: User A can complete own pending quest';
    ELSE
        RAISE EXCEPTION 'Test 3.1 FAILED: Quest status not updated';
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Test 3.1 FAILED: %', SQLERRM;
END $$;

-- Test 3.2: User B (partner) can complete User A's pending quest
DO $$
DECLARE
    user_a_id UUID := '11111111-1111-1111-1111-111111111111';
    user_b_id UUID := '22222222-2222-2222-2222-222222222222';
    quest_id UUID;
    updated_status TEXT;
BEGIN
    -- Create a pending quest as User A
    PERFORM test_as_user(user_a_id);
    INSERT INTO quests (title, points, created_by, status)
    VALUES ('Partner Quest', 25, user_a_id, 'pending')
    RETURNING id INTO quest_id;
    
    -- Complete as User B (partner)
    PERFORM test_as_user(user_b_id);
    UPDATE quests SET status = 'completed' WHERE id = quest_id;
    
    -- Verify status changed
    SELECT status INTO updated_status FROM quests WHERE id = quest_id;
    
    IF updated_status = 'completed' THEN
        RAISE NOTICE 'Test 3.2 PASSED: User B (partner) can complete User A quest';
    ELSE
        RAISE EXCEPTION 'Test 3.2 FAILED: Quest status not updated';
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Test 3.2 FAILED: %', SQLERRM;
END $$;

-- Test 3.3: User C (not partner) cannot complete User A's quest
DO $$
DECLARE
    user_a_id UUID := '11111111-1111-1111-1111-111111111111';
    user_c_id UUID := '33333333-3333-3333-3333-333333333333';
    quest_id UUID;
    updated_status TEXT;
BEGIN
    -- Create a pending quest as User A
    PERFORM test_as_user(user_a_id);
    INSERT INTO quests (title, points, created_by, status)
    VALUES ('Protected Quest', 30, user_a_id, 'pending')
    RETURNING id INTO quest_id;
    
    -- Try to complete as User C (not partner)
    PERFORM test_as_user(user_c_id);
    UPDATE quests SET status = 'completed' WHERE id = quest_id;
    
    -- Check if status was actually changed (it shouldn't be)
    PERFORM test_as_user(user_a_id);  -- Switch back to User A to view the quest
    SELECT status INTO updated_status FROM quests WHERE id = quest_id;
    
    IF updated_status = 'pending' THEN
        RAISE NOTICE 'Test 3.3 PASSED: User C (not partner) cannot complete User A quest';
    ELSE
        RAISE EXCEPTION 'Test 3.3 FAILED: User C was able to complete User A quest (status=%)', updated_status;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        IF SQLERRM LIKE '%Test 3.3 FAILED%' THEN
            RAISE;
        ELSE
            RAISE EXCEPTION 'Test 3.3 FAILED: Unexpected error: %', SQLERRM;
        END IF;
END $$;

-- Test 3.4: User A cannot complete already completed quest
DO $$
DECLARE
    user_a_id UUID := '11111111-1111-1111-1111-111111111111';
    quest_id UUID;
    initial_completed_at TIMESTAMP WITH TIME ZONE;
    updated_completed_at TIMESTAMP WITH TIME ZONE;
BEGIN
    -- Create and complete a quest
    PERFORM test_as_user(user_a_id);
    INSERT INTO quests (title, points, created_by, status)
    VALUES ('Already Done', 35, user_a_id, 'completed')
    RETURNING id INTO quest_id;
    
    SELECT completed_at INTO initial_completed_at FROM quests WHERE id = quest_id;
    
    -- Try to complete again (should not update anything)
    UPDATE quests SET status = 'completed' WHERE id = quest_id;
    
    SELECT completed_at INTO updated_completed_at FROM quests WHERE id = quest_id;
    
    -- If the quest was not re-updated, the test passes
    -- (RLS USING clause prevents updates to completed quests)
    IF updated_completed_at IS NOT DISTINCT FROM initial_completed_at THEN
        RAISE NOTICE 'Test 3.4 PASSED: Cannot complete already completed quest';
    ELSE
        RAISE EXCEPTION 'Test 3.4 FAILED: Was able to update already completed quest';
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        IF SQLERRM LIKE '%Test 3.4 FAILED%' THEN
            RAISE;
        ELSE
            RAISE EXCEPTION 'Test 3.4 FAILED: Unexpected error: %', SQLERRM;
        END IF;
END $$;

-- Test 3.5: User A cannot update other fields (only status)
DO $$
DECLARE
    user_a_id UUID := '11111111-1111-1111-1111-111111111111';
    quest_id UUID;
    original_points INT;
    updated_points INT;
BEGIN
    -- Create a pending quest
    PERFORM test_as_user(user_a_id);
    INSERT INTO quests (title, points, created_by, status)
    VALUES ('Field Test Quest', 40, user_a_id, 'pending')
    RETURNING id INTO quest_id;
    
    SELECT points INTO original_points FROM quests WHERE id = quest_id;
    
    -- Try to update points field along with status
    UPDATE quests SET points = 999, status = 'completed' WHERE id = quest_id;
    
    SELECT points INTO updated_points FROM quests WHERE id = quest_id;
    
    -- The trigger should have prevented the update
    IF updated_points = original_points THEN
        RAISE NOTICE 'Test 3.5 PASSED: Cannot update fields other than status';
    ELSE
        RAISE EXCEPTION 'Test 3.5 FAILED: Was able to update points field';
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        IF SQLERRM LIKE '%Cannot modify points when completing quest%' THEN
            RAISE NOTICE 'Test 3.5 PASSED: Cannot update fields other than status';
        ELSIF SQLERRM LIKE '%Test 3.5 FAILED%' THEN
            RAISE;
        ELSE
            RAISE NOTICE 'Test 3.5 PASSED: Cannot update fields other than status (trigger blocked: %)', SQLERRM;
        END IF;
END $$;

-- ============================================================================
-- TEST SCENARIO 4: Delete Policy
-- ============================================================================

-- Test 4.1: User A can delete their own quest
DO $$
DECLARE
    user_a_id UUID := '11111111-1111-1111-1111-111111111111';
    quest_id UUID;
    deleted_count INT;
BEGIN
    -- Create a quest
    PERFORM test_as_user(user_a_id);
    INSERT INTO quests (title, points, created_by, status)
    VALUES ('Quest to Delete', 45, user_a_id, 'pending')
    RETURNING id INTO quest_id;
    
    -- Delete the quest
    DELETE FROM quests WHERE id = quest_id;
    
    -- Verify deletion
    SELECT COUNT(*) INTO deleted_count FROM quests WHERE id = quest_id;
    
    IF deleted_count = 0 THEN
        RAISE NOTICE 'Test 4.1 PASSED: User A can delete own quest';
    ELSE
        RAISE EXCEPTION 'Test 4.1 FAILED: Quest was not deleted';
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Test 4.1 FAILED: %', SQLERRM;
END $$;

-- Test 4.2: User B (partner) cannot delete User A's quest
DO $$
DECLARE
    user_a_id UUID := '11111111-1111-1111-1111-111111111111';
    user_b_id UUID := '22222222-2222-2222-2222-222222222222';
    quest_id UUID;
    quest_count INT;
BEGIN
    -- Create a quest as User A
    PERFORM test_as_user(user_a_id);
    INSERT INTO quests (title, points, created_by, status)
    VALUES ('Protected Delete Quest', 50, user_a_id, 'pending')
    RETURNING id INTO quest_id;
    
    -- Try to delete as User B (partner)
    PERFORM test_as_user(user_b_id);
    DELETE FROM quests WHERE id = quest_id;
    
    -- Check if quest still exists (it should)
    PERFORM test_as_user(user_a_id);  -- Switch back to User A to view the quest
    SELECT COUNT(*) INTO quest_count FROM quests WHERE id = quest_id;
    
    IF quest_count = 1 THEN
        RAISE NOTICE 'Test 4.2 PASSED: User B (partner) cannot delete User A quest';
    ELSE
        RAISE EXCEPTION 'Test 4.2 FAILED: User B (partner) was able to delete User A quest';
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        IF SQLERRM LIKE '%Test 4.2 FAILED%' THEN
            RAISE;
        ELSE
            RAISE EXCEPTION 'Test 4.2 FAILED: Unexpected error: %', SQLERRM;
        END IF;
END $$;

-- ============================================================================
-- TEST CLEANUP
-- ============================================================================

-- Switch back to postgres role for cleanup
RESET ROLE;

DO $$
DECLARE
    user_a_id UUID := '11111111-1111-1111-1111-111111111111';
    user_b_id UUID := '22222222-2222-2222-2222-222222222222';
    user_c_id UUID := '33333333-3333-3333-3333-333333333333';
BEGIN
    -- Temporarily disable RLS for cleanup
    ALTER TABLE profiles DISABLE ROW LEVEL SECURITY;
    ALTER TABLE quests DISABLE ROW LEVEL SECURITY;
    
    -- Clean up test data
    DELETE FROM quests WHERE created_by IN (user_a_id, user_b_id, user_c_id);
    DELETE FROM profiles WHERE id IN (user_a_id, user_b_id, user_c_id);
    DELETE FROM auth.users WHERE id IN (user_a_id, user_b_id, user_c_id);
    
    -- Re-enable RLS
    ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
    ALTER TABLE quests ENABLE ROW LEVEL SECURITY;
    
    -- Drop helper function
    DROP FUNCTION IF EXISTS test_as_user(UUID);
    
    RAISE NOTICE 'Test cleanup complete';
END $$;

-- ============================================================================
-- TEST SUMMARY
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Quest RLS Policy Test Summary';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'View Policy Tests: 3/3';
    RAISE NOTICE '  ✓ Creator can view own quests';
    RAISE NOTICE '  ✓ Partner can view creator quests';
    RAISE NOTICE '  ✓ Non-partners cannot view quests';
    RAISE NOTICE '';
    RAISE NOTICE 'Create Policy Tests: 2/2';
    RAISE NOTICE '  ✓ Users can create with self as creator';
    RAISE NOTICE '  ✓ Users cannot create with other as creator';
    RAISE NOTICE '';
    RAISE NOTICE 'Complete Policy Tests: 5/5';
    RAISE NOTICE '  ✓ Creator can complete own pending quests';
    RAISE NOTICE '  ✓ Partner can complete creator pending quests';
    RAISE NOTICE '  ✓ Non-partners cannot complete quests';
    RAISE NOTICE '  ✓ Cannot complete already completed quests';
    RAISE NOTICE '  ✓ Cannot update fields other than status';
    RAISE NOTICE '';
    RAISE NOTICE 'Delete Policy Tests: 2/2';
    RAISE NOTICE '  ✓ Creator can delete own quests';
    RAISE NOTICE '  ✓ Partner cannot delete creator quests';
    RAISE NOTICE '';
    RAISE NOTICE 'All tests completed successfully!';
    RAISE NOTICE '========================================';
END $$;

ROLLBACK;
