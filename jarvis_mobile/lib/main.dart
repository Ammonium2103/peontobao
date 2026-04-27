import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:avatar_glow/avatar_glow.dart';
import 'package:animate_do/animate_do.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

void main() => runApp(const JarvisVoiceApp());

class JarvisTheme {
  static const primaryColor = Color(0xFF00E5FF);
  static const bgColor = Color(0xFF0A0E14);
  static const cardColor = Color(0xFF161B22);
}

class JarvisVoiceApp extends StatelessWidget {
  const JarvisVoiceApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: JarvisTheme.bgColor,
        primaryColor: JarvisTheme.primaryColor,
      ),
      home: const JarvisVoiceCore(),
    );
  }
}

class JarvisVoiceCore extends StatefulWidget {
  const JarvisVoiceCore({super.key});
  @override
  State<JarvisVoiceCore> createState() => _JarvisVoiceCoreState();
}

class _JarvisVoiceCoreState extends State<JarvisVoiceCore> {
  // Engines
  final _audioRecorder = AudioRecorder();
  final _audioPlayer = AudioPlayer();
  bool _isRecording = false;
  String _userText = "Giữ để nói chuyện với Jarvis...";
  String _jarvisText = "Tôi đang lắng nghe, thưa sếp.";
  
  // Connection (Standalone Mode - Direct to Cloud via Python Gateway)
  final String _serverUrl = "http://192.168.1.15:8000"; // THAY IP CỦA SẾP
  
  late Database _db;
  List<Map<String, String>> _history = [];

  @override
  void initState() {
    super.initState();
    _initMemory();
  }

  Future<void> _initMemory() async {
    _db = await openDatabase(
      p.join(await getDatabasesPath(), 'jarvis_v6.db'),
      onCreate: (db, version) => db.execute("CREATE TABLE memory(id INTEGER PRIMARY KEY, role TEXT, content TEXT)"),
      version: 1,
    );
    _loadHistory();
  }

  void _loadHistory() async {
    final List<Map<String, dynamic>> maps = await _db.query('memory', orderBy: 'id DESC', limit: 5);
    setState(() {
      _history = List.generate(maps.length, (i) => {
        'role': maps[i]['role'] as String,
        'content': maps[i]['content'] as String,
      }).reversed.toList();
    });
  }

  Future<void> _startRecording() async {
    if (await Permission.microphone.request().isGranted) {
      final dir = await getApplicationDocumentsDirectory();
      final path = p.join(dir.path, 'audio.m4a');
      
      await _audioRecorder.start(const RecordConfig(), path: path);
      setState(() {
        _isRecording = true;
        _userText = "Đang lắng nghe sếp...";
      });
    }
  }

  Future<void> _stopRecording() async {
    final path = await _audioRecorder.stop();
    setState(() => _isRecording = false);
    if (path != null) {
      _processAudio(path);
    }
  }

  Future<void> _processAudio(String path) async {
    setState(() => _jarvisText = "Đang giải mã giọng nói (Whisper)...");
    
    try {
      // 1. Send Audio to Whisper (Python Server Gateway)
      var request = http.MultipartRequest('POST', Uri.parse('$_serverUrl/stt'));
      request.files.add(await http.MultipartFile.fromPath('file', path));
      
      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      var result = jsonDecode(responseData);
      String transcript = result['text'];

      if (transcript.isNotEmpty) {
        setState(() => _userText = transcript);
        _getAIResponse(transcript);
      }
    } catch (e) {
      setState(() => _jarvisText = "Lỗi Whisper: Không thể kết nối tới Server.");
    }
  }

  Future<void> _getAIResponse(String text) async {
    setState(() => _jarvisText = "Jarvis đang suy nghĩ...");
    
    try {
      final response = await http.post(
        Uri.parse('$_serverUrl/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        String aiResponse = data['response'];

        await _db.insert('memory', {'role': 'user', 'content': text});
        await _db.insert('memory', {'role': 'assistant', 'content': aiResponse});
        _loadHistory();

        setState(() => _jarvisText = aiResponse);
        
        // ML Engineer Tip: ElevenLabs voice should be generated on server or client.
        // For simplicity, we use local TTS here, or can be upgraded to stream ElevenLabs audio.
      }
    } catch (e) {
      setState(() => _jarvisText = "Mất kết nối với Neural Core.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [JarvisTheme.bgColor, Color(0xFF001219)],
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 80),
            FadeInDown(
              child: const Text("JARVIS v6.0", style: TextStyle(fontSize: 24, letterSpacing: 5, fontWeight: FontWeight.bold, color: JarvisTheme.primaryColor)),
            ),
            const SizedBox(height: 50),
            
            // Central Neural Ring
            Expanded(
              child: Center(
                child: AvatarGlow(
                  animate: _isRecording,
                  glowColor: JarvisTheme.primaryColor,
                  duration: const Duration(milliseconds: 1000),
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: JarvisTheme.primaryColor.withOpacity(0.3), width: 4),
                      boxShadow: [BoxShadow(color: JarvisTheme.primaryColor.withOpacity(0.2), blurRadius: 30)],
                    ),
                    child: const Icon(Icons.blur_on, size: 100, color: JarvisTheme.primaryColor),
                  ),
                ),
              ),
            ),

            // AI Console
            FadeInUp(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(25),
                height: 250,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: JarvisTheme.cardColor.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white10),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("BOSS: $_userText", style: const TextStyle(color: Colors.white38, fontSize: 13)),
                      const SizedBox(height: 15),
                      const Divider(color: Colors.white10),
                      const SizedBox(height: 15),
                      Text(
                        _jarvisText,
                        style: const TextStyle(fontSize: 18, height: 1.6, fontWeight: FontWeight.w300),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Recording Trigger
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 60),
              child: GestureDetector(
                onTapDown: (_) => _startRecording(),
                onTapUp: (_) => _stopRecording(),
                child: FloatingActionButton.large(
                  onPressed: () {}, // Handled by GestureDetector
                  backgroundColor: _isRecording ? Colors.redAccent : JarvisTheme.primaryColor,
                  child: Icon(_isRecording ? Icons.mic : Icons.mic_none, size: 45, color: Colors.black),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
