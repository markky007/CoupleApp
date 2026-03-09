# Supabase RLS Policy Tests

This directory contains Row Level Security (RLS) policy tests for the Couple Quest application.

## Test Files

- `quest_rls_test.sql` - Tests for quest-related RLS policies
- `rewards_transactions_rls_test.sql` - Tests for rewards and transactions RLS policies

## Running Tests

### Prerequisites

- Local Supabase instance running via Docker
- PostgreSQL client tools installed

### Run All Tests

```bash
# Run rewards and transactions RLS tests
docker exec -i supabase_db_coupleapp psql -U postgres -d postgres -f /dev/stdin < supabase/tests/rewards_transactions_rls_test.sql

# Run quest RLS tests
docker exec -i supabase_db_coupleapp psql -U postgres -d postgres -f /dev/stdin < supabase/tests/quest_rls_test.sql
```

### Test Coverage

#### Rewards RLS Policies

**View Policies:**

- ✓ All authenticated users can view active rewards
- ✓ Users cannot view inactive rewards

**Management Policies:**

- ✓ Users cannot insert rewards (admin only)
- ✓ Users cannot update rewards (admin only)
- ✓ Users cannot delete rewards (admin only)

#### Transactions RLS Policies

**View Policies:**

- ✓ Users can view their own transactions
- ✓ Users can view their partner's transactions
- ✓ Users cannot view non-partner transactions
- ✓ Unpaired users can only see their own transactions

**Insert Policies:**

- ✓ Users cannot directly insert transactions (must use service functions)

**Immutability:**

- ✓ Users cannot update their own transactions
- ✓ Users cannot delete their own transactions
- ✓ Users cannot update partner transactions
- ✓ Users cannot delete partner transactions

## Test Scenarios

### User Setup

Each test creates three test users:

- **User A**: Paired with User B
- **User B**: Paired with User A
- **User C**: Unpaired user

### Test Data

- 3 rewards (2 active, 1 inactive)
- 4 transactions (2 for User A, 1 for User B, 1 for User C)

### Cleanup

All tests run within a transaction that is rolled back at the end, ensuring no test data persists in the database.

## Notes

- Tests use the `authenticated` role to simulate real user access
- The `test_as_user()` function simulates different user contexts by setting JWT claims
- All tests are designed to be idempotent and can be run multiple times
- Tests verify both positive cases (allowed operations) and negative cases (blocked operations)
