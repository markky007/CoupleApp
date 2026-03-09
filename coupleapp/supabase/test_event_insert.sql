-- Test inserting an event to verify format
-- Get a user ID first (assuming you're logged in)
DO $$
DECLARE
    test_user_id UUID;
BEGIN
    -- Get the first user ID from auth.users
    SELECT id INTO test_user_id FROM auth.users LIMIT 1;
    
    -- If no user exists, create a test user
    IF test_user_id IS NULL THEN
        RAISE NOTICE 'No users found in database. Please log in first.';
    ELSE
        -- Insert a test event
        INSERT INTO public.events (
            title,
            event_date,
            is_recurring,
            created_by,
            created_at,
            updated_at
        ) VALUES (
            'Test Event',
            NOW() + INTERVAL '30 days',
            false,
            test_user_id,
            NOW(),
            NOW()
        );
        
        RAISE NOTICE 'Test event created successfully for user: %', test_user_id;
    END IF;
END $$;

-- Show all events
SELECT 
    id,
    title,
    event_date,
    is_recurring,
    created_by,
    created_at,
    updated_at
FROM public.events;
