# GoRouter Navigation Setup Guide

## Overview

This document explains how the GoRouter navigation system is set up in your Flutter app with authentication-based route handling.

## Architecture

### 1. **AppRouter** (`lib/routes/app_router.dart`)
The centralized routing configuration that manages:
- Route definitions
- Authentication-based redirects
- Initial route loading

### 2. **Routes Defined**

| Route | Path | Purpose |
|-------|------|---------|
| Login | `/login` | User login screen |
| Signup | `/signup` | User registration screen |
| Home | `/home` | Main app screen (protected) |

### 3. **Authentication Flow**

```
App Start
   ↓
Supabase Initialized
   ↓
MyApp Widget Created
   ↓
AuthService Initialized
   ↓
AppRouter Configured with Redirect Logic
   ↓
Listen to Auth State Changes
   ↓
Redirect Logic Applies:
   - If Logged In + Accessing Auth Routes → Redirect to /home
   - If Not Logged In + Accessing Protected Routes → Redirect to /login
   - Otherwise → Allow Navigation
```

## How It Works

### Initial App Load

1. **App Starts** → `main.dart`
2. **Supabase Initialized** with your credentials
3. **MyApp Widget Created** as a `StatefulWidget`
4. **AuthService Created** to manage authentication
5. **AppRouter Created** with authentication state management
6. **Auth State Listener** set up to trigger redirects on auth changes

### Redirect Logic

The `redirect` function in `AppRouter` runs on every navigation attempt:

```dart
redirect: (BuildContext context, GoRouterState state) {
  final isLoggedIn = authService.isLoggedIn();
  final isAuthRoute = state.fullPath == '/login' || state.fullPath == '/signup';
  
  if (!isLoggedIn && !isAuthRoute) {
    return '/login'; // Not logged in, trying to access protected route
  }
  if (isLoggedIn && isAuthRoute) {
    return '/home'; // Logged in, trying to access auth screen
  }
  return null; // No redirect needed
}
```

### Navigation Examples

#### Navigate to Home (from anywhere)
```dart
context.go('/home');
```

#### Navigate to Login
```dart
context.go('/login');
```

#### Navigate to Signup
```dart
context.go('/signup');
```

#### Named Navigation (optional)
```dart
context.goNamed('home'); // Uses route name instead of path
```

## User Flows

### New User (Not Logged In)

```
App Opens
   ↓
Redirect Logic Checks Auth State
   ↓
Not Logged In
   ↓
Redirect to /login
   ↓
User Sees Login Screen
   ↓
User Clicks "Sign Up"
   ↓
Navigate to /signup
   ↓
User Creates Account
   ↓
Signup Success
   ↓
Navigate to /login (auto-redirect after 2 seconds)
   ↓
User Logs In
   ↓
Auth State Changes (triggers listener)
   ↓
GoRouter.refresh() Called
   ↓
Redirect Logic Re-runs
   ↓
User Now Logged In
   ↓
Redirect to /home
```

### Existing User (Already Logged In)

```
App Opens
   ↓
Redirect Logic Checks Auth State
   ↓
User Still Has Valid Session
   ↓
isLoggedIn() Returns true
   ↓
Redirect to /home
   ↓
User Sees Home Screen
   ↓
User Clicks Logout
   ↓
logout() Called
   ↓
Auth State Changes
   ↓
GoRouter.refresh() Triggered
   ↓
Redirect Logic Re-runs
   ↓
User Not Logged In
   ↓
Redirect to /login
```

## Files Structure

```
lib/
├── main.dart                 # App entry point with GoRouter setup
├── services/
│   └── auth_service.dart     # Authentication service
├── routes/
│   └── app_router.dart       # Route definitions and redirect logic
└── screens/
    ├── home_screen.dart      # Home page (protected)
    └── auth/
        ├── login_screen.dart # Login screen
        └── signup_screen.dart # Signup screen
```

## Key Features

### 1. **Automatic Redirect**
- Users are automatically redirected based on authentication state
- No manual route guarding needed in each screen

### 2. **State Persistence**
- Session is checked on app start
- If user has valid session, they stay logged in after app restart

### 3. **Real-time Navigation**
- Auth state listener triggers redirect on login/logout
- Uses `GoRouter.refresh()` to rerun redirect logic

### 4. **Error Handling**
- 404 error page for undefined routes
- User-friendly error messages in auth screens

### 5. **Loading States**
- Loading indicators during auth operations
- Form validation before submission
- Error snackbars for failed operations

## Extending the Router

To add new protected routes:

```dart
// In app_router.dart, add to routes array:
GoRoute(
  path: '/new-screen',
  name: 'newScreen',
  pageBuilder: (context, state) => MaterialPage<void>(
    key: state.pageKey,
    child: const NewScreen(),
  ),
),
```

The redirect logic automatically protects this route since it's not in the auth routes list.

## Authentication Events Handled

The app listens to these auth events via `authService.onAuthStateChanged()`:

- `AuthChangeEvent.initialSession` - Initial session load
- `AuthChangeEvent.signedIn` - User logged in
- `AuthChangeEvent.signedOut` - User logged out
- `AuthChangeEvent.tokenRefreshed` - Session refreshed
- `AuthChangeEvent.userUpdated` - User data updated
- `AuthChangeEvent.userDeleted` - User account deleted

Each event triggers `GoRouter.refresh()` to reevaluate redirects.

## Testing the Navigation

### Test 1: Fresh Install (Not Logged In)
```
Run app → Should redirect to /login
```

### Test 2: Login Flow
```
On login screen → Enter credentials → Click Sign In → Should redirect to /home
```

### Test 3: Try to Access Auth Screen When Logged In
```
Logged in, manually navigate to /login → Should redirect to /home
```

### Test 4: Logout Flow
```
On home screen → Click Logout → Should redirect to /login
```

### Test 5: App Restart (Session Persistence)
```
Stop app while logged in → Restart app → Should redirect to /home
```

## Troubleshooting

### App Redirects to Login Infinitely
- **Cause**: `isLoggedIn()` not working correctly
- **Solution**: Check `AuthService.isLoggedIn()` logic - verify session is being stored

### Routes Not Rebuilding After Auth Change
- **Cause**: Auth state listener not triggering refresh
- **Solution**: Ensure `GoRouter.refresh()` is called in auth listener

### Navigation Not Working
- **Cause**: Wrong route path
- **Solution**: Double-check route path matches exactly (case-sensitive)

## Next Steps

1. **Implement Bloc for Auth State** (optional)
   - Move auth state management to Bloc
   - Makes state management more scalable

2. **Add More Routes**
   - Profile screen
   - Settings screen
   - Other protected screens

3. **Add Route Animations**
   - Custom page transitions
   - Slide transitions
   - Fade transitions

4. **Add Deep Linking** (optional)
   - Handle deep links from notifications
   - Handle OAuth redirects

5. **Add Error Boundaries**
   - Handle network errors
   - Handle auth failures gracefully
