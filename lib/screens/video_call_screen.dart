import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/video_room_service.dart';
import '../widgets/call_button.dart';

class VideoCallScreen extends StatefulWidget {
  final int roomId;

  const VideoCallScreen({
    super.key,
    required this.roomId,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final VideoRoomService _videoRoomService = VideoRoomService();

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
    final data = await _videoRoomService.getAgoraToken(widget.roomId);

    _appId = data['app_id'];
    _channelName = data['channel'];
    _token = data['token'];
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
        child: Icon(
          Icons.videocam_off,
          color: Colors.white,
          size: 35,
        ),
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
              style: const TextStyle(
                color: Colors.red,
                fontSize: 16,
              ),
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
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
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
                CallButton(
                  icon: _isMuted ? Icons.mic_off : Icons.mic,
                  backgroundColor: Colors.white24,
                  onTap: _toggleMute,
                ),
                CallButton(
                  icon: _isCameraOff ? Icons.videocam_off : Icons.videocam,
                  backgroundColor: Colors.white24,
                  onTap: _toggleCamera,
                ),
                CallButton(
                  icon: Icons.call_end,
                  backgroundColor: Colors.red,
                  size: 70,
                  onTap: _endCall,
                ),
                CallButton(
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