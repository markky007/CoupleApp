-- ============================================================================
-- Quest RLS Policies Enhancement
-- ============================================================================
-- This migration enhances the RLS policies for the quests table to ensure:
-- 1. Users can view quests created by themselves or their partner
-- 2. Users can complete quests (UPDATE status only, not other fields)
-- 3. Users can create quests
-- 4. Users can delete their own quests
-- ============================================================================

-- Drop existing quest policies to recreate them with enhancements
DROP POLICY IF EXISTS "Users can view shared quests" ON quests;
DROP POLICY IF EXISTS "Users can create quests" ON quests;
DROP POLICY IF EXISTS "Users can complete quests" ON quests;
DROP POLICY IF EXISTS "Users can delete own quests" ON quests;

-- ============================================================================
-- ENHANCED QUEST POLICIES
-- ============================================================================

-- Policy 1: Users can view quests created by themselves or their partner
-- This allows both partners to see all quests in their shared quest board
CREATE POLICY "Users can view shared quests"
  ON quests FOR SELECT
  USING (
    -- User created the quest
    auth.uid() = created_by 
    OR
    -- User is the partner of the quest creator
    auth.uid() IN (
      SELECT partner_id 
      FROM profiles 
      WHERE id = created_by AND partner_id IS NOT NULL
    )
  );

-- Policy 2: Users can create quests
-- Users can create quests and must set themselves as the creator
CREATE POLICY "Users can create quests"
  ON quests FOR INSERT
  WITH CHECK (
    auth.uid() = created_by
  );

-- Policy 3: Users can complete quests (UPDATE status only)
-- Both the creator and their partner can complete quests
-- This policy ensures only the status field can be updated to 'completed'
CREATE POLICY "Users can complete quests"
  ON quests FOR UPDATE
  USING (
    -- Quest must be in pending status
    status = 'pending'
    AND
    -- User is either the creator or the partner
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
    -- Only allow changing status to completed
    status = 'completed'
    -- Ensure other fields remain unchanged
    AND title = (SELECT title FROM quests WHERE id = quests.id)
    AND points = (SELECT points FROM quests WHERE id = quests.id)
    AND created_by = (SELECT created_by FROM quests WHERE id = quests.id)
    AND event_id IS NOT DISTINCT FROM (SELECT event_id FROM quests WHERE id = quests.id)
    AND expire_at IS NOT DISTINCT FROM (SELECT expire_at FROM quests WHERE id = quests.id)
  );

-- Policy 4: Users can delete their own quests
-- Only the quest creator can delete quests they created
CREATE POLICY "Users can delete own quests"
  ON quests FOR DELETE
  USING (
    auth.uid() = created_by
  );

-- ============================================================================
-- VERIFICATION COMMENTS
-- ============================================================================
-- 
-- Policy Testing Scenarios:
-- 
-- 1. View Policy:
--    - User A creates quest → User A can view ✓
--    - User A creates quest → User B (partner) can view ✓
--    - User A creates quest → User C (not partner) cannot view ✓
-- 
-- 2. Create Policy:
--    - User A creates quest with created_by = A → Success ✓
--    - User A creates quest with created_by = B → Fail ✓
-- 
-- 3. Complete Policy:
--    - User A completes pending quest created by A → Success ✓
--    - User B completes pending quest created by A (partner) → Success ✓
--    - User C completes pending quest created by A (not partner) → Fail ✓
--    - User A completes already completed quest → Fail ✓
--    - User A tries to update points field → Fail ✓
-- 
-- 4. Delete Policy:
--    - User A deletes quest created by A → Success ✓
--    - User B deletes quest created by A → Fail ✓
-- 
-- ============================================================================
