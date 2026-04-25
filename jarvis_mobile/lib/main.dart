import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const JarvisMobileApp());
}

class JarvisMobileApp extends StatelessWidget {
  const JarvisMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jarvis Mobile',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const JarvisHomePage(),
    );
  }
}

class JarvisHomePage extends StatefulWidget {
  const JarvisHomePage({super.key});

  @override
  State<JarvisHomePage> createState() => _JarvisHomePageState();
}

class _JarvisHomePageState extends State<JarvisHomePage> {
  final TextEditingController _controller = TextEditingController();
  String _status = "Đang chờ lệnh...";
  String _response = "";
  // Thay đổi IP này thành IP máy tính của bạn (chạy ipconfig để xem)
  String _serverIp = "192.168.1.10";

  Future<void> _sendCommand(String text) async {
    setState(() {
      _status = "Đang gửi...";
    });

    try {
      final url = Uri.parse('http://$_serverIp:8000/agent');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': text,
          'source': 'mobile',
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _response = data['response'] ?? "Không có phản hồi";
          _status = "Đã xong!";
        });
      } else {
        setState(() {
          _status = "Lỗi Server: ${response.statusCode}";
        });
      }
    } catch (e) {
      setState(() {
        _status = "Lỗi kết nối: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Jarvis Remote Control"),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              _showIpDialog();
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Trạng thái: $_status", style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Text("IP Server: $_serverIp"),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _response.isEmpty ? "Phản hồi từ Jarvis sẽ hiện ở đây..." : _response,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: "Nhập lệnh cho Jarvis",
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () {
                    if (_controller.text.isNotEmpty) {
                      _sendCommand(_controller.text);
                      _controller.clear();
                    }
                  },
                ),
              ),
              onSubmitted: (value) {
                if (value.isNotEmpty) {
                  _sendCommand(value);
                  _controller.clear();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showIpDialog() {
    TextEditingController ipController = TextEditingController(text: _serverIp);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Cấu hình IP Server"),
        content: TextField(
          controller: ipController,
          decoration: const InputDecoration(hintText: "Ví dụ: 192.168.1.15"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Hủy"),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _serverIp = ipController.text;
              });
              Navigator.pop(context);
            },
            child: const Text("Lưu"),
          ),
        ],
      ),
    );
  }
}
