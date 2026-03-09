# Quest RLS Policies Documentation

## Overview

This document describes the Row Level Security (RLS) policies implemented for the `quests` table in the Couple Quest application. These policies ensure that quest data is properly secured and only accessible to authorized users.

## Security Requirements

The quest RLS policies enforce the following security requirements:

1. **View Access**: Users can only view quests created by themselves or their partner
2. **Create Access**: Users can create quests and must set themselves as the creator
3. **Update Access**: Users can complete quests (update status to 'completed' only)
4. **Delete Access**: Users can only delete quests they created

## Policy Definitions

### 1. View Policy: "Users can view shared quests"

**Purpose**: Allow users to view quests in their shared quest board with their partner.

**SQL Definition**:

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

**Behavior**:

- User can view quests they created
- User can view quests created by their partner
- User cannot view quests created by non-partners

**Example Scenarios**:

- ✅ Alice creates quest → Alice can view it
- ✅ Alice creates quest → Bob (Alice's partner) can view it
- ❌ Alice creates quest → Charlie (not partner) cannot view it

---

### 2. Create Policy: "Users can create quests"

**Purpose**: Allow users to create quests for their shared quest board.

**SQL Definition**:

```sql
CREATE POLICY "Users can create quests"
  ON quests FOR INSERT
  WITH CHECK (
    auth.uid() = created_by
  );
```

**Behavior**:

- User can create quests with themselves as the creator
- User cannot create quests with someone else as the creator

**Example Scenarios**:

- ✅ Alice creates quest with created_by = Alice → Success
- ❌ Alice creates quest with created_by = Bob → Fails (policy violation)

---

### 3. Complete Policy: "Users can complete quests"

**Purpose**: Allow users to complete quests by updating the status to 'completed', while preventing modification of other fields.

**SQL Definition**:

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
    AND title = (SELECT title FROM quests WHERE id = quests.id)
    AND points = (SELECT points FROM quests WHERE id = quests.id)
    AND created_by = (SELECT created_by FROM quests WHERE id = quests.id)
    AND event_id IS NOT DISTINCT FROM (SELECT event_id FROM quests WHERE id = quests.id)
    AND expire_at IS NOT DISTINCT FROM (SELECT expire_at FROM quests WHERE id = quests.id)
  );
```

**Behavior**:

- User can complete pending quests they created
- User can complete pending quests created by their partner
- User cannot complete quests created by non-partners
- User cannot complete already completed quests
- User cannot update fields other than status (title, points, etc. must remain unchanged)

**Example Scenarios**:

- ✅ Alice completes pending quest created by Alice → Success
- ✅ Bob completes pending quest created by Alice (partner) → Success
- ❌ Charlie completes pending quest created by Alice → Fails (not partner)
- ❌ Alice completes already completed quest → Fails (status not 'pending')
- ❌ Alice updates points field → Fails (WITH CHECK prevents field changes)

---

### 4. Delete Policy: "Users can delete own quests"

**Purpose**: Allow users to delete quests they created.

**SQL Definition**:

```sql
CREATE POLICY "Users can delete own quests"
  ON quests FOR DELETE
  USING (
    auth.uid() = created_by
  );
```

**Behavior**:

- User can delete quests they created
- User cannot delete quests created by others (including partner)

**Example Scenarios**:

- ✅ Alice deletes quest created by Alice → Success
- ❌ Bob deletes quest created by Alice → Fails (even though Bob is partner)

---

## Testing the Policies

### Automated Testing

Run the automated test suite:

```bash
# Run all RLS tests
swift test --filter QuestRLSTests
```

See `coupleapp/Tests/QuestRLSTests.swift` for test implementation.

### Manual Testing

#### Setup Test Environment

1. Create three test users in Supabase Auth:
   - User A (primary user)
   - User B (partner of User A)
   - User C (unrelated user)

2. Create profiles for each user:

```sql
INSERT INTO profiles (id, display_name) VALUES
  ('<user_a_id>', 'Alice'),
  ('<user_b_id>', 'Bob'),
  ('<user_c_id>', 'Charlie');
```

3. Pair User A and User B:

```sql
UPDATE profiles SET partner_id = '<user_b_id>' WHERE id = '<user_a_id>';
UPDATE profiles SET partner_id = '<user_a_id>' WHERE id = '<user_b_id>';
```

#### Test Scenarios

**Test 1: View Policy**

```sql
-- As User A: Create a quest
INSERT INTO quests (title, points, created_by)
VALUES ('Do dishes', 10, '<user_a_id>');

-- As User A: View quests (should see the quest)
SELECT * FROM quests;

-- As User B: View quests (should see the quest - partner)
SELECT * FROM quests;

-- As User C: View quests (should NOT see the quest - not partner)
SELECT * FROM quests;
```

**Test 2: Create Policy**

```sql
-- As User A: Create quest with self as creator (should succeed)
INSERT INTO quests (title, points, created_by)
VALUES ('My Quest', 10, '<user_a_id>');

-- As User A: Create quest with someone else as creator (should fail)
INSERT INTO quests (title, points, created_by)
VALUES ('Fake Quest', 10, '<user_b_id>');
```

**Test 3: Complete Policy**

```sql
-- As User A: Complete own pending quest (should succeed)
UPDATE quests
SET status = 'completed'
WHERE id = '<quest_id>' AND status = 'pending';

-- As User B: Complete partner's pending quest (should succeed)
UPDATE quests
SET status = 'completed'
WHERE id = '<quest_id>' AND status = 'pending';

-- As User C: Complete quest (should fail - not partner)
UPDATE quests
SET status = 'completed'
WHERE id = '<quest_id>';

-- As User A: Complete already completed quest (should fail)
UPDATE quests
SET status = 'completed'
WHERE id = '<quest_id>' AND status = 'completed';

-- As User A: Update points field (should fail)
UPDATE quests
SET points = 999
WHERE id = '<quest_id>';
```

**Test 4: Delete Policy**

```sql
-- As User A: Delete own quest (should succeed)
DELETE FROM quests WHERE id = '<quest_id>';

-- As User B: Delete partner's quest (should fail)
DELETE FROM quests WHERE id = '<quest_id>';
```

---

## Security Considerations

### Partner Relationship Validation

The policies rely on the `partner_id` field in the `profiles` table to determine partner relationships. Key considerations:

1. **Bidirectional Relationship**: Partner relationships must be bidirectional (if A.partner_id = B, then B.partner_id = A)
2. **NULL Handling**: The policies check `partner_id IS NOT NULL` to ensure only paired users can access shared quests
3. **Orphaned Relationships**: If a partner relationship is broken, users lose access to each other's quests

### Status Transition Control

The complete policy enforces strict status transitions:

1. **One-Way Transition**: Status can only change from 'pending' to 'completed'
2. **Immutable Completion**: Once completed, a quest cannot be uncompleted
3. **Field Protection**: The WITH CHECK clause prevents modification of other fields during completion

### Field Immutability

The complete policy uses subqueries to verify that fields other than status remain unchanged:

```sql
AND title = (SELECT title FROM quests WHERE id = quests.id)
AND points = (SELECT points FROM quests WHERE id = quests.id)
-- ... etc
```

This ensures that users cannot:

- Change quest points after creation
- Modify quest title
- Reassign quest to different creator
- Change event association

---

## Troubleshooting

### Common Issues

**Issue**: User cannot view partner's quests

**Possible Causes**:

1. Partner relationship not properly set (check `partner_id` in profiles)
2. Partner relationship not bidirectional
3. User not authenticated (check `auth.uid()`)

**Solution**:

```sql
-- Verify partner relationship
SELECT id, display_name, partner_id FROM profiles
WHERE id IN ('<user_a_id>', '<user_b_id>');

-- Ensure bidirectional relationship
UPDATE profiles SET partner_id = '<user_b_id>' WHERE id = '<user_a_id>';
UPDATE profiles SET partner_id = '<user_a_id>' WHERE id = '<user_b_id>';
```

---

**Issue**: Cannot complete quest (policy violation)

**Possible Causes**:

1. Quest already completed (status = 'completed')
2. User not authorized (not creator or partner)
3. Attempting to update fields other than status

**Solution**:

```sql
-- Check quest status
SELECT id, title, status, created_by FROM quests WHERE id = '<quest_id>';

-- Verify user is creator or partner
SELECT p1.id as user_id, p1.partner_id, p2.id as partner_id
FROM profiles p1
LEFT JOIN profiles p2 ON p1.partner_id = p2.id
WHERE p1.id = '<user_id>';

-- Ensure only updating status field
UPDATE quests SET status = 'completed' WHERE id = '<quest_id>';
```

---

**Issue**: Cannot delete quest (policy violation)

**Possible Causes**:

1. User is not the quest creator
2. User not authenticated

**Solution**:

```sql
-- Verify quest creator
SELECT id, title, created_by FROM quests WHERE id = '<quest_id>';

-- Only creator can delete
-- Partners cannot delete each other's quests
```

---

## Migration History

- **20260309031604_initial_schema.sql**: Initial quest RLS policies
- **20260309040000_quest_rls_policies.sql**: Enhanced policies with field immutability

---

## References

- [Supabase RLS Documentation](https://supabase.com/docs/guides/auth/row-level-security)
- [PostgreSQL Row Security Policies](https://www.postgresql.org/docs/current/ddl-rowsecurity.html)
- Design Document: `.kiro/specs/couple-quest-app/design.md`
- Requirements: `.kiro/specs/couple-quest-app/requirements.md`
