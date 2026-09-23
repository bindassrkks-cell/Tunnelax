import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: EngineDashboard(),
  ));
}

class EngineDashboard extends StatefulWidget {
  const EngineDashboard({super.key});

  @override
  State<EngineDashboard> createState() => _EngineDashboardState();
}

class _EngineDashboardState extends State<EngineDashboard> {
  Map<String, dynamic>? metadata;
  String dbStatus = "Connecting...";
  List<String> luaLogs = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    initializeSystem();
  }

  Future<void> initializeSystem() async {
    try {
      // 1. Read metadata.json
      final metaStr = await rootBundle.loadString('assets/metadata.json');
      final parsedMeta = jsonDecode(metaStr);

      // 2. Setup SQLite Database from Assets
      final docDir = await getApplicationDocumentsDirectory();
      final dbFile = File(p.join(docDir.path, 'app_storage.db'));
      if (!await dbFile.exists()) {
        final byteData = await rootBundle.load('assets/database/app_storage.db');
        await dbFile.writeAsBytes(byteData.buffer.asUint8List());
      }
      final database = await openDatabase(dbFile.path);
      final List<Map<String, dynamic>> records = await database.query('system_config');
      final status = records.isNotEmpty ? records.first['val'].toString() : 'Empty DB';

      // 3. Read Lua Scripts
      final bootLua = await rootBundle.loadString('assets/scripts/bootstrap.lua');
      final patchLua = await rootBundle.loadString('assets/scripts/patcher.lua');

      setState(() {
        metadata = parsedMeta;
        dbStatus = status;
        luaLogs = [
          bootLua.split('\n').firstWhere((l) => l.contains("Engine Initialized"), orElse: () => "Bootstrapped"),
          patchLua.split('\n').firstWhere((l) => l.contains("Patch Applied"), orElse: () => "Patched"),
        ];
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        dbStatus = "Init Error: $e";
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F111A),
      appBar: AppBar(
        title: const Text("App Engine Core", style: TextStyle(fontFamily: 'EngineFont')),
        backgroundColor: const Color(0xFF1A1D2B),
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoCard("App Metadata", [
                    "Name: ${metadata?['app_metadata']['app_name']}",
                    "Package: ${metadata?['app_metadata']['package_id']}",
                    "Target API: ${metadata?['app_metadata']['target_api']}",
                  ]),
                  const SizedBox(height: 12),
                  _buildInfoCard("Graphics Module", [
                    "Renderer: ${metadata?['graphics_module']['renderer']}",
                    "Target FPS: ${metadata?['graphics_module']['target_fps']}",
                    "Compression: ${metadata?['graphics_module']['texture_compression']}",
                    "Resolution Scale: ${metadata?['graphics_module']['resolution_scale']}",
                  ]),
                  const SizedBox(height: 12),
                  _buildInfoCard("Database Status", [
                    "Path: assets/database/app_storage.db",
                    "Live Read: $dbStatus",
                  ]),
                  const SizedBox(height: 12),
                  _buildInfoCard("Scripting Engine", [
                    "Engine: ${metadata?['scripting_module']['engine']}",
                    "Log 1: ${luaLogs.isNotEmpty ? luaLogs[0] : 'None'}",
                    "Log 2: ${luaLogs.length > 1 ? luaLogs[1] : 'None'}",
                  ]),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoCard(String title, List<String> lines) {
    return Card(
      color: const Color(0xFF1E2235),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.cyanAccent, fontSize: 16, fontWeight: FontWeight.bold)),
            const Divider(color: Colors.white24),
            ...lines.map((l) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(l, style: const TextStyle(color: Colors.white, fontSize: 13)),
                )),
          ],
        ),
      ),
    );
  }
}
