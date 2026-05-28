-- Enable Row Level Security
ALTER TABLE groups ENABLE ROW LEVEL SECURITY;

-- Remove all policies
DROP POLICY IF EXISTS "Allow users to view their groups" ON groups;
DROP POLICY IF EXISTS "Allow HQ admins to create groups" ON groups;
DROP POLICY IF EXISTS "Allow admins to update their groups" ON groups;
DROP POLICY IF EXISTS "Allow HQ admins to update any group" ON groups;
DROP POLICY IF EXISTS "Allow HQ admins to delete groups" ON groups;

-- Policy for reading: Users can only view groups they belong to or HQ admins can view all
CREATE POLICY "Allow users to view their groups" ON groups
FOR SELECT USING (
  auth.uid() = ANY(member_ids)
  OR auth.uid() = ANY(admin_ids)
  OR EXISTS (
    SELECT 1 FROM users u
    WHERE u.id = auth.uid()
    AND u.role = 'hq_admin'
  )
);

-- Policy for creation: Only HQ admins can create groups
CREATE POLICY "Allow HQ admins to create groups" ON groups
FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1 FROM users u
    WHERE u.id = auth.uid()
    AND u.role = 'hq_admin'
  )
  AND created_by = auth.uid()
);

-- Policy for updates: Group admins can update their own groups
CREATE POLICY "Allow admins to update their groups" ON groups
FOR UPDATE USING (
  auth.uid() = ANY(admin_ids)
);

-- Policy for updates: HQ admins can update any group
CREATE POLICY "Allow HQ admins to update any group" ON groups
FOR UPDATE USING (
  EXISTS (
    SELECT 1 FROM users u
    WHERE u.id = auth.uid()
    AND u.role = 'hq_admin'
  )
);

-- Policy for deletion: Only HQ admins can delete groups
CREATE POLICY "Allow HQ admins to delete groups" ON groups
FOR DELETE USING (
  EXISTS (
    SELECT 1 FROM users u
    WHERE u.id = auth.uid()
    AND u.role = 'hq_admin'
  )
);