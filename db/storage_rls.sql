-- Enable Row Level Security for files storage
DROP POLICY IF EXISTS "Allow users to view files from their groups" ON storage.objects;
DROP POLICY IF EXISTS "Allow users to upload files to their groups" ON storage.objects;
DROP POLICY IF EXISTS "Allow users to delete their own files" ON storage.objects;
DROP POLICY IF EXISTS "Allow HQ admins to delete any file" ON storage.objects;

-- Policy for viewing files: Users can only view files from groups they belong to
CREATE POLICY "Allow users to view files from their groups" ON storage.objects
FOR SELECT USING (
  bucket_id = 'files'
  AND EXISTS (
    SELECT 1 FROM messages m
    JOIN groups g ON m.group_id = g.id
    WHERE m.file_url = storage.objects.name
    AND (
      auth.uid() = ANY(g.member_ids)
      OR auth.uid() = ANY(g.admin_ids)
      OR EXISTS (
        SELECT 1 FROM auth.users u
        WHERE u.id = auth.uid()
        AND u.role = 'hq_admin'
      )
    )
  )
);

-- Policy for uploading files: Users can only upload files to groups they belong to
CREATE POLICY "Allow users to upload files to their groups" ON storage.objects
FOR INSERT WITH CHECK (
  bucket_id = 'files'
  AND EXISTS (
    SELECT 1 FROM groups g
    WHERE g.id = (SELECT group_id FROM messages WHERE file_url = storage.objects.name LIMIT 1)
    AND (
      auth.uid() = ANY(g.member_ids)
      OR auth.uid() = ANY(g.admin_ids)
    )
  )
);

-- Policy for deleting files: Users can only delete their own files
CREATE POLICY "Allow users to delete their own files" ON storage.objects
FOR DELETE USING (
  bucket_id = 'files'
  AND EXISTS (
    SELECT 1 FROM messages m
    WHERE m.file_url = storage.objects.name
    AND m.sender_id = auth.uid()
  )
);

-- Policy for HQ admins: Can delete any file
CREATE POLICY "Allow HQ admins to delete any file" ON storage.objects
FOR DELETE USING (
  bucket_id = 'files'
  AND EXISTS (
    SELECT 1 FROM auth.users u
    WHERE u.id = auth.uid()
    AND u.role = 'hq_admin'
  )
);