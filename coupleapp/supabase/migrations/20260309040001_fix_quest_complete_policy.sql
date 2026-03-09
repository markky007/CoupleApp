-- ============================================================================
-- Fix Quest Complete Policy - Remove Infinite Recursion
-- ============================================================================
-- This migration fixes the infinite recursion issue in the quest complete
-- policy by using a simpler approach that doesn't require subqueries.
-- ============================================================================

-- Drop the existing complete policy
DROP POLICY IF EXISTS "Users can complete quests" ON quests;

-- Recreate the policy with a simpler approach
-- Note: PostgreSQL RLS doesn't support OLD/NEW references like triggers do
-- Instead, we'll use a trigger to enforce field immutability
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
    -- Note: Field immutability is enforced by the trigger below
  );

-- Create a trigger to enforce field immutability during quest completion
CREATE OR REPLACE FUNCTION check_quest_completion_fields()
RETURNS TRIGGER AS $$
BEGIN
    -- Only check if status is being changed to completed
    IF NEW.status = 'completed' AND OLD.status = 'pending' THEN
        -- Ensure other fields remain unchanged
        IF NEW.title != OLD.title THEN
            RAISE EXCEPTION 'Cannot modify title when completing quest';
        END IF;
        
        IF NEW.points != OLD.points THEN
            RAISE EXCEPTION 'Cannot modify points when completing quest';
        END IF;
        
        IF NEW.created_by != OLD.created_by THEN
            RAISE EXCEPTION 'Cannot modify created_by when completing quest';
        END IF;
        
        IF NEW.event_id IS DISTINCT FROM OLD.event_id THEN
            RAISE EXCEPTION 'Cannot modify event_id when completing quest';
        END IF;
        
        IF NEW.expire_at IS DISTINCT FROM OLD.expire_at THEN
            RAISE EXCEPTION 'Cannot modify expire_at when completing quest';
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS enforce_quest_completion_immutability ON quests;

-- Create the trigger
CREATE TRIGGER enforce_quest_completion_immutability
    BEFORE UPDATE ON quests
    FOR EACH ROW
    EXECUTE FUNCTION check_quest_completion_fields();

-- ============================================================================
-- VERIFICATION
-- ============================================================================
-- The policy now allows updates when:
-- 1. Quest status is 'pending'
-- 2. User is creator or partner
-- 3. New status is 'completed'
--
-- The trigger ensures:
-- 1. Other fields cannot be modified during completion
-- 2. Clear error messages for field modification attempts
-- ============================================================================
