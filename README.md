<p align="center">
  <h1 align="center">🛡️ Aegis</h1>
  <p align="center">
    <strong>Secure Closed-Group Communication for Indian Defense Personnel</strong>
  </p>
  <p align="center">
    End-to-end encrypted messaging · Role-based access control · Real-time collaboration
  </p>
</p>

---

## Overview

Aegis is a Flutter-based prototype for secure, closed-group communication designed for Indian defense personnel, veterans, and their families. All messages and files are **AES-256 encrypted client-side** before leaving the device, ensuring true end-to-end security over public networks.

Built for the **Smart India Hackathon (SIH) 2024**.

## Key Features

| Category | Features |
|---|---|
| **Encryption** | AES-256 text encryption, encrypted file uploads/downloads, secure key generation via `flutter_secure_storage` |
| **Containment** | Copy-paste prevention, text selection blocking, security warnings on violation attempts |
| **Messaging** | Real-time group chat via Supabase Realtime, encrypted file sharing (≤ 10 MB), message history with on-device decryption |
| **Access Control** | Three-tier role hierarchy (User → Group Admin → HQ Admin), invite-code-based group joining, join-request approval system |
| **Admin** | Group creation/deactivation, member management, ban/mute controls, system-wide oversight for HQ Admin |

## Architecture

### Tech Stack

| Layer | Technology |
|---|---|
| Frontend | Flutter (Dart) with Material Design 3 |
| Backend | [Supabase](https://supabase.com) (PostgreSQL + Auth + Realtime + Storage) |
| State Management | Provider |
| Encryption | `encrypt` (AES-256) + `crypto` |
| Secure Storage | `flutter_secure_storage` |

### Project Structure

```
lib/
├── main.dart                  # App entry point & theme
├── models/
│   ├── group.dart             # Group data model
│   ├── group_join_request.dart
│   ├── message.dart           # Message model with encryption flags
│   └── user.dart              # User model with role support
├── services/
│   ├── supabase_service.dart  # Supabase client wrapper
│   ├── auth_service.dart      # Authentication logic
│   ├── chat_service.dart      # Encrypted messaging & file sharing
│   └── group_service.dart     # Group CRUD & member management
├── providers/
│   ├── auth_provider.dart     # Auth state
│   ├── chat_provider.dart     # Chat state
│   └── group_provider.dart    # Group state
├── screens/
│   ├── splash_screen.dart
│   ├── login_screen.dart
│   ├── register_screen.dart
│   ├── home_screen.dart
│   ├── groups_screen.dart
│   ├── group_requests_screen.dart
│   ├── chat_screen.dart
│   ├── admin_screen.dart
│   └── profile_screen.dart
├── widgets/
│   ├── message_bubble.dart
│   └── file_picker_button.dart
└── utils/
    ├── encryption_utils.dart  # AES-256 encrypt/decrypt helpers
    └── containment_utils.dart # Screenshot & copy-paste prevention

db/                            # Supabase SQL scripts
├── groups_rls.sql             # Groups table RLS policies
├── messages_rls.sql           # Messages table RLS policies
├── storage_rls.sql            # Storage bucket RLS policies
├── FIX_GROUP_JOINING.sql      # Group joining fix + join requests table
├── GROUP_ACCESS_TABLES.sql    # Bans, mutes, message-read tracking
└── GROUP_JOIN_REQUESTS_TABLE.sql
```

## Prerequisites

- **Flutter SDK** ≥ 3.9.2
- **Dart SDK** (bundled with Flutter)
- A free **[Supabase](https://supabase.com)** account
- Android Studio / VS Code
- An Android device or emulator (recommended for full security features)

## Getting Started

### 1. Clone & Install

```bash
git clone https://github.com/<your-username>/aegis.git
cd aegis
flutter pub get
```

### 2. Set Up Supabase

1. Create a new project at [supabase.com](https://supabase.com) (name: `aegis`).
2. Go to **Settings → API** and copy your **Project URL** and **Anon Key**.
3. Update `lib/services/supabase_service.dart`:

```dart
static const String supabaseUrl = 'https://your-project.supabase.co';
static const String supabaseAnonKey = 'your-anon-key';
```

### 3. Create Database Tables

Open the **SQL Editor** in your Supabase dashboard and run:

```sql
-- Users table
CREATE TABLE users (
  id UUID REFERENCES auth.users(id) PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  role TEXT DEFAULT 'user' CHECK (role IN ('user', 'admin', 'hq_admin')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  group_ids UUID[] DEFAULT '{}'
);

-- Groups table
CREATE TABLE groups (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  invite_code TEXT UNIQUE NOT NULL,
  created_by UUID REFERENCES users(id) NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  member_ids UUID[] DEFAULT '{}',
  admin_ids UUID[] DEFAULT '{}',
  is_active BOOLEAN DEFAULT true
);

-- Messages table
CREATE TABLE messages (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  group_id UUID REFERENCES groups(id) NOT NULL,
  sender_id UUID REFERENCES users(id) NOT NULL,
  sender_name TEXT NOT NULL,
  content TEXT NOT NULL,            -- stored as AES-256 ciphertext
  type TEXT DEFAULT 'text' CHECK (type IN ('text', 'file', 'image')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  file_url TEXT,
  file_name TEXT,
  file_size INTEGER,
  is_encrypted BOOLEAN DEFAULT true
);

-- Enable Row Level Security
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view their own data" ON users FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update their own data" ON users FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Users can insert their own data" ON users FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can view groups they belong to" ON groups FOR SELECT USING (auth.uid() = ANY(member_ids));
CREATE POLICY "Admins can create groups" ON groups FOR INSERT WITH CHECK (auth.uid() = created_by);
CREATE POLICY "Group admins can update groups" ON groups FOR UPDATE USING (auth.uid() = ANY(admin_ids));

CREATE POLICY "Users can view messages in their groups" ON messages FOR SELECT USING (
  group_id IN (SELECT id FROM groups WHERE auth.uid() = ANY(member_ids))
);
CREATE POLICY "Users can send messages to their groups" ON messages FOR INSERT WITH CHECK (
  group_id IN (SELECT id FROM groups WHERE auth.uid() = ANY(member_ids))
);
```

> Additional SQL scripts for join requests, bans, mutes, and message reads are in the `db/` directory.

### 4. Configure Storage

1. Go to **Storage** in the Supabase dashboard.
2. Create a bucket named `files` (set to **public**).

### 5. Disable Email Confirmation (for demo)

Go to **Authentication → Settings → User Signups** and uncheck **Enable email confirmations**.

### 6. Run

```bash
flutter run            # default device
flutter run -d chrome  # web
```

## User Roles

| Role | Can Create Groups | Can Join Groups | Admin Panel |
|---|:---:|:---:|:---:|
| Defense Personnel / Veteran / Family | ✗ | ✓ (invite code) | ✗ |
| Group Admin | ✓ | ✓ | Limited |
| HQ Admin | ✓ | ✓ | Full |

## Security Model

```
┌──────────────┐     AES-256      ┌──────────────┐
│  User Device │ ──── encrypt ───▶│   Supabase   │
│  (plaintext) │                  │  (ciphertext) │
│              │ ◀── decrypt ──── │              │
└──────────────┘                  └──────────────┘
```

1. **Client-side encryption** — messages are AES-256 encrypted before leaving the device.
2. **Secure key storage** — encryption keys are stored in platform-specific secure storage (`flutter_secure_storage`).
3. **Row Level Security** — Supabase RLS policies ensure users can only access data from their own groups.
4. **Containment** — copy-paste prevention and text selection blocking reduce data leakage vectors.

## Supported Platforms

| Platform | Status | Notes |
|---|---|---|
| Android | ✅ Primary | Full security features |
| iOS | ✅ Supported | Full security features |
| Web | ⚠️ Partial | No screenshot blocking |
| Desktop | ⚠️ Partial | Limited containment features |

## Troubleshooting

| Problem | Solution |
|---|---|
| "Email not confirmed" error | Disable email confirmation in Supabase Auth settings |
| Supabase connection failed | Verify URL + Anon Key in `supabase_service.dart`; check internet |
| File upload fails | Ensure file ≤ 10 MB; verify `files` storage bucket exists |
| Screenshot blocking not working | Test on a **physical device** — emulators may not support `FLAG_SECURE` |
| Build errors | Run `flutter clean && flutter pub get && flutter run` |

## Future Roadmap

- [ ] WireGuard VPN integration
- [ ] Biometric authentication (fingerprint / face)
- [ ] Message self-destruction (timed auto-delete)
- [ ] Advanced audit logging & threat detection
- [ ] Push notifications

## License

This project was developed as a prototype for **SIH 2024** demonstration purposes.

---

<p align="center">
  Built with Flutter · Secured with AES-256 · Powered by Supabase
</p>
# tahska_z
