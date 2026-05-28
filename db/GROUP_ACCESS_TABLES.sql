-- Table for tracking group bans
CREATE TABLE group_bans (
    id UUID PRIMARY KEY,
    group_id UUID REFERENCES groups(id),
    user_id UUID REFERENCES users(id),
    banned_by UUID REFERENCES users(id),
    banned_at TIMESTAMP WITH TIME ZONE NOT NULL,
    reason TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    unbanned_by UUID REFERENCES users(id),
    unbanned_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(group_id, user_id, is_active)
);

-- Table for tracking group mutes
CREATE TABLE group_mutes (
    id UUID PRIMARY KEY,
    group_id UUID REFERENCES groups(id),
    user_id UUID REFERENCES users(id),
    muted_by UUID REFERENCES users(id),
    muted_at TIMESTAMP WITH TIME ZONE NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    reason TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    unmuted_by UUID REFERENCES users(id),
    unmuted_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(group_id, user_id, is_active)
);

-- Table for tracking message reads
CREATE TABLE message_reads (
    id UUID PRIMARY KEY,
    message_id TEXT NOT NULL, -- or UUID depending on your message ID format
    group_id UUID REFERENCES groups(id),
    user_id UUID REFERENCES users(id),
    read_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(message_id, user_id) -- Prevent duplicate read records
);

-- Add RLS policies for group_bans
ALTER TABLE group_bans ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Group admins can create bans"
    ON group_bans
    FOR INSERT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM groups
            WHERE id = group_id
            AND admin_ids @> ARRAY[auth.uid()]::uuid[]
        )
    );

CREATE POLICY "Group admins can update bans"
    ON group_bans
    FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM groups
            WHERE id = group_id
            AND admin_ids @> ARRAY[auth.uid()]::uuid[]
        )
    );

CREATE POLICY "Members can view bans"
    ON group_bans
    FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM groups
            WHERE id = group_id
            AND member_ids @> ARRAY[auth.uid()]::uuid[]
        )
    );

-- Add RLS policies for group_mutes
ALTER TABLE group_mutes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Group admins can create mutes"
    ON group_mutes
    FOR INSERT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM groups
            WHERE id = group_id
            AND admin_ids @> ARRAY[auth.uid()]::uuid[]
        )
    );

CREATE POLICY "Group admins can update mutes"
    ON group_mutes
    FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM groups
            WHERE id = group_id
            AND admin_ids @> ARRAY[auth.uid()]::uuid[]
        )
    );

CREATE POLICY "Members can view mutes"
    ON group_mutes
    FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM groups
            WHERE id = group_id
            AND member_ids @> ARRAY[auth.uid()]::uuid[]
        )
    );

-- Add RLS policies for message_reads
ALTER TABLE message_reads ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can record their own reads"
    ON message_reads
    FOR INSERT
    TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY "Group members can view reads"
    ON message_reads
    FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM groups
            WHERE id = group_id
            AND member_ids @> ARRAY[auth.uid()]::uuid[]
        )
    );

-- Indexes for performance
CREATE INDEX idx_group_bans_lookup ON group_bans(group_id, user_id, is_active);
CREATE INDEX idx_group_mutes_lookup ON group_mutes(group_id, user_id, is_active);
CREATE INDEX idx_group_mutes_expiry ON group_mutes(expires_at) WHERE is_active = TRUE;
CREATE INDEX idx_message_reads_lookup ON message_reads(message_id, user_id);
CREATE INDEX idx_message_reads_group ON message_reads(group_id);