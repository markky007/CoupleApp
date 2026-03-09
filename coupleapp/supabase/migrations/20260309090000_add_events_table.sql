-- Migration: Add events table for special dates and occasions
-- Created: 2026-03-09

-- Create events table
CREATE TABLE IF NOT EXISTS public.events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL CHECK (length(title) >= 1 AND length(title) <= 100),
    event_date TIMESTAMPTZ NOT NULL,
    is_recurring BOOLEAN NOT NULL DEFAULT false,
    created_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Create indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_events_created_by ON public.events(created_by);
CREATE INDEX IF NOT EXISTS idx_events_event_date ON public.events(event_date);

-- Enable Row Level Security
ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Users can view events created by themselves or their partner
DROP POLICY IF EXISTS "Users can view accessible events" ON public.events;
CREATE POLICY "Users can view accessible events"
    ON public.events
    FOR SELECT
    USING (
        created_by = auth.uid()
        OR
        created_by IN (
            SELECT partner_id 
            FROM public.profiles 
            WHERE id = auth.uid() AND partner_id IS NOT NULL
        )
    );

-- RLS Policy: Users can create their own events
DROP POLICY IF EXISTS "Users can create events" ON public.events;
CREATE POLICY "Users can create events"
    ON public.events
    FOR INSERT
    WITH CHECK (created_by = auth.uid());

-- RLS Policy: Users can update their own events
DROP POLICY IF EXISTS "Users can update own events" ON public.events;
CREATE POLICY "Users can update own events"
    ON public.events
    FOR UPDATE
    USING (created_by = auth.uid())
    WITH CHECK (created_by = auth.uid());

-- RLS Policy: Users can delete their own events
DROP POLICY IF EXISTS "Users can delete own events" ON public.events;
CREATE POLICY "Users can delete own events"
    ON public.events
    FOR DELETE
    USING (created_by = auth.uid());

-- Add comment to table
COMMENT ON TABLE public.events IS 'Special dates and occasions with countdown and notification support';
