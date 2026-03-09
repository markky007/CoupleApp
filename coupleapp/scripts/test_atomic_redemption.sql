-- ============================================================================
-- Manual Test Script: Atomic Reward Redemption
-- ============================================================================
-- This script tests the atomic reward redemption functionality
-- Run with: psql -h localhost -p 54322 -U postgres -d postgres -f scripts/test_atomic_redemption.sql
-- ============================================================================

\echo '=== Setting up test data ==='

-- Create test user profile
INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, created_at, updated_at)
VALUES (
  '00000000-0000-0000-0000-000000000001',
  'test@example.com',
  crypt('password123', gen_salt('bf')),
  NOW(),
  NOW(),
  NOW()
) ON CONFLICT (id) DO NOTHING;

-- Create test profile with 100 points
INSERT INTO profiles (id, display_name, total_points)
VALUES (
  '00000000-0000-0000-0000-000000000001',
  'Test User',
  100
) ON CONFLICT (id) DO UPDATE SET total_points = 100;

-- Create test reward costing 50 points
INSERT INTO rewards (id, title, points_cost, is_active)
VALUES (
  '00000000-0000-0000-0000-000000000002',
  'Test Reward',
  50,
  true
) ON CONFLICT (id) DO UPDATE SET points_cost = 50, is_active = true;

\echo '=== Initial state ==='
SELECT id, display_name, total_points FROM profiles WHERE id = '00000000-0000-0000-0000-000000000001';
SELECT id, title, points_cost, is_active FROM rewards WHERE id = '00000000-0000-0000-0000-000000000002';

\echo ''
\echo '=== Test 1: Successful redemption with sufficient points ==='
SELECT redeem_reward_atomic(
  '00000000-0000-0000-0000-000000000002'::uuid,
  '00000000-0000-0000-0000-000000000001'::uuid
);

\echo '=== After redemption ==='
SELECT id, display_name, total_points FROM profiles WHERE id = '00000000-0000-0000-0000-000000000001';
SELECT id, type, amount, description FROM transactions WHERE user_id = '00000000-0000-0000-0000-000000000001' ORDER BY created_at DESC LIMIT 1;

\echo ''
\echo '=== Test 2: Redemption with insufficient points (should fail) ==='
SELECT redeem_reward_atomic(
  '00000000-0000-0000-0000-000000000002'::uuid,
  '00000000-0000-0000-0000-000000000001'::uuid
);

\echo '=== After failed redemption (points should be unchanged) ==='
SELECT id, display_name, total_points FROM profiles WHERE id = '00000000-0000-0000-0000-000000000001';

\echo ''
\echo '=== Test 3: Redemption of inactive reward (should fail) ==='
-- Deactivate the reward
UPDATE rewards SET is_active = false WHERE id = '00000000-0000-0000-0000-000000000002';

-- Reset user points
UPDATE profiles SET total_points = 100 WHERE id = '00000000-0000-0000-0000-000000000001';

SELECT redeem_reward_atomic(
  '00000000-0000-0000-0000-000000000002'::uuid,
  '00000000-0000-0000-0000-000000000001'::uuid
);

\echo '=== After failed redemption (points should be unchanged) ==='
SELECT id, display_name, total_points FROM profiles WHERE id = '00000000-0000-0000-0000-000000000001';

\echo ''
\echo '=== Test 4: Redemption of non-existent reward (should fail) ==='
SELECT redeem_reward_atomic(
  '99999999-9999-9999-9999-999999999999'::uuid,
  '00000000-0000-0000-0000-000000000001'::uuid
);

\echo ''
\echo '=== Cleanup ==='
DELETE FROM transactions WHERE user_id = '00000000-0000-0000-0000-000000000001';
DELETE FROM profiles WHERE id = '00000000-0000-0000-0000-000000000001';
DELETE FROM rewards WHERE id = '00000000-0000-0000-0000-000000000002';
DELETE FROM auth.users WHERE id = '00000000-0000-0000-0000-000000000001';

\echo '=== Tests complete ==='
