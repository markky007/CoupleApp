# Quest Completion Atomicity Implementation

## Overview

The quest completion workflow has been enhanced to ensure **true atomicity** - all operations succeed together or fail together with no partial state changes.

## Problem Statement

The original implementation performed three separate operations:

1. Update quest status to 'completed'
2. Award points to user via ProfileService.updatePoints
3. Create transaction record

If any operation failed after the first succeeded, the system would be left in an inconsistent state (e.g., quest marked complete but points not awarded).

## Solution

### Database-Level Atomicity

We implemented a PostgreSQL function `complete_quest_atomic()` that wraps all three operations in a single database transaction:

```sql
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

  -- Validation checks...

  -- Step 2: Update quest status
  UPDATE quests SET status = 'completed', completed_at = NOW()
  WHERE id = p_quest_id;

  -- Step 3: Award points (calls increment_user_points)
  PERFORM increment_user_points(p_user_id, v_quest.points);

  -- Step 4: Create transaction record
  INSERT INTO transactions (user_id, type, amount, description)
  VALUES (p_user_id, 'earn', v_quest.points, 'Completed quest: ' || v_quest.title)
  RETURNING id INTO v_transaction_id;

  -- Return success details
  RETURN jsonb_build_object(...);

EXCEPTION
  WHEN OTHERS THEN
    -- Any error causes automatic rollback
    RAISE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

### Key Features

1. **Row-Level Locking**: Uses `FOR UPDATE` to lock the quest row, preventing concurrent modifications
2. **Validation Before Changes**: Checks quest status and expiration before making any changes
3. **Automatic Rollback**: PostgreSQL's transaction mechanism ensures all changes rollback on any error
4. **Single RPC Call**: Swift code makes one RPC call instead of three separate operations

### Swift Implementation

```swift
func completeQuest(questId: UUID, userId: UUID) async throws {
    let paramsDict: [String: AnyJSON] = [
        "p_quest_id": .string(questId.uuidString),
        "p_user_id": .string(userId.uuidString),
    ]

    let response: [String: AnyJSON] =
        try await client
        .rpc("complete_quest_atomic", params: paramsDict)
        .execute()
        .value

    // Handle response...
}
```

## Guarantees

### Atomicity Guarantees

✅ **All-or-Nothing**: Either all three operations succeed, or none do
✅ **No Partial State**: System never left in inconsistent state
✅ **Concurrent Safety**: Row locking prevents race conditions
✅ **Error Recovery**: Automatic rollback on any failure

### Validation Guarantees

✅ Quest must exist
✅ Quest must have status = 'pending'
✅ Quest must not be expired
✅ User must have valid profile
✅ Point update must not cause negative balance

## Error Handling

The function throws specific errors that are caught and mapped to QuestError types:

- `Quest not found` → `QuestError.questNotFound`
- `Quest already completed` → `QuestError.alreadyCompleted`
- `Quest has expired` → `QuestError.questExpired`
- `Insufficient points` → `QuestError.pointAwardFailed`

## Testing

See `QuestService.test.swift` for comprehensive tests covering:

1. ✅ Successful atomic completion
2. ✅ Rollback on quest not found
3. ✅ Prevention of duplicate completion
4. ✅ Prevention of expired quest completion

## Migration

The atomic function is defined in:

- `supabase/migrations/20260309032000_add_complete_quest_function.sql`

Apply with:

```bash
npx supabase db reset
```

## Benefits

1. **Data Integrity**: Guaranteed consistency across all operations
2. **Simplified Code**: Single RPC call instead of complex error handling
3. **Better Performance**: Reduced network round-trips (1 instead of 3)
4. **Easier Debugging**: All operations succeed or fail together
5. **Concurrent Safety**: Database-level locking prevents race conditions

## Comparison: Before vs After

### Before (Non-Atomic)

```swift
// ❌ Three separate operations - risk of partial failure
try await updateQuestStatus(questId)      // Operation 1
try await updatePoints(userId, delta)     // Operation 2 - might fail here
try await createTransaction(...)          // Operation 3 - never reached
```

### After (Atomic)

```swift
// ✅ Single atomic operation - all succeed or all fail
try await client.rpc("complete_quest_atomic", params: ...)
```

## Future Enhancements

Potential improvements:

- Add support for quest completion notifications
- Track completion time for analytics
- Support for bonus points based on completion speed
- Add quest completion streaks

## References

- Design Document: `.kiro/specs/couple-quest-app/design.md` (Algorithm 1)
- Database Schema: `supabase/migrations/20260309031604_initial_schema.sql`
- Service Implementation: `coupleapp/Services/QuestService.swift`
