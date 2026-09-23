import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    title: "StreamRaaz OTT",
    home: MovieAppScreen(),
  ));
}

class MovieAppScreen extends StatefulWidget {
  const MovieAppScreen({super.key});

  @override
  State<MovieAppScreen> createState() => _MovieAppScreenState();
}

class _MovieAppScreenState extends State<MovieAppScreen> {
  bool isLoading = true;
  bool binariesInstalled = false;
  double downloadProgress = 0.0;
  String statusText = "Checking metadata...";
  Map<String, dynamic>? metadata;
  List<Map<String, dynamic>> moviesList = [];

  @override
  void initState() {
    super.initState();
    initMetadataAndBinaries();
  }

  Future<void> initMetadataAndBinaries() async {
    try {
      // 1. Read metadata.json
      final metaStr = await rootBundle.loadString('assets/metadata/metadata.json');
      final metaJson = jsonDecode(metaStr);
      setState(() {
        metadata = metaJson;
        statusText = "Checking binary packages (.dat)...";
      });

      // 2. Check local binary storage
      final docDir = await getApplicationDocumentsDirectory();
      final catalogFile = File(p.join(docDir.path, 'catalog.dat'));

      if (!await catalogFile.exists()) {
        setState(() {
          isLoading = false;
          binariesInstalled = false;
        });
      } else {
        await loadCatalogBinary(catalogFile);
      }
    } catch (e) {
      setState(() {
        statusText = "Error: $e";
        isLoading = false;
      });
    }
  }

  Future<void> downloadAndInstallBinaries() async {
    setState(() {
      isLoading = true;
      statusText = "Extracting and mounting .dat binaries...";
      downloadProgress = 0.1;
    });

    final docDir = await getApplicationDocumentsDirectory();
    List packages = metadata?['binary_packages'] ?? [];

    for (int i = 0; i < packages.length; i++) {
      final pkg = packages[i];
      final assetPath = pkg['asset_path'];
      final fileName = pkg['file_name'];

      final byteData = await rootBundle.load(assetPath);
      final destFile = File(p.join(docDir.path, fileName));
      await destFile.writeAsBytes(byteData.buffer.asUint8List());

      setState(() {
        downloadProgress = (i + 1) / packages.length;
        statusText = "Unpacking: $fileName (${(downloadProgress * 100).toInt()}%)";
      });
      await Future.delayed(const Duration(milliseconds: 300));
    }

    final catalogFile = File(p.join(docDir.path, 'catalog.dat'));
    await loadCatalogBinary(catalogFile);
  }

  Future<void> loadCatalogBinary(File file) async {
    Uint8List bytes = await file.readAsBytes();
    // Parse header '!4sI' (8 bytes) -> Magic bytes 'MOVI' + length
    Uint8List payload = bytes.sublist(8);
    String jsonStr = utf8.decode(payload);
    final catalog = jsonDecode(jsonStr);

    setState(() {
      moviesList = List<Map<String, dynamic>>.from(catalog['movies']);
      binariesInstalled = true;
      isLoading = false;
    });
  }

  void playMovie(Map<String, dynamic> movie) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141724),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text("Now Streaming: ${movie['title']}", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text("Connecting to Supabase Bucket 'Raaz'...", style: TextStyle(color: Colors.tealAccent.shade400, fontSize: 13)),
            const SizedBox(height: 20),
            LinearProgressIndicator(color: Colors.redAccent, backgroundColor: Colors.white10),
            const SizedBox(height: 20),
            Text("Stream Source: ${movie['stream_url']}", textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 11)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(ctx),
              icon: const Icon(Icons.close),
              label: const Text("Close Player"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090A10),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111422),
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.play_circle_fill, color: Colors.redAccent, size: 28),
            const SizedBox(width: 8),
            Text(metadata?['app_info']['app_name'] ?? "StreamRaaz OTT", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_suggest, color: Colors.tealAccent),
            onPressed: () => _showBinaryInfoDialog(),
          )
        ],
      ),
      body: isLoading
          ? _buildLoader()
          : !binariesInstalled
              ? _buildDownloadPrompt()
              : _buildMovieDashboard(),
    );
  }

  Widget _buildLoader() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.redAccent),
            const SizedBox(height: 20),
            Text(statusText, style: const TextStyle(color: Colors.white70, fontSize: 14)),
            if (downloadProgress > 0) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(value: downloadProgress, color: Colors.redAccent, backgroundColor: Colors.white12),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadPrompt() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF131726),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_download_rounded, size: 64, color: Colors.redAccent),
            const SizedBox(height: 16),
            const Text("Download Binary Assets", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              "App ko run karne ke liye metadata dwara required .dat binary files (catalog, Supabase module & graphics cache) download karna zaroori hai.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: downloadAndInstallBinaries,
              icon: const Icon(Icons.download),
              label: const Text("Download & Mount .DAT Files"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildMovieDashboard() {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        // Featured Banner
        Container(
          height: 200,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            image: const DecorationImage(
              image: NetworkImage("https://images.unsplash.com/photo-1574375927938-d5a98e8ffe85?w=800"),
              fit: BoxFit.cover,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withOpacity(0.9), Colors.transparent]),
            ),
            padding: const EdgeInsets.all(16),
            alignment: Alignment.bottomLeft,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("TRENDING NOW", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 11)),
                const Text("Cyber City 2077: Raaz Protocol", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () => playMovie(moviesList.first),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text("Watch Now"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                )
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text("Movies From .DAT Engine Catalog", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 12),
        // Movie Grid/List
        ...moviesList.map((movie) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(color: const Color(0xFF131726), borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(movie['thumb'], width: 55, height: 75, fit: BoxFit.cover),
                ),
                title: Text(movie['title'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text("${movie['genre']} • Rating: ${movie['rating']}", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                trailing: ElevatedButton(
                  onPressed: () => playMovie(movie),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent.shade700, shape: const CircleBorder(), padding: const EdgeInsets.all(10)),
                  child: const Icon(Icons.play_arrow, color: Colors.white),
                ),
              ),
            ))
      ],
    );
  }

  void _showBinaryInfoDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF151928),
        title: const Text("Mounted Metadata Modules", style: TextStyle(color: Colors.tealAccent, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Storage Bucket: ${metadata?['supabase_module']['bucket_name']}", style: const TextStyle(color: Colors.white70)),
            Text("Lua Driver: ${metadata?['supabase_module']['lua_driver']}", style: const TextStyle(color: Colors.white70)),
            const Divider(color: Colors.white24),
            const Text("Loaded .DAT Binaries:", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            ...?metadata?['binary_packages']?.map((pkg) => Text("• ${pkg['file_name']} (${pkg['size_kb']} KB)", style: const TextStyle(color: Colors.white54, fontSize: 12))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK", style: TextStyle(color: Colors.redAccent)))
        ],
      ),
    );
  }
}
