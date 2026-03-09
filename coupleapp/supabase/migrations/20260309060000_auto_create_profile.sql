-- ============================================================================
-- Auto-create Profile on User Signup
-- ============================================================================
-- This migration adds a trigger to automatically create a profile record
-- when a new user signs up via Supabase Auth
-- ============================================================================

-- Function to create profile for new user
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, display_name, total_points)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'display_name', split_part(NEW.email, '@', 1)),
    0
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to call the function when a new user is created
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- ============================================================================
-- Backfill existing users without profiles
-- ============================================================================

-- Create profiles for any existing users that don't have one
INSERT INTO public.profiles (id, display_name, total_points)
SELECT 
  u.id,
  COALESCE(u.raw_user_meta_data->>'display_name', split_part(u.email, '@', 1)),
  0
FROM auth.users u
LEFT JOIN public.profiles p ON u.id = p.id
WHERE p.id IS NULL
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- Verification
-- ============================================================================

DO $$
DECLARE
  user_count INTEGER;
  profile_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO user_count FROM auth.users;
  SELECT COUNT(*) INTO profile_count FROM public.profiles;
  
  RAISE NOTICE 'Users: %, Profiles: %', user_count, profile_count;
  
  IF user_count != profile_count THEN
    RAISE WARNING 'Mismatch: % users but % profiles', user_count, profile_count;
  ELSE
    RAISE NOTICE 'All users have profiles ✓';
  END IF;
END $$;
