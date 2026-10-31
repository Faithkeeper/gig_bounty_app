import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'data/remote/auth_service.dart';
import 'screens/auth/auth_screen.dart';
import 'models/user_profile.dart';
import 'screens/dashboard/task_board_screen.dart';
import 'data/remote/fcm_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize FCM / local notifications safely
  await FcmService().initNotifications();

  runApp(const GigBountyApp());
}

class GigBountyApp extends StatelessWidget {
  const GigBountyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GigBounty',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();

    return StreamBuilder(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          final uid = authService.currentUser!.uid;
          
          // Fetch user profile and pass it to the full TaskBoardScreen
          return FutureBuilder<UserProfile?>(
            future: authService.getUserProfile(uid),
            builder: (context, profileSnapshot) {
              if (profileSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              if (!profileSnapshot.hasData || profileSnapshot.data == null) {
                return Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Error loading user profile from database.'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => authService.signOut(),
                          child: const Text('Sign Out'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Route straight to the live marketplace dashboard!
              return TaskBoardScreen(userProfile: profileSnapshot.data!);
            },
          );
        }
        return const AuthScreen();
      },
    );
  }
}

class HomeScreen extends StatelessWidget {
  final String uid;
  const HomeScreen({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('GigBounty Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => authService.signOut(),
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: FutureBuilder<UserProfile?>(
        future: authService.getUserProfile(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('User profile not found in database.'));
          }

          final user = snapshot.data!;
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.verified_user, size: 80, color: Colors.deepOrange),
                  const SizedBox(height: 16),
                  Text('Welcome, ${user.fullName}!', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Chip(
                    label: Text('Role: ${user.role}', style: const TextStyle(color: Colors.white)),
                    backgroundColor: Colors.deepOrange,
                  ),
                  const SizedBox(height: 8),
                  Text('Email: ${user.email}', style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 24),
                  const Text(
                    'Phase 3 complete! Multiple user accounts and Firestore profiles active.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}