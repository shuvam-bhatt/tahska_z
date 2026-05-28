-- Enable Row Level Security
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- Remove all policies
DROP POLICY IF EXISTS "Allow users to read messages from their groups" ON messages;
DROP POLICY IF EXISTS "Allow users to send messages in their groups" ON messages;
DROP POLICY IF EXISTS "Allow users to delete their own messages" ON messages;
DROP POLICY IF EXISTS "Allow HQ admins to delete any message" ON messages;

-- Policy for reading messages: Users can only read messages from groups they belong to
CREATE POLICY "Allow users to read messages from their groups" ON messages
FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM groups g
    WHERE g.id = messages.group_id 
    AND (
      auth.uid() = ANY(g.member_ids)
      OR auth.uid() = ANY(g.admin_ids)
      OR EXISTS (
        SELECT 1 FROM users u
        WHERE u.id = auth.uid()
        AND u.role = 'hq_admin'
      )
    )
  )
);

-- Policy for sending messages: Users can only send messages in groups they belong to
CREATE POLICY "Allow users to send messages in their groups" ON messages
FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1 FROM groups g
    WHERE g.id = messages.group_id 
    AND (
      auth.uid() = ANY(g.member_ids)
      OR auth.uid() = ANY(g.admin_ids)
    )
  )
  AND messages.sender_id = auth.uid()
);

-- Policy for deleting messages: Users can only delete their own messages
CREATE POLICY "Allow users to delete their own messages" ON messages
FOR DELETE USING (
  messages.sender_id = auth.uid()
);

-- Policy for HQ admins: Can delete any message
CREATE POLICY "Allow HQ admins to delete any message" ON messages
FOR DELETE USING (
  EXISTS (
    SELECT 1 FROM users u
    WHERE u.id = auth.uid()
    AND u.role = 'hq_admin'
  )
);