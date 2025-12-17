import 'package:flutter/material.dart';
import 'package:process_run/shell.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

void main() {
  runApp(const GitMobileApp());
}

class GitMobileApp extends StatelessWidget {
  const GitMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        textTheme: GoogleFonts.firaCodeTextTheme(ThemeData.dark().textTheme),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.cyanAccent,
          brightness: Brightness.dark,
        ),
      ),
      home: const GitDashboard(),
    );
  }
}

class GitDashboard extends StatefulWidget {
  const GitDashboard({super.key});

  @override
  State<GitDashboard> createState() => _GitDashboardState();
}

class _GitDashboardState extends State<GitDashboard> {
  final TextEditingController _messageController = TextEditingController();
  final shell = Shell();
  String _statusOutput = "Klik refresh untuk cek status Git.";
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      checkStatus();
    } else {
      _statusOutput = "Mode Web Terdeteksi: Fitur Terminal dinonaktifkan. Silakan build ke APK untuk mencoba fitur Git.";
    }
  }

  Future<void> checkStatus() async {
    if (kIsWeb) return;

    setState(() => _isLoading = true);
    try {
      var results = await shell.run('git status -s');
      setState(() {
        _statusOutput = results.outText.isEmpty 
            ? "✅ Status: Clean (Tidak ada perubahan)." 
            : results.outText;
      });
    } catch (e) {
      setState(() => _statusOutput = "❌ Error: Perintah Git gagal dijalankan.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> runGitFlow() async {
    if (kIsWeb) {
      _showSnackBar("Gagal: Browser tidak diizinkan mengakses Terminal!");
      return;
    }

    if (_messageController.text.trim().isEmpty) {
      _showSnackBar("Isi pesan commit dulu!");
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Menjalankan urutan perintah git di sistem
      await shell.run('git add .');
      await shell.run('git commit -m "${_messageController.text}"');
      await shell.run('git push origin main');
      
      _messageController.clear();
      await checkStatus();
      _showSnackBar("🚀 Berhasil push ke GitHub!");
    } catch (e) {
      _showErrorDialog(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Git Error"),
        content: Text("Detail Error:\n$error"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("GitMobile Dashboard"),
        actions: [
          IconButton(onPressed: checkStatus, icon: const Icon(Icons.refresh_rounded))
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.cyanAccent.withOpacity(0.3))
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _statusOutput,
                    style: const TextStyle(color: Colors.greenAccent, fontSize: 13),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _messageController,
              enabled: !kIsWeb,
              decoration: InputDecoration(
                labelText: kIsWeb ? "Input dinonaktifkan di Web" : "Pesan Commit",
                prefixIcon: const Icon(Icons.edit_note),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: (_isLoading || kIsWeb) ? null : runGitFlow,
                icon: _isLoading 
                  ? const CircularProgressIndicator(strokeWidth: 2)
                  : const Icon(Icons.cloud_upload),
                label: Text(_isLoading ? "SABAR..." : "PUSH KE GITHUB"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}