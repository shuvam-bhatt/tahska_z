-- Fix for Group Joining Issues
-- Run this in your Supabase SQL Editor

-- 1. Add the missing RLS policy for invite code lookups
CREATE POLICY "Users can view groups by invite code for joining" ON groups 
FOR SELECT USING (
  invite_code IS NOT NULL AND is_active = true
);

-- 2. Create group_join_requests table if it doesn't exist
CREATE TABLE IF NOT EXISTS group_join_requests (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  group_id UUID REFERENCES groups(id) NOT NULL,
  user_id UUID REFERENCES users(id) NOT NULL,
  user_name TEXT NOT NULL,
  user_email TEXT NOT NULL,
  user_role TEXT NOT NULL,
  request_message TEXT,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  requested_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  reviewed_by UUID REFERENCES users(id),
  reviewed_at TIMESTAMP WITH TIME ZONE,
  review_notes TEXT,
  UNIQUE(group_id, user_id) -- Prevent duplicate requests
);

-- 3. Enable RLS on group_join_requests table
ALTER TABLE group_join_requests ENABLE ROW LEVEL SECURITY;

-- 4. Create RLS policies for group_join_requests
CREATE POLICY "Users can view their own requests" ON group_join_requests 
FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Group admins can view requests for their groups" ON group_join_requests 
FOR SELECT USING (
  group_id IN (SELECT id FROM groups WHERE auth.uid() = ANY(admin_ids) OR auth.uid() = created_by)
);

CREATE POLICY "Users can create join requests" ON group_join_requests 
FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Group admins can update request status" ON group_join_requests 
FOR UPDATE USING (
  group_id IN (SELECT id FROM groups WHERE auth.uid() = ANY(admin_ids) OR auth.uid() = created_by)
);

-- 5. Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_group_join_requests_group_id ON group_join_requests(group_id);
CREATE INDEX IF NOT EXISTS idx_group_join_requests_user_id ON group_join_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_group_join_requests_status ON group_join_requests(status);
CREATE INDEX IF NOT EXISTS idx_groups_invite_code ON groups(invite_code);

-- 6. Test the fix by checking if invite codes are accessible
-- This should return all groups with invite codes (for testing)
SELECT id, name, invite_code, is_active FROM groups WHERE invite_code IS NOT NULL;

