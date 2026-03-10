-- ============================================================================
-- Additional Features Enhancement Migration
-- ============================================================================
-- This migration adds support for partner pairing, profile pictures,
-- theme preferences, and localization preferences
-- ============================================================================

-- Add new columns to profiles table
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS username TEXT,
ADD COLUMN IF NOT EXISTS partner_code TEXT UNIQUE,
ADD COLUMN IF NOT EXISTS profile_picture_url TEXT,
ADD COLUMN IF NOT EXISTS theme_preference TEXT DEFAULT 'system' CHECK (theme_preference IN ('light', 'dark', 'system')),
ADD COLUMN IF NOT EXISTS language_preference TEXT DEFAULT 'en' CHECK (language_preference IN ('en', 'th'));

-- Add constraints
ALTER TABLE profiles
ADD CONSTRAINT username_length CHECK (char_length(username) >= 1 AND char_length(username) <= 50),
ADD CONSTRAINT partner_code_format CHECK (partner_code ~ '^[A-Z0-9]{6,8}$');

-- Create index for partner code lookups
CREATE INDEX IF NOT EXISTS idx_profiles_partner_code ON profiles(partner_code) WHERE partner_code IS NOT NULL;

-- Create index for username searches
CREATE INDEX IF NOT EXISTS idx_profiles_username ON profiles(username) WHERE username IS NOT NULL;

-- ============================================================================
-- Pairing Requests Table
-- ============================================================================

CREATE TABLE IF NOT EXISTS pairing_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  requester_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  recipient_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

  -- Constraints
  CONSTRAINT different_users CHECK (requester_id != recipient_id),
  CONSTRAINT unique_pending_request UNIQUE (requester_id, recipient_id, status)
);

-- Indexes for pairing requests
CREATE INDEX IF NOT EXISTS idx_pairing_requests_requester ON pairing_requests(requester_id);
CREATE INDEX IF NOT EXISTS idx_pairing_requests_recipient ON pairing_requests(recipient_id);
CREATE INDEX IF NOT EXISTS idx_pairing_requests_status ON pairing_requests(status);
CREATE INDEX IF NOT EXISTS idx_pairing_requests_created_at ON pairing_requests(created_at);

-- Trigger to update updated_at on pairing_requests
CREATE TRIGGER update_pairing_requests_updated_at
  BEFORE UPDATE ON pairing_requests
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- Functions
-- ============================================================================

-- Function to generate unique partner code
CREATE OR REPLACE FUNCTION generate_partner_code()
RETURNS TEXT AS $$
DECLARE
  code TEXT;
  exists BOOLEAN;
BEGIN
  LOOP
    -- Generate random 8-character alphanumeric code
    code := upper(substring(md5(random()::text) from 1 for 8));

    -- Check if code already exists
    SELECT EXISTS(SELECT 1 FROM profiles WHERE partner_code = code) INTO exists;

    EXIT WHEN NOT exists;
  END LOOP;

  RETURN code;
END;
$$ LANGUAGE plpgsql;

-- Function to clean up old pairing requests (older than 7 days)
CREATE OR REPLACE FUNCTION cleanup_old_pairing_requests()
RETURNS void AS $$
BEGIN
  DELETE FROM pairing_requests
  WHERE status = 'pending'
  AND created_at < NOW() - INTERVAL '7 days';
END;
$$ LANGUAGE plpgsql;

-- Function to accept pairing request (atomic operation)
CREATE OR REPLACE FUNCTION accept_pairing_request(request_id UUID)
RETURNS void AS $$
DECLARE
  req_record RECORD;
BEGIN
  -- Get request details
  SELECT requester_id, recipient_id, status
  INTO req_record
  FROM pairing_requests
  WHERE id = request_id;

  -- Validate request exists and is pending
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Pairing request not found';
  END IF;

  IF req_record.status != 'pending' THEN
    RAISE EXCEPTION 'Pairing request is not pending';
  END IF;

  -- Check if either user is already paired
  IF EXISTS(SELECT 1 FROM profiles WHERE id = req_record.requester_id AND partner_id IS NOT NULL) THEN
    RAISE EXCEPTION 'Requester is already paired';
  END IF;

  IF EXISTS(SELECT 1 FROM profiles WHERE id = req_record.recipient_id AND partner_id IS NOT NULL) THEN
    RAISE EXCEPTION 'Recipient is already paired';
  END IF;

  -- Update both profiles (bidirectional)
  UPDATE profiles
  SET partner_id = req_record.recipient_id, updated_at = NOW()
  WHERE id = req_record.requester_id;

  UPDATE profiles
  SET partner_id = req_record.requester_id, updated_at = NOW()
  WHERE id = req_record.recipient_id;

  -- Update request status
  UPDATE pairing_requests
  SET status = 'accepted', updated_at = NOW()
  WHERE id = request_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- Row Level Security Policies
-- ============================================================================

-- Enable RLS on pairing_requests
ALTER TABLE pairing_requests ENABLE ROW LEVEL SECURITY;

-- Users can view requests where they are requester or recipient
CREATE POLICY "Users can view own pairing requests"
  ON pairing_requests FOR SELECT
  USING (
    auth.uid() = requester_id OR
    auth.uid() = recipient_id
  );

-- Users can create pairing requests
CREATE POLICY "Users can create pairing requests"
  ON pairing_requests FOR INSERT
  WITH CHECK (auth.uid() = requester_id);

-- Users can update requests where they are recipient (for accept/reject)
CREATE POLICY "Recipients can update pairing requests"
  ON pairing_requests FOR UPDATE
  USING (auth.uid() = recipient_id)
  WITH CHECK (auth.uid() = recipient_id);

-- Users can delete their own sent requests
CREATE POLICY "Requesters can delete own requests"
  ON pairing_requests FOR DELETE
  USING (auth.uid() = requester_id);

-- ============================================================================
-- Storage Bucket for Profile Pictures
-- ============================================================================

-- Note: Storage bucket creation must be done via Supabase Dashboard or API
-- Bucket name: profile-pictures
-- Configuration:
--   - Public: false
--   - File size limit: 5MB
--   - Allowed MIME types: image/jpeg, image/png
--
-- Storage policies to create in Supabase Dashboard:
-- 1. Users can upload to their own folder: profile-pictures/{user_id}/*
--    Policy: INSERT with check: bucket_id = 'profile-pictures' AND (storage.foldername(name))[1] = auth.uid()::text
-- 2. Users can view their own and their partner's profile pictures
--    Policy: SELECT with check: bucket_id = 'profile-pictures' AND (
--      (storage.foldername(name))[1] = auth.uid()::text OR
--      (storage.foldername(name))[1] IN (SELECT partner_id::text FROM profiles WHERE id = auth.uid())
--    )
-- 3. Users can delete their own profile pictures
--    Policy: DELETE with check: bucket_id = 'profile-pictures' AND (storage.foldername(name))[1] = auth.uid()::text
