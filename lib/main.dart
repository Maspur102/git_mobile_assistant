import 'package:flutter/material.dart';
import 'package:process_run/shell.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

void main() => runApp(const GitMobileApp());

class GitMobileApp extends StatelessWidget {
  const GitMobileApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        textTheme: GoogleFonts.firaCodeTextTheme(ThemeData.dark().textTheme),
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.cyanAccent, brightness: Brightness.dark),
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
  final shell = Shell();
  final TextEditingController _tokenController = TextEditingController();
  final TextEditingController _repoUrlController = TextEditingController();
  final TextEditingController _commitController = TextEditingController();
  
  String _output = "Terminal: Siap.";
  String? _savedToken;
  bool _isLoading = false;
  List<FileSystemEntity> _files = [];

  @override
  void initState() {
    super.initState();
    _loadToken();
    _refreshFiles();
  }

  // FITUR: Load Token
  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _savedToken = prefs.getString('github_token'));
  }

  Future<void> _saveToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('github_token', _tokenController.text);
    setState(() => _savedToken = _tokenController.text);
    _tokenController.clear();
    _showSnackBar("Token tersimpan!");
  }

  // FITUR: File Explorer Sederhana
  Future<void> _refreshFiles() async {
    try {
      final directory = Directory(Directory.current.path);
      setState(() {
        _files = directory.listSync().take(10).toList(); // Ambil 10 item saja
      });
    } catch (e) {
      print("Gagal scan folder: $e");
    }
  }

  // FITUR: Clone Repo
  Future<void> _cloneRepo() async {
    if (_savedToken == null) return _showSnackBar("Isi Token di tab Login dulu!");
    setState(() => _isLoading = true);
    try {
      String rawUrl = _repoUrlController.text.replaceFirst("https://", "");
      String authUrl = "https://$_savedToken@$rawUrl";
      await shell.run('git clone $authUrl');
      setState(() => _output = "✅ Clone Berhasil!");
      _refreshFiles();
    } catch (e) {
      setState(() => _output = "❌ Gagal Clone: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // FITUR: Push
  Future<void> _pushChanges() async {
    if (_savedToken == null) return _showSnackBar("Login dulu!");
    setState(() => _isLoading = true);
    try {
      await shell.run('git add .');
      await shell.run('git commit -m "${_commitController.text}"');
      await shell.run('git push origin main');
      setState(() => _output = "🚀 Push Berhasil!");
      _commitController.clear();
    } catch (e) {
      setState(() => _output = "❌ Gagal Push: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("GitMobile Pro"),
          bottom: const TabBar(
            tabs: [Tab(icon: Icon(Icons.code), text: "Git"), Tab(icon: Icon(Icons.folder), text: "Files")],
          ),
        ),
        body: TabBarView(
          children: [
            // TAB 1: GIT OPERATIONS
            _buildGitTab(),
            // TAB 2: FILE EXPLORER
            _buildFileTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildGitTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildTokenCard(),
          const SizedBox(height: 15),
          TextField(controller: _repoUrlController, decoration: const InputDecoration(labelText: "URL Repo (HTTPS)", border: OutlineInputBorder())),
          const SizedBox(height: 8),
          ElevatedButton.icon(onPressed: _isLoading ? null : _cloneRepo, icon: const Icon(Icons.download), label: const Text("CLONE REPOSITORY")),
          const Divider(height: 40),
          TextField(controller: _commitController, decoration: const InputDecoration(labelText: "Pesan Commit", border: OutlineInputBorder())),
          const SizedBox(height: 8),
          ElevatedButton.icon(onPressed: _isLoading ? null : _pushChanges, icon: const Icon(Icons.upload), label: const Text("COMMIT & PUSH"), style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black)),
          const SizedBox(height: 20),
          _buildTerminalOutput(),
        ],
      ),
    );
  }

  Widget _buildFileTab() {
    return ListView.builder(
      itemCount: _files.length,
      itemBuilder: (context, index) {
        final item = _files[index];
        return ListTile(
          leading: Icon(item is Directory ? Icons.folder : Icons.insert_drive_file, color: Colors.cyanAccent),
          title: Text(item.path.split('/').last),
          subtitle: Text(item is Directory ? "Folder" : "File"),
        );
      },
    );
  }

  Widget _buildTokenCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(_savedToken == null ? "🔑 Status: Belum Login" : "✅ Status: Terhubung"),
            const SizedBox(height: 8),
            TextField(controller: _tokenController, decoration: const InputDecoration(hintText: "Paste GitHub Token (PAT)"), obscureText: true),
            TextButton(onPressed: _saveToken, child: const Text("Update Token")),
          ],
        ),
      ),
    );
  }

  Widget _buildTerminalOutput() {
    return Container(
      width: double.infinity, height: 120, padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8)),
      child: SingleChildScrollView(child: Text(_output, style: const TextStyle(color: Colors.greenAccent, fontSize: 12))),
    );
  }
}