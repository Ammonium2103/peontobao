import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:avatar_glow/avatar_glow.dart';
import 'package:animate_do/animate_do.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

void main() => runApp(const JarvisStandaloneApp());

class JarvisTheme {
  static const primaryColor = Color(0xFF00E5FF);
  static const bgColor = Color(0xFF0A0E14);
  static const cardColor = Color(0xFF161B22);
}

class JarvisStandaloneApp extends StatelessWidget {
  const JarvisStandaloneApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: JarvisTheme.bgColor,
        primaryColor: JarvisTheme.primaryColor,
      ),
      home: const JarvisCoreScreen(),
    );
  }
}

class JarvisCoreScreen extends StatefulWidget {
  const JarvisCoreScreen({super.key});
  @override
  State<JarvisCoreScreen> createState() => _JarvisCoreScreenState();
}

class _JarvisCoreScreenState extends State<JarvisCoreScreen> {
  // AI Engines
  late stt.SpeechToText _speech;
  late FlutterTts _tts;
  bool _isListening = false;
  String _userText = "Nhấn để nói, sếp!";
  String _jarvisText = "Hệ thống Standalone đã sẵn sàng. Tôi đang chạy trực tiếp trên điện thoại của sếp.";
  
  // Local Memory (SQLite)
  late Database _db;
  List<Map<String, String>> _history = [];

  // NVIDIA Neural Link (Thay key của sếp vào đây)
  final String _nvidiaApiKey = "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";

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _tts = FlutterTts();
    _initNeuralMemory();
    _setupVoice();
  }

  Future<void> _initNeuralMemory() async {
    _db = await openDatabase(
      p.join(await getDatabasesPath(), 'jarvis_memory.db'),
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

  void _setupVoice() async {
    await _tts.setLanguage("vi-VN");
    await _tts.setSpeechRate(0.5);
  }

  void _listen() async {
    if (!_isListening) {
      if (await Permission.microphone.request().isGranted) {
        bool available = await _speech.initialize();
        if (available) {
          setState(() => _isListening = true);
          _speech.listen(onResult: (val) {
            setState(() => _userText = val.recognizedWords);
            if (val.finalResult) {
              setState(() => _isListening = false);
              _processWithAI(_userText);
            }
          });
        }
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  Future<void> _processWithAI(String text) async {
    setState(() => _jarvisText = "Đang suy luận...");

    try {
      final url = Uri.parse('https://integrate.api.nvidia.com/v1/chat/completions');
      
      // Prompt Engineering: Personality & Autonomy
      final messages = [
        {"role": "system", "content": "You are JARVIS, a helpful and witty AI assistant running standalone on a mobile device. Your responses should be professional yet warm. Always speak in Vietnamese."},
        ..._history,
        {"role": "user", "content": text}
      ];

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $_nvidiaApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "model": "meta/llama-3.1-70b-instruct",
          "messages": messages,
          "temperature": 0.5,
          "max_tokens": 512,
        }),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        String aiResponse = data['choices'][0]['message']['content'];

        // Save to Local Memory
        await _db.insert('memory', {'role': 'user', 'content': text});
        await _db.insert('memory', {'role': 'assistant', 'content': aiResponse});
        _loadHistory();

        setState(() => _jarvisText = aiResponse);
        await _tts.speak(aiResponse);
      }
    } catch (e) {
      setState(() => _jarvisText = "Kết nối Neural Link bị gián đoạn. Kiểm tra Internet, sếp!");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text("JARVIS STANDALONE", style: TextStyle(letterSpacing: 3)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 30),
          // Neural Visualizer
          AvatarGlow(
            animate: _isListening,
            glowColor: JarvisTheme.primaryColor,
            child: GestureDetector(
              onTap: _listen,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: JarvisTheme.primaryColor, width: 2),
                  gradient: const RadialGradient(colors: [Color(0x3300E5FF), Colors.transparent]),
                ),
                child: Icon(_isListening ? Icons.mic : Icons.bolt, size: 60, color: JarvisTheme.primaryColor),
              ),
            ),
          ),
          
          const SizedBox(height: 40),
          
          // AI Interaction Terminal
          Expanded(
            child: FadeInUp(
              child: Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: JarvisTheme.cardColor,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("BOSS: $_userText", style: const TextStyle(color: Colors.white38, fontSize: 12)),
                    const Divider(color: Colors.white10, height: 30),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Text(
                          _jarvisText,
                          style: const TextStyle(fontSize: 18, height: 1.5, fontWeight: FontWeight.w300),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Clear Memory Button
          Padding(
            padding: const EdgeInsets.only(bottom: 40),
            child: TextButton.icon(
              onPressed: () {
                _db.delete('memory');
                _loadHistory();
              },
              icon: const Icon(Icons.delete_sweep, color: Colors.white24),
              label: const Text("XÓA KÝ ỨC", style: TextStyle(color: Colors.white24)),
            ),
          )
        ],
      ),
    );
  }
}
