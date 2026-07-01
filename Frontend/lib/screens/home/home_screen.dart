// lib/screens/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../auth/login_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final authNotifier = ref.read(authProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authNotifier.logout();
              // ✅ استخدام !context.mounted بدلاً من context.mounted
              if (!context.mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (authState.user != null) ...[
              CircleAvatar(
                radius: 50,
                backgroundImage: authState.user!.profilePicture != null
                    ? NetworkImage(authState.user!.profilePicture!)
                    : null,
                child: authState.user!.profilePicture == null
                    ? Text(
                        authState.user!.fullName[0].toUpperCase(),
                        style: const TextStyle(fontSize: 40),
                      )
                    : null,
              ),
              const SizedBox(height: 20),
              Text(
                'Welcome, ${authState.user!.fullName}!',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Email: ${authState.user!.email}',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Text(
                'Role: ${authState.user!.role}',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Text(
                'Status: ${authState.user!.status}',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ] else
              const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}