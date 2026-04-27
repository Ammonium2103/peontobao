import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:avatar_glow/avatar_glow.dart';
import 'package:animate_do/animate_do.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

void main() => runApp(const JarvisFuturisticApp());

class JColor {
  static const primary = Color(0xFF00FBFF);
  static const secondary = Color(0xFF0077B6);
  static const background = Color(0xFF02040F);
  static const card = Color(0xFF0D1B2A);
  static const accent = Color(0xFFE0E1DD);
}

class JarvisFuturisticApp extends StatelessWidget {
  const JarvisFuturisticApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: JColor.background,
        primaryColor: JColor.primary,
      ),
      home: const JarvisHUD(),
    );
  }
}

class JarvisHUD extends StatefulWidget {
  const JarvisHUD({super.key});
  @override
  State<JarvisHUD> createState() => _JarvisHUDState();
}

class _JarvisHUDState extends State<JarvisHUD> with SingleTickerProviderStateMixin {
  final _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  String _userText = "Awaiting command...";
  String _aiText = "System Online. Standby for orders, Boss.";
  
  final String _serverUrl = "http://192.168.1.15:8000"; // SẾP NHỚ THAY IP
  late Database _db;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _initMemory();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initMemory() async {
    _db = await openDatabase(
      p.join(await getDatabasesPath(), 'jarvis_hud.db'),
      onCreate: (db, version) => db.execute("CREATE TABLE memory(id INTEGER PRIMARY KEY, role TEXT, content TEXT)"),
      version: 1,
    );
  }

  Future<void> _launchApp(String name) async {
    final Map<String, String> apps = {
      'zalo': 'https://zalo.me',
      'facebook': 'https://facebook.com',
      'youtube': 'https://youtube.com',
      'mess': 'https://messenger.com',
    };
    
    String? target = apps[name.toLowerCase()];
    if (target != null) {
      final uri = Uri.parse(target);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  void _checkShortcuts(String text) {
    String lower = text.toLowerCase();
    if (lower.contains("zalo")) _launchApp("zalo");
    if (lower.contains("facebook")) _launchApp("facebook");
    if (lower.contains("youtube")) _launchApp("youtube");
  }

  Future<void> _startVoice() async {
    if (await Permission.microphone.request().isGranted) {
      final dir = await getApplicationDocumentsDirectory();
      final path = p.join(dir.path, 'cmd.m4a');
      await _audioRecorder.start(const RecordConfig(), path: path);
      setState(() {
        _isRecording = true;
        _userText = "Listening...";
      });
    }
  }

  Future<void> _stopVoice() async {
    final path = await _audioRecorder.stop();
    setState(() => _isRecording = false);
    if (path != null) _processVoice(path);
  }

  Future<void> _processVoice(String path) async {
    setState(() => _aiText = "Decoding Neural Signal...");
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$_serverUrl/stt'));
      request.files.add(await http.MultipartFile.fromPath('file', path));
      var response = await request.send();
      var result = jsonDecode(await response.stream.bytesToString());
      String transcript = result['text'];

      if (transcript.isNotEmpty) {
        setState(() => _userText = transcript);
        _checkShortcuts(transcript);
        _getAIResponse(transcript);
      }
    } catch (e) {
      setState(() => _aiText = "Communication Link Severed.");
    }
  }

  Future<void> _getAIResponse(String text) async {
    try {
      final response = await http.post(
        Uri.parse('$_serverUrl/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() => _aiText = data['response']);
        _checkShortcuts(_aiText);
      }
    } catch (e) {
      setState(() => _aiText = "Core Processor Error.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background HUD Layer
          Positioned.fill(child: _buildHUDBackground()),
          
          Column(
            children: [
              const SizedBox(height: 60),
              _buildTopHeader(),
              const Spacer(),
              _buildNeuralCenter(),
              const Spacer(),
              _buildConsoleBox(),
              _buildMicButton(),
              const SizedBox(height: 50),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHUDBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          colors: [JColor.secondary.withOpacity(0.1), JColor.background],
          radius: 1.5,
        ),
      ),
    );
  }

  Widget _buildTopHeader() {
    return FadeInDown(
      child: Column(
        children: [
          Text("STRATEGIC DEFENSE SYSTEM", style: TextStyle(color: JColor.primary.withOpacity(0.5), fontSize: 10, letterSpacing: 2)),
          const Text("JARVIS HUD v7.0", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 8, color: JColor.primary)),
          const SizedBox(height: 5),
          Container(height: 1, width: 200, color: JColor.primary.withOpacity(0.3)),
        ],
      ),
    );
  }

  Widget _buildNeuralCenter() {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Rotating Outer Ring
          AnimatedBuilder(
            animation: _controller,
            builder: (_, child) => Transform.rotate(angle: _controller.value * 2 * math.pi, child: child),
            child: Container(
              width: 250, height: 250,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: JColor.primary.withOpacity(0.1), width: 15)),
            ),
          ),
          // Pulsing Core
          AvatarGlow(
            animate: _isRecording,
            glowColor: JColor.primary,
            child: SpinKitPulse(color: JColor.primary, size: 150),
          ),
          const Icon(Icons.shield_outlined, color: JColor.primary, size: 60),
        ],
      ),
    );
  }

  Widget _buildConsoleBox() {
    return FadeInUp(
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(20),
        height: 220,
        width: double.infinity,
        decoration: BoxDecoration(
          color: JColor.card.withOpacity(0.6),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: JColor.primary.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.terminal, size: 14, color: JColor.primary),
                const SizedBox(width: 8),
                Text("NEURAL_LINK_STREAM", style: TextStyle(color: JColor.primary.withOpacity(0.7), fontSize: 10)),
              ],
            ),
            const Divider(color: Colors.white10),
            Text("USER >> $_userText", style: const TextStyle(color: JColor.primary, fontSize: 13, fontFamily: 'monospace')),
            const SizedBox(height: 10),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  "JARVIS >> $_aiText",
                  style: const TextStyle(color: JColor.accent, fontSize: 16, height: 1.5, fontWeight: FontWeight.w300),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMicButton() {
    return GestureDetector(
      onTapDown: (_) => _startVoice(),
      onTapUp: (_) => _stopVoice(),
      child: Container(
        width: 90, height: 90,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _isRecording ? Colors.red.withOpacity(0.2) : JColor.primary.withOpacity(0.1),
          border: Border.all(color: _isRecording ? Colors.red : JColor.primary, width: 2),
          boxShadow: [BoxShadow(color: (_isRecording ? Colors.red : JColor.primary).withOpacity(0.3), blurRadius: 20)],
        ),
        child: Icon(_isRecording ? Icons.mic : Icons.mic_none, size: 40, color: _isRecording ? Colors.red : JColor.primary),
      ),
    );
  }
}
