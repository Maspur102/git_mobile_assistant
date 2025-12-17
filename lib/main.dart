import 'package:flutter/material.dart';
import 'package:process_run/shell.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:code_text_field/code_text_field.dart';
import 'package:highlight/languages/dart.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';
import 'package:permission_handler/permission_handler.dart';

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
  
  String _output = "Status: Menunggu Izin...";
  String? _savedToken;
  bool _isLoading = false;
  List<FileSystemEntity> _files = [];
  File? _selectedFile;

  @override
  void initState() {
    super.initState();
    _requestPermissions(); // Minta izin saat startup
    _loadToken();
    _codeController = CodeController(text: "// Pilih file untuk edit", language: dart);
  }

  // Minta Izin Storage Android
  Future<void> _requestPermissions() async {
    var status = await Permission.manageExternalStorage.request();
    if (status.isGranted) {
      _refreshFiles();
    } else {
      setState(() => _output = "Izin Storage Ditolak! Aplikasi tidak bisa bekerja.");
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
    _showSnackBar("Login Berhasil!");
  }

  Future<void> _refreshFiles() async {
    try {
      final directory = Directory(Directory.current.path);
      setState(() {
        _files = directory.listSync();
        _output = "Lokasi: ${directory.path}";
      });
    } catch (e) {
      setState(() => _output = "Gagal memuat file. Pastikan izin diberikan.");
    }
  }

  void _openFile(File file) async {
    final content = await file.readAsString();
    setState(() {
      _selectedFile = file;
      _codeController?.text = content;
    });
    _showSnackBar("Membuka: ${file.path.split('/').last}");
  }

  Future<void> _runGitCommand(String command) async {
    if (_savedToken == null || _savedToken!.isEmpty) {
      _showSnackBar("Masukkan Token PAT dulu!");
      return;
    }
    
    setState(() => _isLoading = true);
    try {
      // Menjalankan command lewat shell
      var result = await shell.run(command);
      setState(() => _output = result.outText.isEmpty ? "Sukses menjalankan command." : result.outText);
      _refreshFiles();
    } catch (e) {
      setState(() => _output = "Error Git: Cek apakah Git terinstal & Token benar.");
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
          title: const Text("GitMobile Pro v2"),
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
    return ListView.builder(
      itemCount: _files.length,
      itemBuilder: (context, index) {
        final item = _files[index];
        return ListTile(
          leading: Icon(item is Directory ? Icons.folder : Icons.code, color: Colors.cyanAccent),
          title: Text(item.path.split('/').last),
          onTap: () { if (item is File) _openFile(item); },
        );
      },
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
                  _showSnackBar("Tersimpan!");
                }
              }, icon: const Icon(Icons.save), label: const Text("Simpan")),
              IconButton(onPressed: _refreshFiles, icon: const Icon(Icons.refresh)),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildTokenCard() {
    return Card(child: Padding(padding: const EdgeInsets.all(8), child: Column(children: [
      TextField(controller: _tokenController, decoration: const InputDecoration(hintText: "GitHub Token (PAT)", prefixIcon: Icon(Icons.key)), obscureText: true),
      TextButton(onPressed: _saveToken, child: const Text("Set Login Token"))
    ])));
  }
}