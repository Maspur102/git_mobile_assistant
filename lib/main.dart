import 'package:flutter/material.dart';
import 'package:process_run/shell.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:code_text_field/code_text_field.dart';
import 'package:highlight/languages/dart.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart'; // Tambahan

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
  CodeController? _codeController;
  
  String _output = "Status: Menunggu...";
  String? _savedToken;
  bool _isLoading = false;
  List<FileSystemEntity> _files = [];
  File? _selectedFile;
  String _currentPath = ""; // Variabel baru untuk simpan lokasi folder

  @override
  void initState() {
    super.initState();
    _initApp();
    _codeController = CodeController(text: "// Pilih file", language: dart);
  }

  Future<void> _initApp() async {
    await _loadToken();
    await _requestPermissions();
    // Set lokasi awal ke folder dokumen internal agar tidak kena Permission Denied
    final directory = await getApplicationDocumentsDirectory();
    setState(() {
      _currentPath = directory.path;
    });
    _refreshFiles();
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      await Permission.storage.request();
      await Permission.manageExternalStorage.request();
    }
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _savedToken = prefs.getString('github_token'));
  }

  Future<void> _saveToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('github_token', _tokenController.text);
    setState(() => _savedToken = _tokenController.text);
    _tokenController.clear();
    _showSnackBar("Token GitHub Tersimpan!");
  }

  Future<void> _refreshFiles() async {
    if (_currentPath.isEmpty) return;
    try {
      final directory = Directory(_currentPath);
      setState(() {
        _files = directory.listSync();
        _output = "Lokasi aktif: $_currentPath";
      });
    } catch (e) {
      setState(() => _output = "Gagal memuat file: Akses Ditolak ke $_currentPath. Coba pindah folder.");
    }
  }

  void _openFile(File file) async {
    try {
      final content = await file.readAsString();
      setState(() {
        _selectedFile = file;
        _codeController?.text = content;
      });
      _showSnackBar("Membuka: ${file.path.split('/').last}");
    } catch (e) {
      _showSnackBar("Gagal membaca file!");
    }
  }

  Future<void> _runGitCommand(String command) async {
    if (_savedToken == null || _savedToken!.isEmpty) {
      _showSnackBar("Login (Input Token) dulu!");
      return;
    }
    setState(() => _isLoading = true);
    try {
      // Jalankan git di dalam currentPath
      var result = await shell.cd(_currentPath).run(command);
      setState(() => _output = result.outText.isEmpty ? "Perintah dijalankan." : result.outText);
      _refreshFiles();
    } catch (e) {
      setState(() => _output = "Git Error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("GitMobile Assistant"),
          bottom: const TabBar(tabs: [Tab(text: "Git"), Tab(text: "Files"), Tab(text: "Editor")]),
        ),
        body: TabBarView(
          children: [
            _buildGitTab(),
            _buildFileTab(),
            _buildEditorTab(),
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
          const SizedBox(height: 10),
          TextField(controller: _repoUrlController, decoration: const InputDecoration(labelText: "URL Repo HTTPS", border: OutlineInputBorder())),
          const SizedBox(height: 10),
          ElevatedButton(onPressed: () => _runGitCommand("git clone ${_repoUrlController.text}"), child: const Text("CLONE REPO")),
          const Divider(height: 30),
          TextField(controller: _commitController, decoration: const InputDecoration(labelText: "Pesan Commit", border: OutlineInputBorder())),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () => _runGitCommand("git add . && git commit -m '${_commitController.text}' && git push origin main"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
            child: const Text("PUSH KE GITHUB"),
          ),
          const SizedBox(height: 15),
          Container(
            width: double.infinity, height: 120, padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8)),
            child: SingleChildScrollView(child: Text(_output, style: const TextStyle(color: Colors.greenAccent, fontSize: 11))),
          ),
        ],
      ),
    );
  }

  Widget _buildFileTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text("Folder: $_currentPath", style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _files.length,
            itemBuilder: (context, index) {
              final item = _files[index];
              return ListTile(
                leading: Icon(item is Directory ? Icons.folder : Icons.code, color: Colors.cyanAccent),
                title: Text(item.path.split('/').last),
                onTap: () {
                  if (item is File) {
                    _openFile(item);
                  } else if (item is Directory) {
                    setState(() => _currentPath = item.path);
                    _refreshFiles();
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEditorTab() {
    return Column(
      children: [
        Expanded(
          child: CodeTheme(
            data: const CodeThemeData(styles: monokaiSublimeTheme),
            child: CodeField(controller: _codeController!, textStyle: const TextStyle(fontSize: 14)),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          color: Colors.black26,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(onPressed: () async {
                if (_selectedFile != null) {
                  await _selectedFile!.writeAsString(_codeController!.text);
                  _showSnackBar("File Disimpan!");
                }
              }, icon: const Icon(Icons.save), label: const Text("Simpan")),
              IconButton(onPressed: () {
                // Tombol Back folder
                final parent = Directory(_currentPath).parent;
                setState(() => _currentPath = parent.path);
                _refreshFiles();
              }, icon: const Icon(Icons.arrow_upward)),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildTokenCard() {
    return Card(child: Padding(padding: const EdgeInsets.all(8), child: Column(children: [
      TextField(controller: _tokenController, decoration: const InputDecoration(hintText: "Paste GitHub Token (PAT)", prefixIcon: Icon(Icons.key)), obscureText: true),
      TextButton(onPressed: _saveToken, child: const Text("Set Token & Login"))
    ])));
  }
}