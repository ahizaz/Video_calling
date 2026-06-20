import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/video_room_service.dart';
import 'video_call_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();

  final AuthService _authService = AuthService();
  final VideoRoomService _videoRoomService = VideoRoomService();

  bool isLoading = false;
  String? errorMessage;

  Future<void> loginUser() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      await _authService.login(
        phoneNumber: phoneController.text.trim(),
        password: passwordController.text.trim(),
      );

      final roomId = await _videoRoomService.getMyRoomId();

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => VideoCallScreen(roomId: roomId),
        ),
      );
    } catch (e) {
      setState(() {
        errorMessage = 'Error: $e';
      });
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            if (errorMessage != null)
              Text(
                errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: isLoading ? null : loginUser,
                icon: isLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.login),
                label: Text(isLoading ? 'Loading...' : 'Login & Start Call'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}