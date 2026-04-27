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
  String _userText = "Neural Standby...";
  String _aiText = "System Standalone Online. No Proxy required, Boss.";
  
  // NVIDIA & OpenAI Direct Neural Links
  final String _nvidiaApiKey = "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";
  final String _openaiApiKey = "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";

  late Database _db;
  List<Map<String, String>> _history = [];
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
      p.join(await getDatabasesPath(), 'jarvis_standalone_hud.db'),
      onCreate: (db, version) => db.execute("CREATE TABLE memory(id INTEGER PRIMARY KEY, role TEXT, content TEXT)"),
      version: 1,
    );
    _loadHistory();
  }

  void _loadHistory() async {
    final List<Map<String, dynamic>> maps = await _db.query('memory', orderBy: 'id DESC', limit: 6);
    setState(() {
      _history = List.generate(maps.length, (i) => {
        'role': maps[i]['role'] as String,
        'content': maps[i]['content'] as String,
      }).reversed.toList();
    });
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
      final path = p.join(dir.path, 'neural_signal.m4a');
      await _audioRecorder.start(const RecordConfig(), path: path);
      setState(() {
        _isRecording = true;
        _userText = "Recording Neural Wave...";
      });
    }
  }

  Future<void> _stopVoice() async {
    final path = await _audioRecorder.stop();
    setState(() => _isRecording = false);
    if (path != null) _processVoiceDirectly(path);
  }

  Future<void> _processVoiceDirectly(String path) async {
    setState(() => _aiText = "Analyzing Audio Frequency...");
    try {
      // Direct call to OpenAI Whisper API
      var request = http.MultipartRequest('POST', Uri.parse('https://api.openai.com/v1/audio/transcriptions'));
      request.headers['Authorization'] = 'Bearer $_openaiApiKey';
      request.fields['model'] = 'whisper-1';
      request.files.add(await http.MultipartFile.fromPath('file', path));
      
      var response = await request.send();
      var result = jsonDecode(await response.stream.bytesToString());
      String transcript = result['text'];

      if (transcript.isNotEmpty) {
        setState(() => _userText = transcript);
        _checkShortcuts(transcript);
        _getAIDirectResponse(transcript);
      }
    } catch (e) {
      setState(() => _aiText = "Speech Processor Offline. Use Text, Boss.");
    }
  }

  Future<void> _getAIDirectResponse(String text) async {
    setState(() => _aiText = "Reasoning with Llama-3...");
    try {
      final messages = [
        {"role": "system", "content": "You are JARVIS HUD. Standalone Agent. Professional, witty, and elite. Reply in Vietnamese."},
        ..._history,
        {"role": "user", "content": text}
      ];

      final response = await http.post(
        Uri.parse('https://integrate.api.nvidia.com/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $_nvidiaApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "model": "meta/llama-3.1-70b-instruct",
          "messages": messages,
          "temperature": 0.5,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        String aiResponse = data['choices'][0]['message']['content'];

        await _db.insert('memory', {'role': 'user', 'content': text});
        await _db.insert('memory', {'role': 'assistant', 'content': aiResponse});
        _loadHistory();

        setState(() => _aiText = aiResponse);
        _checkShortcuts(aiResponse);
      }
    } catch (e) {
      setState(() => _aiText = "Direct Neural Link Severed.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: Container(decoration: BoxDecoration(gradient: RadialGradient(center: Alignment.center, colors: [JColor.secondary.withOpacity(0.05), JColor.background], radius: 1.5)))),
          Column(
            children: [
              const SizedBox(height: 60),
              FadeInDown(child: _buildHUDHeader()),
              const Spacer(),
              _buildNeuralOrb(),
              const Spacer(),
              _buildHUDConsole(),
              _buildNeuralTrigger(),
              const SizedBox(height: 50),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHUDHeader() {
    return Column(
      children: [
        Text("STANDALONE NEURAL LINK", style: TextStyle(color: JColor.primary.withOpacity(0.4), fontSize: 10, letterSpacing: 2)),
        const Text("JARVIS SUPREME", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 6, color: JColor.primary)),
        const SizedBox(height: 5),
        Container(height: 1, width: 150, color: JColor.primary.withOpacity(0.2)),
      ],
    );
  }

  Widget _buildNeuralOrb() {
    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (_, child) => Transform.rotate(angle: _controller.value * 2 * math.pi, child: child),
          child: Container(width: 230, height: 230, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: JColor.primary.withOpacity(0.05), width: 10))),
        ),
        AvatarGlow(animate: _isRecording, glowColor: JColor.primary, child: SpinKitDoubleBounce(color: JColor.primary.withOpacity(0.5), size: 160)),
        const Icon(Icons.psychology_outlined, color: JColor.primary, size: 50),
      ],
    );
  }

  Widget _buildHUDConsole() {
    return FadeInUp(
      child: Container(
        margin: const EdgeInsets.all(25),
        padding: const EdgeInsets.all(20),
        height: 220,
        decoration: BoxDecoration(color: JColor.card.withOpacity(0.5), borderRadius: BorderRadius.circular(20), border: Border.all(color: JColor.primary.withOpacity(0.1))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("DATA_STREAM >> USER: $_userText", style: const TextStyle(color: JColor.primary, fontSize: 11, fontFamily: 'monospace')),
            const Divider(color: Colors.white10),
            Expanded(child: SingleChildScrollView(child: Text("NEURAL_OUT >> JARVIS: $_aiText", style: const TextStyle(color: JColor.accent, fontSize: 16, height: 1.4)))),
          ],
        ),
      ),
    );
  }

  Widget _buildNeuralTrigger() {
    return GestureDetector(
      onTapDown: (_) => _startVoice(),
      onTapUp: (_) => _stopVoice(),
      child: Container(
        width: 80, height: 80,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _isRecording ? Colors.red : JColor.primary, width: 1.5), color: _isRecording ? Colors.red.withOpacity(0.1) : Colors.transparent),
        child: Icon(_isRecording ? Icons.mic : Icons.bolt, color: _isRecording ? Colors.red : JColor.primary, size: 35),
      ),
    );
  }
}
