import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:avatar_glow/avatar_glow.dart';
import 'package:animate_do/animate_do.dart';

void main() => runApp(const JarvisAIApp());

class JarvisMobileTheme {
  static const primaryColor = Color(0xFF00E5FF); // Neon Cyan
  static const bgColor = Color(0xFF0A0E14);
  static const cardColor = Color(0xFF161B22);
}

class JarvisAIApp extends StatelessWidget {
  const JarvisAIApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: JarvisMobileTheme.bgColor,
        primaryColor: JarvisMobileTheme.primaryColor,
      ),
      home: const JarvisBrainCenter(),
    );
  }
}

class JarvisBrainCenter extends StatefulWidget {
  const JarvisBrainCenter({super.key});
  @override
  State<JarvisBrainCenter> createState() => _JarvisBrainCenterState();
}

class _JarvisBrainCenterState extends State<JarvisBrainCenter> {
  // AI & Voice Engines
  late stt.SpeechToText _speech;
  late FlutterTts _tts;
  bool _isListening = false;
  String _textText = "Nhấn micro để ra lệnh, sếp!";
  String _aiResponse = "Hệ thống đã sẵn sàng.";
  
  // Connection
  String _serverIp = "192.168.1.15"; // SẾP NHỚ THAY IP NÀY
  final TextEditingController _ipController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _tts = FlutterTts();
    _setupTts();
  }

  void _setupTts() async {
    await _tts.setLanguage("vi-VN");
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.5);
  }

  Future<void> _speak(String text) async {
    await _tts.speak(text);
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) => setState(() {
            _textText = val.recognizedWords;
            if (val.finalResult) {
              _isListening = false;
              _sendCommand(_textText);
            }
          }),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  Future<void> _sendCommand(String text) async {
    try {
      final response = await http.post(
        Uri.parse('http://$_serverIp:8000/agent'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text, 'source': 'mobile'}),
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _aiResponse = data['response'];
        });
        _speak(_aiResponse);
      }
    } catch (e) {
      setState(() => _aiResponse = "Kết nối thất bại. Kiểm tra Server!");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: FadeInDown(child: const Text("JARVIS CORE v2.0", style: TextStyle(letterSpacing: 2, fontWeight: TextStyle.bold))),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.hub_outlined, color: JarvisMobileTheme.primaryColor), onPressed: _showSettings)
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          // AI Visualization Area
          Expanded(
            flex: 3,
            child: Center(
              child: AvatarGlow(
                animate: _isListening,
                glowColor: JarvisMobileTheme.primaryColor,
                duration: const Duration(milliseconds: 2000),
                repeat: true,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxType.circle,
                    border: Border.all(color: JarvisMobileTheme.primaryColor.withOpacity(0.5), width: 2),
                    gradient: RadialGradient(colors: [JarvisMobileTheme.primaryColor.withOpacity(0.2), Colors.transparent]),
                  ),
                  child: Icon(
                    _isListening ? Icons.graphic_eq : Icons.bolt,
                    size: 80,
                    color: JarvisMobileTheme.primaryColor,
                  ),
                ),
              ),
            ),
          ),
          
          // Response Display (Glassmorphism style)
          Expanded(
            flex: 2,
            child: FadeInUp(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: JarvisMobileTheme.cardColor,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: Colors.white10),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10)],
                ),
                child: Column(
                  children: [
                    Text("USER: $_textText", style: const TextStyle(color: Colors.white54, fontSize: 14)),
                    const Divider(color: Colors.white10, height: 20),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Text(
                          _aiResponse,
                          textAlign: BoxTextAlign.center,
                          style: const TextStyle(fontSize: 18, fontWeight: TextStyle.w300),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 30),
          
          // Micro Action Button
          Padding(
            padding: const EdgeInsets.only(bottom: 50),
            child: GestureDetector(
              onLongPress: _listen,
              onLongPressUp: () {
                if (_isListening) _listen();
              },
              child: FloatingActionButton.large(
                onPressed: _listen,
                backgroundColor: _isListening ? Colors.redAccent : JarvisMobileTheme.primaryColor,
                child: Icon(_isListening ? Icons.stop : Icons.mic, size: 40, color: Colors.black),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSettings() {
    _ipController.text = _serverIp;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: JarvisMobileTheme.cardColor,
        title: const Text("Cấu hình Neural Link"),
        content: TextField(
          controller: _ipController,
          decoration: const InputDecoration(hintText: "Nhập IP Server (vd: 192.168.1.15)"),
        ),
        actions: [
          TextButton(onPressed: () {
            setState(() => _serverIp = _ipController.text);
            Navigator.pop(context);
          }, child: const Text("LƯU", style: TextStyle(color: JarvisMobileTheme.primaryColor)))
        ],
      ),
    );
  }
}
