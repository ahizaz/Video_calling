import 'dart:convert';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String baseUrl = 'http://66.29.151.40:6060';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Video Calling',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
final phoneController = TextEditingController();
final passwordController = TextEditingController();

  bool isLoading = false;
  String? errorMessage;

  Future<int> _getMyRoomId() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('access_token') ?? '';

    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/video-rooms/rooms/my-rooms/'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      if (data is List && data.isNotEmpty) {
        return data.first['id'];
      } else {
        throw Exception('No video room found');
      }
    } else {
      throw Exception(
        data['detail']?.toString() ?? 'Failed to load video rooms',
      );
    }
  }

  Future<void> loginUser() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/auth/login/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone_number': phoneController.text.trim(),
          'password': passwordController.text.trim(),
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();

        await prefs.setString('access_token', data['access'] ?? '');
        await prefs.setString('refresh_token', data['refresh'] ?? '');
        await prefs.setString('user_name', data['user']?['name'] ?? '');

        final roomId = await _getMyRoomId();

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => VideoCallScreen(roomId: roomId)),
        );
      } else {
        setState(() {
          errorMessage =
              data['detail']?.toString() ??
              data['non_field_errors']?.toString() ??
              'Login failed';
        });
      }
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
              Text(errorMessage!, style: const TextStyle(color: Colors.red)),
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

class VideoCallScreen extends StatefulWidget {
  final int roomId;

  const VideoCallScreen({super.key, required this.roomId});

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  RtcEngine? _engine;

  int? _remoteUid;
  bool _localUserJoined = false;
  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _isLoading = true;
  String? _errorMessage;

  String? _appId;
  String? _token;
  String? _channelName;

  @override
  void initState() {
    super.initState();
    _setupVideoCall();
  }

  Future<void> _setupVideoCall() async {
    try {
      await _fetchAgoraToken();
      await _initAgora();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchAgoraToken() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('access_token') ?? '';

    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/video-rooms/rooms/${widget.roomId}/token/'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      _appId = data['app_id'];
      _channelName = data['channel'];
      _token = data['token'];
    } else {
      throw Exception(
        data['detail']?.toString() ?? 'Failed to get video call token',
      );
    }
  }

  Future<void> _initAgora() async {
    await [Permission.camera, Permission.microphone].request();

    final engine = createAgoraRtcEngine();
    _engine = engine;

    await engine.initialize(
      RtcEngineContext(
        appId: _appId!,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ),
    );

    engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          setState(() {
            _localUserJoined = true;
            _isLoading = false;
          });
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          setState(() {
            _remoteUid = remoteUid;
          });
        },
        onUserOffline: (connection, remoteUid, reason) {
          setState(() {
            _remoteUid = null;
          });
        },
        onError: (err, msg) {
          setState(() {
            _errorMessage = 'Agora Error: $err $msg';
            _isLoading = false;
          });
        },
      ),
    );

    await engine.enableVideo();
    await engine.startPreview();

    await engine.joinChannel(
      token: _token!,
      channelId: _channelName!,
      uid: 0,
      options: const ChannelMediaOptions(
        autoSubscribeVideo: true,
        autoSubscribeAudio: true,
        publishCameraTrack: true,
        publishMicrophoneTrack: true,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
      ),
    );
  }

  Future<void> _toggleMute() async {
    final engine = _engine;
    if (engine == null) return;

    setState(() {
      _isMuted = !_isMuted;
    });

    await engine.muteLocalAudioStream(_isMuted);
  }

  Future<void> _toggleCamera() async {
    final engine = _engine;
    if (engine == null) return;

    setState(() {
      _isCameraOff = !_isCameraOff;
    });

    await engine.muteLocalVideoStream(_isCameraOff);
  }

  Future<void> _switchCamera() async {
    final engine = _engine;
    if (engine == null) return;

    await engine.switchCamera();
  }

  Future<void> _endCall() async {
    final engine = _engine;
    if (engine != null) {
      await engine.leaveChannel();
    }

    if (!mounted) return;

    Navigator.pop(context);
  }

  @override
  void dispose() {
    _engine?.leaveChannel();
    _engine?.release();
    super.dispose();
  }

  Widget _remoteVideo() {
    final engine = _engine;

    if (engine != null && _remoteUid != null && _channelName != null) {
      return AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: engine,
          canvas: VideoCanvas(uid: _remoteUid),
          connection: RtcConnection(channelId: _channelName!),
        ),
      );
    }

    return const Center(
      child: Text(
        'Waiting for remote user...',
        style: TextStyle(color: Colors.white, fontSize: 18),
      ),
    );
  }

  Widget _localVideo() {
    final engine = _engine;

    if (engine != null && _localUserJoined && !_isCameraOff) {
      return AgoraVideoView(
        controller: VideoViewController(
          rtcEngine: engine,
          canvas: const VideoCanvas(uid: 0),
        ),
      );
    }

    return Container(
      color: Colors.black54,
      child: const Center(
        child: Icon(Icons.videocam_off, color: Colors.white, size: 35),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red, fontSize: 16),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: _remoteVideo()),
          Positioned(
            top: 50,
            right: 16,
            child: Container(
              height: 180,
              width: 120,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white, width: 2),
              ),
              clipBehavior: Clip.antiAlias,
              child: _localVideo(),
            ),
          ),
          Positioned(
            top: 55,
            left: 16,
            right: 150,
            child: Text(
              _channelName ?? 'Video Call',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 35,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _CallButton(
                  icon: _isMuted ? Icons.mic_off : Icons.mic,
                  backgroundColor: Colors.white24,
                  onTap: _toggleMute,
                ),
                _CallButton(
                  icon: _isCameraOff ? Icons.videocam_off : Icons.videocam,
                  backgroundColor: Colors.white24,
                  onTap: _toggleCamera,
                ),
                _CallButton(
                  icon: Icons.call_end,
                  backgroundColor: Colors.red,
                  size: 70,
                  onTap: _endCall,
                ),
                _CallButton(
                  icon: Icons.cameraswitch,
                  backgroundColor: Colors.white24,
                  onTap: _switchCamera,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  final IconData icon;
  final Color backgroundColor;
  final VoidCallback onTap;
  final double size;

  const _CallButton({
    required this.icon,
    required this.backgroundColor,
    required this.onTap,
    this.size = 58,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(size / 2),
      onTap: onTap,
      child: Container(
        height: size,
        width: size,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: size == 70 ? 34 : 28),
      ),
    );
  }
}
