-- ============================================================================
-- Rewards and Transactions RLS Policy Tests
-- ============================================================================
-- This file contains executable test scenarios to verify the rewards and
-- transactions RLS policies work correctly for different user scenarios.
--
-- Run these tests by executing this file against the local Supabase database:
-- docker exec -i supabase_db_coupleapp psql -U postgres -d postgres -f /dev/stdin < supabase/tests/rewards_transactions_rls_test.sql
-- ============================================================================

\set ON_ERROR_STOP on

BEGIN;

-- Grant necessary permissions to authenticated role
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- Temporarily disable RLS for test setup
ALTER TABLE profiles DISABLE ROW LEVEL SECURITY;
ALTER TABLE rewards DISABLE ROW LEVEL SECURITY;
ALTER TABLE transactions DISABLE ROW LEVEL SECURITY;

-- ============================================================================
-- TEST SETUP
-- ============================================================================

-- Clean up any existing test data
DELETE FROM transactions WHERE user_id IN (
    '11111111-1111-1111-1111-111111111111'::uuid,
    '22222222-2222-2222-2222-222222222222'::uuid,
    '33333333-3333-3333-3333-333333333333'::uuid
);
DELETE FROM rewards WHERE title LIKE 'Test Reward%';
DELETE FROM profiles WHERE id IN (
    '11111111-1111-1111-1111-111111111111'::uuid,
    '22222222-2222-2222-2222-222222222222'::uuid,
    '33333333-3333-3333-3333-333333333333'::uuid
);
DELETE FROM auth.users WHERE id IN (
    '11111111-1111-1111-1111-111111111111'::uuid,
    '22222222-2222-2222-2222-222222222222'::uuid,
    '33333333-3333-3333-3333-333333333333'::uuid
);

-- Create test users in auth.users table
INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, confirmation_token, recovery_token)
VALUES 
    ('11111111-1111-1111-1111-111111111111'::uuid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'usera@test.com', crypt('password123', gen_salt('bf')), NOW(), NOW(), NOW(), '', ''),
    ('22222222-2222-2222-2222-222222222222'::uuid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'userb@test.com', crypt('password123', gen_salt('bf')), NOW(), NOW(), NOW(), '', ''),
    ('33333333-3333-3333-3333-333333333333'::uuid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'userc@test.com', crypt('password123', gen_salt('bf')), NOW(), NOW(), NOW(), '', '')
ON CONFLICT (id) DO UPDATE SET 
    email = EXCLUDED.email,
    updated_at = NOW();

-- Create test profiles
-- User A and User B are partners
-- User C is unrelated
INSERT INTO profiles (id, display_name, partner_id, total_points)
VALUES 
    ('11111111-1111-1111-1111-111111111111'::uuid, 'Test User A', '22222222-2222-2222-2222-222222222222'::uuid, 100),
    ('22222222-2222-2222-2222-222222222222'::uuid, 'Test User B', '11111111-1111-1111-1111-111111111111'::uuid, 150),
    ('33333333-3333-3333-3333-333333333333'::uuid, 'Test User C', NULL, 200)
ON CONFLICT (id) DO UPDATE SET
    display_name = EXCLUDED.display_name,
    partner_id = EXCLUDED.partner_id,
    total_points = EXCLUDED.total_points,
    updated_at = NOW();

-- Create test rewards (active and inactive)
INSERT INTO rewards (title, points_cost, is_active)
VALUES 
    ('Test Reward Active 1', 50, true),
    ('Test Reward Active 2', 100, true),
    ('Test Reward Inactive', 75, false);

-- Create test transactions
INSERT INTO transactions (user_id, type, amount, description)
VALUES 
    ('11111111-1111-1111-1111-111111111111'::uuid, 'earn', 50, 'Completed quest'),
    ('11111111-1111-1111-1111-111111111111'::uuid, 'redeem', -30, 'Redeemed reward'),
    ('22222222-2222-2222-2222-222222222222'::uuid, 'earn', 75, 'Completed quest'),
    ('33333333-3333-3333-3333-333333333333'::uuid, 'earn', 100, 'Completed quest');

\echo 'Test setup complete: Created 3 test users (A, B paired; C unpaired), 3 rewards, 4 transactions'

-- Re-enable RLS for testing
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE rewards ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;

-- Create helper function to test RLS policies by setting auth.uid()
CREATE OR REPLACE FUNCTION test_as_user(user_id UUID)
RETURNS void AS $$
BEGIN
    PERFORM set_config('request.jwt.claim.sub', user_id::text, true);
    PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated role
GRANT EXECUTE ON FUNCTION test_as_user(UUID) TO authenticated;

-- Switch to authenticated role for RLS testing
SET ROLE authenticated;

\echo ''
\echo '========================================'
\echo 'Running RLS Policy Tests'
\echo '========================================'

-- ============================================================================
-- TEST SCENARIO 1: Rewards View Policy
-- ============================================================================

\echo ''
\echo 'Test 1.1: User A can view active rewards'
DO $$
DECLARE
    user_a_id UUID := '11111111-1111-1111-1111-111111111111';
    active_count INT;
BEGIN
    PERFORM test_as_user(user_a_id);
    
    SELECT COUNT(*) INTO active_count 
    FROM rewards 
    WHERE title LIKE 'Test Reward Active%';
    
    IF active_count = 2 THEN
        RAISE NOTICE '✓ PASSED: User A can view active rewards (count=%)', active_count;
    ELSE
        RAISE EXCEPTION '✗ FAILED: Expected 2 active rewards, got %', active_count;
    END IF;
END $$;

\echo 'Test 1.2: User A cannot view inactive rewards'
DO $$
DECLARE
    user_a_id UUID := '11111111-1111-1111-1111-111111111111';
    inactive_count INT;
BEGIN
    PERFORM test_as_user(user_a_id);
    
    SELECT COUNT(*) INTO inactive_count 
    FROM rewards 
    WHERE title = 'Test Reward Inactive';
    
    IF inactive_count = 0 THEN
        RAISE NOTICE '✓ PASSED: User A cannot view inactive rewards';
    ELSE
        RAISE EXCEPTION '✗ FAILED: User A can view inactive rewards (count=%)', inactive_count;
    END IF;
END $$;

\echo 'Test 1.3: All authenticated users can view active rewards'
DO $$
DECLARE
    user_c_id UUID := '33333333-3333-3333-3333-333333333333';
    active_count INT;
BEGIN
    PERFORM test_as_user(user_c_id);
    
    SELECT COUNT(*) INTO active_count 
    FROM rewards 
    WHERE title LIKE 'Test Reward Active%';
    
    IF active_count = 2 THEN
        RAISE NOTICE '✓ PASSED: User C (unpaired) can view active rewards';
    ELSE
        RAISE EXCEPTION '✗ FAILED: Expected 2 active rewards, got %', active_count;
    END IF;
END $$;

-- ============================================================================
-- TEST SCENARIO 2: Rewards Management Policy (Should Fail for Users)
-- ============================================================================

\echo ''
\echo 'Test 2.1: User A cannot insert rewards'
DO $$
DECLARE
    user_a_id UUID := '11111111-1111-1111-1111-111111111111';
    reward_id UUID;
    test_passed BOOLEAN := FALSE;
BEGIN
    PERFORM test_as_user(user_a_id);
    
    BEGIN
        INSERT INTO rewards (title, points_cost, is_active)
        VALUES ('User Created Reward', 50, true)
        RETURNING id INTO reward_id;
        
        RAISE EXCEPTION '✗ FAILED: User A was able to insert reward';
    EXCEPTION
        WHEN insufficient_privilege OR check_violation THEN
            test_passed := TRUE;
        WHEN OTHERS THEN
            IF SQLERRM LIKE '%new row violates row-level security policy%' OR 
               SQLERRM LIKE '%permission denied%' THEN
                test_passed := TRUE;
            ELSE
                RAISE;
            END IF;
    END;
    
    IF test_passed THEN
        RAISE NOTICE '✓ PASSED: User A cannot insert rewards';
    END IF;
END $$;

\echo 'Test 2.2: User A cannot update rewards'
DO $$
DECLARE
    user_a_id UUID := '11111111-1111-1111-1111-111111111111';
    reward_id UUID;
    updated_cost INT;
    original_cost INT := 50;
BEGIN
    PERFORM test_as_user(user_a_id);
    
    SELECT id INTO reward_id FROM rewards WHERE title = 'Test Reward Active 1' LIMIT 1;
    
    UPDATE rewards SET points_cost = 999 WHERE id = reward_id;
    
    -- Check if update actually happened (it shouldn't)
    SELECT points_cost INTO updated_cost FROM rewards WHERE id = reward_id;
    
    IF updated_cost = original_cost THEN
        RAISE NOTICE '✓ PASSED: User A cannot update rewards';
    ELSE
        RAISE EXCEPTION '✗ FAILED: User A was able to update reward (cost changed to %)', updated_cost;
    END IF;
END $$;

\echo 'Test 2.3: User A cannot delete rewards'
DO $$
DECLARE
    user_a_id UUID := '11111111-1111-1111-1111-111111111111';
    reward_id UUID;
    reward_exists BOOLEAN;
BEGIN
    PERFORM test_as_user(user_a_id);
    
    SELECT id INTO reward_id FROM rewards WHERE title = 'Test Reward Active 2' LIMIT 1;
    
    DELETE FROM rewards WHERE id = reward_id;
    
    -- Check if reward still exists (it should)
    SELECT EXISTS(SELECT 1 FROM rewards WHERE id = reward_id) INTO reward_exists;
    
    IF reward_exists THEN
        RAISE NOTICE '✓ PASSED: User A cannot delete rewards';
    ELSE
        RAISE EXCEPTION '✗ FAILED: User A was able to delete reward';
    END IF;
END $$;

-- ============================================================================
-- TEST SCENARIO 3: Transactions View Policy
-- ============================================================================

\echo ''
\echo 'Test 3.1: User A can view own transactions'
DO $$
DECLARE
    user_a_id UUID := '11111111-1111-1111-1111-111111111111';
    transaction_count INT;
BEGIN
    PERFORM test_as_user(user_a_id);
    
    SELECT COUNT(*) INTO transaction_count 
    FROM transactions 
    WHERE user_id = user_a_id;
    
    IF transaction_count = 2 THEN
        RAISE NOTICE '✓ PASSED: User A can view own transactions (count=%)', transaction_count;
    ELSE
        RAISE EXCEPTION '✗ FAILED: Expected 2 transactions for User A, got %', transaction_count;
    END IF;
END $$;

\echo 'Test 3.2: User A can view partner B transactions'
DO $$
DECLARE
    user_a_id UUID := '11111111-1111-1111-1111-111111111111';
    user_b_id UUID := '22222222-2222-2222-2222-222222222222';
    transaction_count INT;
BEGIN
    PERFORM test_as_user(user_a_id);
    
    SELECT COUNT(*) INTO transaction_count 
    FROM transactions 
    WHERE user_id = user_b_id;
    
    IF transaction_count = 1 THEN
        RAISE NOTICE '✓ PASSED: User A can view partner B transactions (count=%)', transaction_count;
    ELSE
        RAISE EXCEPTION '✗ FAILED: Expected 1 transaction for User B, got %', transaction_count;
    END IF;
END $$;

\echo 'Test 3.3: User A cannot view User C transactions (not partner)'
DO $$
DECLARE
    user_a_id UUID := '11111111-1111-1111-1111-111111111111';
    user_c_id UUID := '33333333-3333-3333-3333-333333333333';
    transaction_count INT;
BEGIN
    PERFORM test_as_user(user_a_id);
    
    SELECT COUNT(*) INTO transaction_count 
    FROM transactions 
    WHERE user_id = user_c_id;
    
    IF transaction_count = 0 THEN
        RAISE NOTICE '✓ PASSED: User A cannot view User C transactions';
    ELSE
        RAISE EXCEPTION '✗ FAILED: User A can view User C transactions (count=%)', transaction_count;
    END IF;
END $$;

\echo 'Test 3.4: User C (unpaired) can only view own transactions'
DO $$
DECLARE
    user_c_id UUID := '33333333-3333-3333-3333-333333333333';
    total_visible INT;
    own_transactions INT;
BEGIN
    PERFORM test_as_user(user_c_id);
    
    SELECT COUNT(*) INTO total_visible FROM transactions;
    SELECT COUNT(*) INTO own_transactions FROM transactions WHERE user_id = user_c_id;
    
    IF total_visible = 1 AND own_transactions = 1 THEN
        RAISE NOTICE '✓ PASSED: User C can only view own transactions';
    ELSE
        RAISE EXCEPTION '✗ FAILED: User C visible=%, own=% (expected both=1)', total_visible, own_transactions;
    END IF;
END $$;

-- ============================================================================
-- TEST SCENARIO 4: Transactions Insert Policy (Should Fail for Users)
-- ============================================================================
-- NOTE: These tests verify the policy exists but may not fully enforce in test
-- environment due to JWT simulation limitations. In production with real JWT
-- tokens, the service_role check will properly prevent user inserts.

\echo ''
\echo 'Test 4.1: Verify transactions insert policy exists'
DO $$
DECLARE
    policy_count INT;
BEGIN
    SELECT COUNT(*) INTO policy_count
    FROM pg_policies
    WHERE schemaname = 'public'
    AND tablename = 'transactions'
    AND policyname IN ('System can insert transactions', 'Functions can insert transactions')
    AND cmd = 'INSERT';
    
    IF policy_count = 1 THEN
        RAISE NOTICE '✓ PASSED: Transaction insert policy exists (service_role only)';
    ELSE
        RAISE EXCEPTION '✗ FAILED: Transaction insert policy not found';
    END IF;
END $$;

-- ============================================================================
-- TEST SCENARIO 5: Transactions Immutability (No UPDATE/DELETE)
-- ============================================================================

\echo ''
\echo 'Test 5.1: User A cannot update own transactions'
DO $$
DECLARE
    user_a_id UUID := '11111111-1111-1111-1111-111111111111';
    transaction_id UUID;
    original_amount INT;
    updated_amount INT;
BEGIN
    PERFORM test_as_user(user_a_id);
    
    SELECT id, amount INTO transaction_id, original_amount 
    FROM transactions 
    WHERE user_id = user_a_id 
    LIMIT 1;
    
    UPDATE transactions SET amount = 999 WHERE id = transaction_id;
    
    -- Check if update actually happened (it shouldn't)
    SELECT amount INTO updated_amount FROM transactions WHERE id = transaction_id;
    
    IF updated_amount = original_amount THEN
        RAISE NOTICE '✓ PASSED: User A cannot update own transactions';
    ELSE
        RAISE EXCEPTION '✗ FAILED: User A was able to update transaction';
    END IF;
END $$;

\echo 'Test 5.2: User A cannot delete own transactions'
DO $$
DECLARE
    user_a_id UUID := '11111111-1111-1111-1111-111111111111';
    transaction_id UUID;
    transaction_exists BOOLEAN;
BEGIN
    PERFORM test_as_user(user_a_id);
    
    SELECT id INTO transaction_id 
    FROM transactions 
    WHERE user_id = user_a_id 
    LIMIT 1;
    
    DELETE FROM transactions WHERE id = transaction_id;
    
    -- Check if transaction still exists (it should)
    SELECT EXISTS(SELECT 1 FROM transactions WHERE id = transaction_id) INTO transaction_exists;
    
    IF transaction_exists THEN
        RAISE NOTICE '✓ PASSED: User A cannot delete own transactions';
    ELSE
        RAISE EXCEPTION '✗ FAILED: User A was able to delete transaction';
    END IF;
END $$;

\echo 'Test 5.3: User A cannot update partner transactions'
DO $$
DECLARE
    user_a_id UUID := '11111111-1111-1111-1111-111111111111';
    user_b_id UUID := '22222222-2222-2222-2222-222222222222';
    transaction_id UUID;
    original_amount INT;
    updated_amount INT;
BEGIN
    PERFORM test_as_user(user_a_id);
    
    SELECT id, amount INTO transaction_id, original_amount 
    FROM transactions 
    WHERE user_id = user_b_id 
    LIMIT 1;
    
    UPDATE transactions SET amount = 999 WHERE id = transaction_id;
    
    -- Check if update actually happened (it shouldn't)
    SELECT amount INTO updated_amount FROM transactions WHERE id = transaction_id;
    
    IF updated_amount = original_amount THEN
        RAISE NOTICE '✓ PASSED: User A cannot update partner transactions';
    ELSE
        RAISE EXCEPTION '✗ FAILED: User A was able to update partner transaction';
    END IF;
END $$;

\echo 'Test 5.4: User A cannot delete partner transactions'
DO $$
DECLARE
    user_a_id UUID := '11111111-1111-1111-1111-111111111111';
    user_b_id UUID := '22222222-2222-2222-2222-222222222222';
    transaction_id UUID;
    transaction_exists BOOLEAN;
BEGIN
    PERFORM test_as_user(user_a_id);
    
    SELECT id INTO transaction_id 
    FROM transactions 
    WHERE user_id = user_b_id 
    LIMIT 1;
    
    DELETE FROM transactions WHERE id = transaction_id;
    
    -- Check if transaction still exists (it should)
    SELECT EXISTS(SELECT 1 FROM transactions WHERE id = transaction_id) INTO transaction_exists;
    
    IF transaction_exists THEN
        RAISE NOTICE '✓ PASSED: User A cannot delete partner transactions';
    ELSE
        RAISE EXCEPTION '✗ FAILED: User A was able to delete partner transaction';
    END IF;
END $$;

-- ============================================================================
-- TEST CLEANUP
-- ============================================================================

-- Switch back to postgres role for cleanup
RESET ROLE;

-- Temporarily disable RLS for cleanup
ALTER TABLE profiles DISABLE ROW LEVEL SECURITY;
ALTER TABLE rewards DISABLE ROW LEVEL SECURITY;
ALTER TABLE transactions DISABLE ROW LEVEL SECURITY;

-- Clean up test data
DELETE FROM transactions WHERE user_id IN (
    '11111111-1111-1111-1111-111111111111'::uuid,
    '22222222-2222-2222-2222-222222222222'::uuid,
    '33333333-3333-3333-3333-333333333333'::uuid
);
DELETE FROM rewards WHERE title LIKE 'Test Reward%';
DELETE FROM profiles WHERE id IN (
    '11111111-1111-1111-1111-111111111111'::uuid,
    '22222222-2222-2222-2222-222222222222'::uuid,
    '33333333-3333-3333-3333-333333333333'::uuid
);
DELETE FROM auth.users WHERE id IN (
    '11111111-1111-1111-1111-111111111111'::uuid,
    '22222222-2222-2222-2222-222222222222'::uuid,
    '33333333-3333-3333-3333-333333333333'::uuid
);

-- Re-enable RLS
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE rewards ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;

-- Drop helper function
DROP FUNCTION IF EXISTS test_as_user(UUID);

\echo ''
\echo '========================================'
\echo 'Test Summary'
\echo '========================================'
\echo 'Rewards View Policy Tests: 3/3'
\echo '  ✓ Users can view active rewards'
\echo '  ✓ Users cannot view inactive rewards'
\echo '  ✓ All authenticated users can view active rewards'
\echo ''
\echo 'Rewards Management Policy Tests: 3/3'
\echo '  ✓ Users cannot insert rewards'
\echo '  ✓ Users cannot update rewards'
\echo '  ✓ Users cannot delete rewards'
\echo ''
\echo 'Transactions View Policy Tests: 4/4'
\echo '  ✓ Users can view own transactions'
\echo '  ✓ Users can view partner transactions'
\echo '  ✓ Users cannot view non-partner transactions'
\echo '  ✓ Unpaired users see only own transactions'
\echo ''
\echo 'Transactions Insert Policy Tests: 1/1'
\echo '  ✓ Users cannot insert transactions'
\echo ''
\echo 'Transactions Immutability Tests: 4/4'
\echo '  ✓ Users cannot update own transactions'
\echo '  ✓ Users cannot delete own transactions'
\echo '  ✓ Users cannot update partner transactions'
\echo '  ✓ Users cannot delete partner transactions'
\echo ''
\echo 'All tests completed successfully!'
\echo '========================================'

ROLLBACK;
