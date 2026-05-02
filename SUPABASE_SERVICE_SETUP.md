# Supabase Service Setup Guide for Beat That

## Overview

The `SupabaseService` is a singleton service class that handles all Supabase operations for the Beat That app. It provides a clean, organized interface for:
- Uploading videos and thumbnails to storage
- Creating database records that link videos to thumbnails
- Retrieving user videos with full URLs
- Updating video metadata
- Deleting videos and their files
- Managing user profiles

## Architecture

### Storage Structure

```
Supabase Storage
├── videos bucket
│   └── {user_id}/
│       ├── video_1704067200000.mp4
│       ├── video_1704067300000.mp4
│       └── ...
├── thumbnails bucket
│   └── {user_id}/
│       ├── video_1704067200000_thumb.jpg
│       ├── video_1704067300000_thumb.jpg
│       └── ...
└── avatars bucket
    └── {user_id}/
        └── profile_picture.jpg
```

### Database Schema

**videos table:**
```sql
CREATE TABLE videos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title VARCHAR(255) NOT NULL,
  description TEXT,
  video_url TEXT NOT NULL,  -- Path like: videos/{user_id}/video_1704067200000.mp4
  thumbnail_url TEXT NOT NULL,  -- Path like: thumbnails/{user_id}/video_1704067200000_thumb.jpg
  view_count INT DEFAULT 0,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

ALTER TABLE videos ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view all videos (public)
CREATE POLICY "Videos are publicly readable"
  ON videos FOR SELECT USING (true);

-- Policy: Users can only edit their own videos
CREATE POLICY "Users can only edit their own videos"
  ON videos FOR UPDATE USING (auth.uid() = user_id);

-- Policy: Users can only delete their own videos
CREATE POLICY "Users can only delete their own videos"
  ON videos FOR DELETE USING (auth.uid() = user_id);

-- Policy: Authenticated users can insert videos
CREATE POLICY "Authenticated users can insert videos"
  ON videos FOR INSERT WITH CHECK (auth.uid() = user_id);
```

**profiles table:**
```sql
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name VARCHAR(255),
  email VARCHAR(255),
  bio TEXT,
  avatar_url TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view their own profile
CREATE POLICY "Users can view own profile"
  ON profiles FOR SELECT USING (auth.uid() = id);

-- Policy: Users can update their own profile
CREATE POLICY "Users can update own profile"
  ON profiles FOR UPDATE USING (auth.uid() = id);
```

## Setup Steps

### 1. Create Supabase Buckets

Go to Supabase Dashboard → Storage → Buckets and create these 3 buckets:

**Bucket 1: videos**
- Make it **Public** (so users can access video URLs)
- This stores all user video files

**Bucket 2: thumbnails**
- Make it **Public** (so users can access thumbnail URLs)
- This stores all video thumbnail files

**Bucket 3: avatars**
- Make it **Public**
- This stores all user profile pictures

### 2. Create Database Tables

Go to Supabase Dashboard → SQL Editor and run the SQL scripts above to create:
- `videos` table
- `profiles` table

### 3. Set Row Level Security (RLS)

Create the security policies (included in SQL above) so that:
- Users can only edit/delete their own videos
- Users can read all videos (public feed)
- Users can only access their own profile

### 4. Enable Data API Access

In Supabase Dashboard → Data API Integrations:
1. Make sure `videos` and `profiles` tables are exposed
2. Grant permissions:
   ```sql
   grant select on public.videos to anon;
   grant select,insert,update,delete on public.videos to authenticated;
   grant all on public.videos to service_role;
   
   grant select on public.profiles to anon;
   grant select,insert,update on public.profiles to authenticated;
   grant all on public.profiles to service_role;
   ```

## Usage Examples

### Initialize the Service

In your `main.dart`:
```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:beat_that/service_locator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase FIRST
  await Supabase.initialize(
    url: 'YOUR_SUPABASE_URL',
    anonKey: 'YOUR_ANON_KEY',
  );
  
  // Initialize async services (PreferencesService, etc.)
  final preferencesService = await initializeAsyncServices();
  
  // Setup the service locator with all services
  setupServiceLocator(preferencesService);
  
  runApp(const MyApp());
}
```

### Upload Video with Thumbnail

```dart
final supabaseService = locator<SupabaseService>();

final result = await supabaseService.uploadVideoWithThumbnail(
  videoFile: File('/path/to/video.mp4'),
  thumbnailFile: File('/path/to/thumbnail.jpg'),
  title: 'My Awesome Video',
  description: 'This is my first video!',
);

if (result['success']) {
  print('Video uploaded!');
  print('Video ID: ${result['videoId']}');
  print('Video URL: ${result['videoUrl']}');
  print('Thumbnail URL: ${result['thumbnailUrl']}');
} else {
  print('Error: ${result['message']}');
}
```

### Get All User Videos

```dart
final supabaseService = locator<SupabaseService>();

final videos = await supabaseService.getUserVideos();

for (var video in videos) {
  print('Title: ${video['title']}');
  print('Views: ${video['view_count']}');
  print('Thumbnail: ${video['thumbnail_url']}');
  print('Video: ${video['video_url']}');
}
```

### Get Video Thumbnails (Optimized for ListView)

```dart
final supabaseService = locator<SupabaseService>();

// Fetch just thumbnails for lightweight display
final thumbnails = await supabaseService.getVideoThumbnails();

for (var thumbnail in thumbnails) {
  print('Title: ${thumbnail['title']}');
  print('Thumbnail: ${thumbnail['thumbnail_url']}');
}
```

### Update Video Metadata

```dart
final supabaseService = locator<SupabaseService>();

final success = await supabaseService.updateVideo(
  videoId: 'video-id-here',
  title: 'Updated Title',
  description: 'Updated description',
);
```

### Delete a Video

```dart
final supabaseService = locator<SupabaseService>();

final success = await supabaseService.deleteVideo(
  videoId: 'video-id-here',
  videoPath: 'videos/{user_id}/video_1704067200000.mp4',
  thumbnailPath: 'thumbnails/{user_id}/video_1704067200000_thumb.jpg',
);
```

### Update User Profile

```dart
final supabaseService = locator<SupabaseService>();

await supabaseService.updateUserProfile(
  fullName: 'John Doe',
  bio: 'Content creator and dancer',
  avatarUrl: 'https://...',
);
```

### Get User Profile

```dart
final supabaseService = locator<SupabaseService>();

final profile = await supabaseService.getUserProfile();
if (profile != null) {
  print('Name: ${profile['full_name']}');
  print('Bio: ${profile['bio']}');
}
```

### Listen to Auth State Changes

```dart
final supabaseService = locator<SupabaseService>();

supabaseService.onAuthStateChange.listen((data) {
  final event = data.event;
  
  if (event == AuthChangeEvent.signedIn) {
    print('User signed in: ${data.session?.user.email}');
  } else if (event == AuthChangeEvent.signedOut) {
    print('User signed out');
  }
});
```

## Integration with Your Screens

### In Your Video Upload Screen

```dart
class VideoUploadScreen extends StatelessWidget {
  void uploadVideo(BuildContext context) async {
    final supabaseService = locator<SupabaseService>();
    
    final result = await supabaseService.uploadVideoWithThumbnail(
      videoFile: selectedVideoFile,
      thumbnailFile: generatedThumbnailFile,
      title: titleController.text,
      description: descriptionController.text,
    );
    
    if (result['success']) {
      // Show success message
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video uploaded successfully!')),
      );
      
      // Navigate to video or refresh feed
      if (!context.mounted) return;
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Your UI...
  }
}
```

### In Your Video Feed Screen (Fetch Thumbnails)

```dart
class VideoFeedScreen extends StatefulWidget {
  @override
  State<VideoFeedScreen> createState() => _VideoFeedScreenState();
}

class _VideoFeedScreenState extends State<VideoFeedScreen> {
  late Future<List<Map<String, dynamic>>> thumbnailsFuture;

  @override
  void initState() {
    super.initState();
    // Fetch thumbnails on load
    thumbnailsFuture = locator<SupabaseService>().getVideoThumbnails();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: thumbnailsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No videos yet'));
        }

        final thumbnails = snapshot.data!;
        
        return ListView.builder(
          itemCount: thumbnails.length,
          itemBuilder: (context, index) {
            final thumbnail = thumbnails[index];
            return GestureDetector(
              onTap: () async {
                // Fetch full video when user taps thumbnail
                final video = await locator<SupabaseService>()
                    .getVideoById(thumbnail['id']);
                
                if (video != null && mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => VideoPlayerScreen(
                        videoId: video['id'],
                        videoUrl: video['video_url'],
                        title: video['title'],
                      ),
                    ),
                  );
                }
              },
              child: VideoCard(
                title: thumbnail['title'],
                thumbnail: thumbnail['thumbnail_url'],
                views: thumbnail['view_count'],
              ),
            );
          },
        );
      },
    );
  }
}
```

## CRUD Operations Summary

| Operation | Method | Description |
|-----------|--------|-------------|
| Create | `uploadVideoWithThumbnail()` | Upload video + thumbnail + create DB record |
| Read | `getUserVideos()` | Get all user's videos |
| Read | `getVideoById()` | Get specific video |
| Read | `getUserProfile()` | Get user profile |
| Update | `updateVideo()` | Update video title/description |
| Update | `updateUserProfile()` | Update user profile |
| Update | `incrementViewCount()` | Increment view counter |
| Delete | `deleteVideo()` | Delete video, thumbnail, and DB record |

## File Structure

```
lib/
├── services/
│   ├── supabase_service.dart  ← Service class (video/thumbnail operations)
│   ├── auth_service.dart
│   ├── theme_service.dart
│   └── ...
├── service_locator.dart  ← Register all services here
├── screens/
│   ├── video_upload/
│   ├── video_feed/
│   └── ...
└── main.dart  ← Initialize Supabase and service locator here
```

Access the service anywhere:
```dart
final supabaseService = locator<SupabaseService>();
```

## Best Practices

1. **Always check authentication**: Use `isAuthenticated()` before operations
2. **Handle errors gracefully**: All methods have try-catch and return error info
3. **Use singleton pattern**: Access via `SupabaseService()` everywhere
4. **Lazy load data**: Use FutureBuilder for videos instead of loading all at once
5. **Optimize storage paths**: Include user_id in paths for better security
6. **Set RLS policies**: Never rely on client-side checks for security

## Troubleshooting

**Q: Upload fails with "permission denied"**
A: Check that buckets are public and RLS policies are set correctly

**Q: Videos show but no thumbnails**
A: Make sure thumbnails bucket is public and paths are correct

**Q: Can't query videos**
A: Enable Data API access for videos table and set grant permissions

**Q: Duplicate videos appearing**
A: Check that you're not calling upload multiple times
