# Task 3.5: Quest RLS Policies - Test Results

## Overview

This document summarizes the test results for the Quest RLS (Row Level Security) policies implemented in the Couple Quest application.

## Test Execution

**Date**: 2026-03-09  
**Test File**: `supabase/tests/quest_rls_test.sql`  
**Database**: Local Supabase instance  
**Status**: ✅ ALL TESTS PASSED

## Test Results Summary

### View Policy Tests (3/3 PASSED)

- ✅ Test 1.1: Creator can view own quests
- ✅ Test 1.2: Partner can view creator's quests
- ✅ Test 1.3: Non-partners cannot view quests

### Create Policy Tests (2/2 PASSED)

- ✅ Test 2.1: Users can create quests with themselves as creator
- ✅ Test 2.2: Users cannot create quests with others as creator

### Complete Policy Tests (5/5 PASSED)

- ✅ Test 3.1: Creator can complete own pending quests
- ✅ Test 3.2: Partner can complete creator's pending quests
- ✅ Test 3.3: Non-partners cannot complete quests
- ✅ Test 3.4: Cannot complete already completed quests
- ✅ Test 3.5: Cannot update fields other than status

### Delete Policy Tests (2/2 PASSED)

- ✅ Test 4.1: Creator can delete own quests
- ✅ Test 4.2: Partner cannot delete creator's quests

## RLS Policies Verified

### 1. Users can view shared quests (SELECT)

**Policy**: Users can view quests created by themselves or their partner

**Implementation**:

```sql
CREATE POLICY "Users can view shared quests"
  ON quests FOR SELECT
  USING (
    auth.uid() = created_by
    OR
    auth.uid() IN (
      SELECT partner_id
      FROM profiles
      WHERE id = created_by AND partner_id IS NOT NULL
    )
  );
```

**Test Scenarios**:

- ✅ User A creates quest → User A can view
- ✅ User A creates quest → User B (partner) can view
- ✅ User A creates quest → User C (non-partner) cannot view

### 2. Users can create quests (INSERT)

**Policy**: Users can only create quests with themselves as the creator

**Implementation**:

```sql
CREATE POLICY "Users can create quests"
  ON quests FOR INSERT
  WITH CHECK (
    auth.uid() = created_by
  );
```

**Test Scenarios**:

- ✅ User A creates quest with created_by = User A → Success
- ✅ User A creates quest with created_by = User B → Blocked

### 3. Users can complete quests (UPDATE)

**Policy**: Both creator and partner can complete pending quests, status-only updates

**Implementation**:

```sql
CREATE POLICY "Users can complete quests"
  ON quests FOR UPDATE
  USING (
    status = 'pending'
    AND
    (
      auth.uid() = created_by
      OR
      auth.uid() IN (
        SELECT partner_id
        FROM profiles
        WHERE id = created_by AND partner_id IS NOT NULL
      )
    )
  )
  WITH CHECK (
    status = 'completed'
  );
```

**Additional Protection**: Trigger `enforce_quest_completion_immutability` ensures field immutability

**Test Scenarios**:

- ✅ User A completes own pending quest → Success
- ✅ User B (partner) completes User A's pending quest → Success
- ✅ User C (non-partner) attempts to complete User A's quest → Blocked
- ✅ User A attempts to complete already completed quest → Blocked
- ✅ User A attempts to modify points while completing → Blocked by trigger

### 4. Users can delete own quests (DELETE)

**Policy**: Only the quest creator can delete their quests

**Implementation**:

```sql
CREATE POLICY "Users can delete own quests"
  ON quests FOR DELETE
  USING (
    auth.uid() = created_by
  );
```

**Test Scenarios**:

- ✅ User A deletes own quest → Success
- ✅ User B (partner) attempts to delete User A's quest → Blocked

## Technical Implementation Details

### Test Setup

- Created 3 test users in `auth.users` table
- Created corresponding profiles with partner relationships:
  - User A and User B are partners (bidirectional)
  - User C is unpaired
- Tests run as `authenticated` role to properly enforce RLS policies
- Helper function `test_as_user(UUID)` simulates different user contexts

### Key Findings

1. **RLS Enforcement**: RLS policies only apply to non-superuser roles. Tests must run as `authenticated` role.

2. **Silent Failures**: When RLS blocks an operation, PostgreSQL doesn't raise an exception - it simply affects 0 rows. Tests verify by checking actual data state.

3. **Infinite Recursion Fix**: The original complete policy had infinite recursion due to subqueries. Fixed by:
   - Simplifying the WITH CHECK clause
   - Adding a trigger for field immutability enforcement

4. **Field Immutability**: Implemented via trigger `check_quest_completion_fields()` which validates that only status changes during quest completion.

## Running the Tests

To run the tests locally:

```bash
# Method 1: Using docker exec
cat supabase/tests/quest_rls_test.sql | docker exec -i supabase_db_coupleapp psql -U postgres -d postgres

# Method 2: If psql is installed locally
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -f supabase/tests/quest_rls_test.sql
```

## Conclusion

All RLS policies for the quests table have been successfully implemented and thoroughly tested. The policies correctly enforce:

- View access control (creator and partner only)
- Create restrictions (self as creator only)
- Update permissions (creator and partner can complete, status-only changes)
- Delete permissions (creator only)

The security model ensures that quest data is properly isolated between couples while allowing collaborative quest completion within partner relationships.
