# Supabase Integration Guide for Beat That

## Overview
Supabase is an open-source Firebase alternative that provides:
- **Authentication** - User login/signup with multiple methods
- **Database** - PostgreSQL for storing user data
- **Storage** - S3-compatible file storage for images and videos

This guide explains how to integrate these three components to manage user profiles, videos, and thumbnails.

---

## 1. AUTHENTICATION

### How It Works
Supabase Auth uses **JSON Web Tokens (JWTs)** for authentication. When a user logs in, they receive a token that proves their identity and is automatically attached to all database requests.

### Features
- **Email/Password authentication**
- **Magic Links** (passwordless)
- **Social Login** (Google, Apple, GitHub, Discord, etc.)
- **Phone Login** (SMS-based)
- **Row Level Security (RLS)** - Database rows are automatically scoped to the authenticated user

### For Flutter
You'll use the `supabase_flutter` package:
```dart
// Initialize Supabase
await Supabase.initialize(
  url: 'YOUR_SUPABASE_URL',
  anonKey: 'YOUR_ANON_KEY',
);

// Sign up
await supabase.auth.signUp(
  email: email,
  password: password,
);

// Sign in
await supabase.auth.signInWithPassword(
  email: email,
  password: password,
);

// Get current user
final user = supabase.auth.currentUser;
```

---

## 2. STORAGE

### How It Works
Files (images, videos, etc.) are stored in **Buckets**, which are like "super folders". Each bucket can have security policies that control who can upload/download files.

### Structure
- **Buckets** - Top-level containers (e.g., "videos", "avatars", "thumbnails")
- **Folders** - Organize files (e.g., "videos/{user_id}/")
- **Files** - Actual media files

### Recommended Bucket Structure for Beat That
```
videos/
  {user_id}/
    video_1.mp4
    video_2.mp4

thumbnails/
  {user_id}/
    video_1_thumb.jpg
    video_2_thumb.jpg

avatars/
  {user_id}/
    profile_picture.jpg
```

### For Flutter
```dart
// Upload a file
await supabase.storage
  .from('videos')
  .upload(
    '${userId}/video_${timestamp}.mp4',
    File(videoPath),
  );

// Get public URL
final url = supabase.storage
  .from('videos')
  .getPublicUrl('${userId}/video_1.mp4');

// Delete a file
await supabase.storage
  .from('videos')
  .remove(['${userId}/video_1.mp4']);
```

---

## 3. DATABASE - User Profiles

### What is It?
Supabase comes with a full **PostgreSQL database**. You create tables like a spreadsheet to store user information.

### Recommended Schema for Beat That

#### Users Table (Auto-created by Supabase Auth)
```sql
-- Supabase automatically creates this when you sign up a user
-- It has: id (UUID), email, created_at, etc.
```

#### Profiles Table (You create this)
```sql
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name VARCHAR(255),
  email VARCHAR(255),
  avatar_url TEXT,  -- URL to the profile picture in storage
  bio TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see their own profile
CREATE POLICY "Users can view their own profile"
  ON profiles FOR SELECT
  USING (auth.uid() = id);

-- Policy: Users can update their own profile
CREATE POLICY "Users can update their own profile"
  ON profiles FOR UPDATE
  USING (auth.uid() = id);
```

#### Videos Table (You create this)
```sql
CREATE TABLE videos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title VARCHAR(255),
  description TEXT,
  video_url TEXT NOT NULL,  -- Path in storage: videos/{user_id}/...
  thumbnail_url TEXT,       -- Path in storage: thumbnails/{user_id}/...
  duration_seconds INT,
  view_count INT DEFAULT 0,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE videos ENABLE ROW LEVEL SECURITY;

-- Policy: Users can see all videos (public)
CREATE POLICY "Videos are publicly readable"
  ON videos FOR SELECT
  USING (true);

-- Policy: Users can only edit their own videos
CREATE POLICY "Users can only edit their own videos"
  ON videos FOR UPDATE
  USING (auth.uid() = user_id);

-- Policy: Users can only delete their own videos
CREATE POLICY "Users can only delete their own videos"
  ON videos FOR DELETE
  USING (auth.uid() = user_id);
```

---

## 4. HOW IT ALL WORKS TOGETHER

### User Registration Flow
```
1. User enters email + password in Flutter app
2. Supabase Auth creates user in auth.users table
3. Trigger automatically creates empty record in profiles table
4. User can upload profile picture → stored in avatars bucket
5. Profile table updated with avatar_url
```

### Video Upload Flow
```
1. User selects video in app
2. Generate thumbnail from video
3. Upload video file → Storage (videos/{user_id}/)
4. Upload thumbnail file → Storage (thumbnails/{user_id}/)
5. Create row in videos table with:
   - user_id (current logged-in user)
   - video_url (path to video in storage)
   - thumbnail_url (path to thumbnail in storage)
   - title, description, etc.
```

### Data Retrieval Flow
```
1. User's profile info → Query profiles table (filtered by user_id)
2. User's videos → Query videos table WHERE user_id = current_user
3. Video files → Download from Storage using video_url
4. Thumbnail files → Download from Storage using thumbnail_url
```

---

## 5. EXAMPLE FLUTTER CODE

### Setup
```dart
import 'package:supabase_flutter/supabase_flutter.dart';

// In main.dart
await Supabase.initialize(
  url: 'https://your-project.supabase.co',
  anonKey: 'your-anon-key',
);

final supabase = Supabase.instance.client;
```

### Create User Profile
```dart
Future<void> createUserProfile(String fullName, String email) async {
  final userId = supabase.auth.currentUser?.id;
  
  await supabase.from('profiles').insert({
    'id': userId,
    'full_name': fullName,
    'email': email,
  });
}
```

### Fetch User Profile
```dart
Future<Map<String, dynamic>> getUserProfile() async {
  final userId = supabase.auth.currentUser?.id;
  
  final response = await supabase
    .from('profiles')
    .select()
    .eq('id', userId)
    .single();
  
  return response;
}
```

### Upload Profile Picture
```dart
Future<String> uploadProfilePicture(File imageFile) async {
  final userId = supabase.auth.currentUser?.id;
  final fileName = '$userId/profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
  
  await supabase.storage
    .from('avatars')
    .upload(fileName, imageFile);
  
  final url = supabase.storage
    .from('avatars')
    .getPublicUrl(fileName);
  
  // Update profile with avatar URL
  await supabase
    .from('profiles')
    .update({'avatar_url': url})
    .eq('id', userId);
  
  return url;
}
```

### Upload Video & Thumbnail
```dart
Future<void> uploadVideo({
  required File videoFile,
  required File thumbnailFile,
  required String title,
  required String description,
}) async {
  final userId = supabase.auth.currentUser?.id;
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  
  // Upload video
  final videoPath = '$userId/video_$timestamp.mp4';
  await supabase.storage.from('videos').upload(videoPath, videoFile);
  
  // Upload thumbnail
  final thumbPath = '$userId/video_${timestamp}_thumb.jpg';
  await supabase.storage.from('thumbnails').upload(thumbPath, thumbnailFile);
  
  // Create database record
  await supabase.from('videos').insert({
    'user_id': userId,
    'title': title,
    'description': description,
    'video_url': videoPath,
    'thumbnail_url': thumbPath,
  });
}
```

### Fetch User's Videos
```dart
Future<List<Map<String, dynamic>>> getUserVideos() async {
  final userId = supabase.auth.currentUser?.id;
  
  final videos = await supabase
    .from('videos')
    .select()
    .eq('user_id', userId);
  
  // Convert paths to public URLs
  return videos.map((video) {
    return {
      ...video,
      'video_url': supabase.storage.from('videos').getPublicUrl(video['video_url']),
      'thumbnail_url': supabase.storage.from('thumbnails').getPublicUrl(video['thumbnail_url']),
    };
  }).toList();
}
```

---

## 6. KEY CONCEPTS

### Row Level Security (RLS)
- Automatically filters database queries based on the authenticated user
- Example: A user can only see/edit their own videos
- Enforced at the database level (more secure than client-side checks)

### Buckets
- Think of them as "super folders" for files
- Each bucket can have different security policies
- S3-compatible API (can use standard S3 libraries)

### Foreign Keys
- Link data between tables (e.g., videos.user_id → auth.users.id)
- Ensures data integrity
- ON DELETE CASCADE = delete videos when user is deleted

### Triggers (Advanced)
- Automatically create a profiles record when user signs up
```sql
CREATE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, email)
  VALUES (new.id, new.email);
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
```

---

## 7. GETTING STARTED

1. **Create Supabase Project**
   - Go to https://supabase.com/dashboard
   - Create new project
   - Wait for database to initialize
   - Copy Project URL and Anon Key

2. **Add Supabase to Flutter**
   ```bash
   flutter pub add supabase_flutter
   ```

3. **Create Tables**
   - Go to SQL Editor in Supabase Dashboard
   - Run the SQL scripts above for profiles and videos tables

4. **Enable Storage**
   - Go to Storage in Dashboard
   - Create buckets: "videos", "thumbnails", "avatars"

5. **Set Up Row Level Security**
   - Go to Authentication → Policies
   - Add policies from the SQL scripts above

6. **Integrate into Your Flutter App**
   - Initialize Supabase in main.dart
   - Use the code examples above

---

## 8. ADVANTAGES

✅ **Built-in Authentication** - No need for Firebase or Auth0
✅ **File Storage** - No need for separate AWS S3 setup
✅ **Database** - Full PostgreSQL power
✅ **Row Level Security** - Automatic data filtering per user
✅ **Real-time Subscriptions** - Watch database changes in real-time
✅ **REST API** - Auto-generated endpoints
✅ **Affordable** - Free tier available
✅ **Open Source** - Self-hostable

---

## 9. NEXT STEPS

1. Research the `supabase_flutter` package documentation
2. Set up a Supabase project
3. Create the database tables
4. Test authentication flow
5. Implement file upload/download
6. Build the profile management screens
7. Implement video upload with thumbnail generation

