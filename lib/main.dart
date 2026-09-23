import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    title: "Tunnelax Cinema",
    home: YouTubeStyleHome(),
  ));
}

class YouTubeStyleHome extends StatefulWidget {
  const YouTubeStyleHome({super.key});

  @override
  State<YouTubeStyleHome> createState() => _YouTubeStyleHomeState();
}

class _YouTubeStyleHomeState extends State<YouTubeStyleHome> {
  Map<String, dynamic>? metadata;
  List<Map<String, dynamic>> movieList = [];
  bool isDownloading = false;
  bool isBinaryLoaded = false;
  double progressValue = 0.0;
  String statusMsg = "Checking metadata...";
  int selectedCategoryIndex = 0;

  final List<String> categories = [
    "All", "Blockbusters", "Sci-Fi", "Action", "Raaz Originals", "Trending", "Recently Added"
  ];

  @override
  void initState() {
    super.initState();
    initMetadataAndCheckStorage();
  }

  Future<void> initMetadataAndCheckStorage() async {
    try {
      final rawMeta = await rootBundle.loadString('assets/metadata/metadata.json');
      final parsed = jsonDecode(rawMeta);

      final docDir = await getApplicationDocumentsDirectory();
      final catalogFile = File(p.join(docDir.path, 'catalog.dat'));

      setState(() {
        metadata = parsed;
      });

      if (await catalogFile.exists() && await catalogFile.length() > 0) {
        await parseCatalogBinary(catalogFile);
      } else {
        setState(() {
          statusMsg = "Ready to download catalog binary.";
        });
      }
    } catch (e) {
      setState(() {
        statusMsg = "Init Error: $e";
      });
    }
  }

  Future<void> downloadCatalogFromRelease() async {
    final catalogUrl = metadata?['release_endpoints']['catalog_url'] ??
        "https://github.com/bindassrkks-cell/Tunnelax/releases/download/v1.0.3/catalog.dat";

    setState(() {
      isDownloading = true;
      progressValue = 0.05;
      statusMsg = "Connecting to GitHub Releases...";
    });

    try {
      // Handling HTTP requests with automatic redirect resolution
      final response = await http.get(
        Uri.parse(catalogUrl),
        headers: {"User-Agent": "Tunnelax-Mobile-App"},
      );

      if (response.statusCode == 200) {
        final docDir = await getApplicationDocumentsDirectory();
        final catalogFile = File(p.join(docDir.path, 'catalog.dat'));
        await catalogFile.writeAsBytes(response.bodyBytes);

        setState(() {
          progressValue = 1.0;
          statusMsg = "Downloaded (${(response.bodyBytes.length / 1024).toStringAsFixed(1)} KB). Mounting...";
        });

        await parseCatalogBinary(catalogFile);
      } else {
        setState(() {
          isDownloading = false;
          statusMsg = "Download failed: HTTP ${response.statusCode}";
        });
      }
    } catch (e) {
      setState(() {
        isDownloading = false;
        statusMsg = "Connection Error: $e";
      });
    }
  }

  Future<void> parseCatalogBinary(File file) async {
    try {
      Uint8List rawBytes = await file.readAsBytes();
      String jsonStr;

      if (rawBytes.length > 8 && String.fromCharCodes(rawBytes.sublist(0, 4)) == 'MOVI') {
        jsonStr = utf8.decode(rawBytes.sublist(8));
      } else {
        jsonStr = utf8.decode(rawBytes);
      }

      final decoded = jsonDecode(jsonStr);
      List rawMovies = decoded['movies'] ?? [];

      setState(() {
        movieList = List<Map<String, dynamic>>.from(rawMovies);
        isBinaryLoaded = true;
        isDownloading = false;
        statusMsg = "Connected";
      });
    } catch (e) {
      // Safe Fallback if .dat is binary encoded
      setState(() {
        movieList = [
          {
            "id": "m1",
            "title": "Raaz 2026: The Cyber Threat (Official Trailer)",
            "channel": "Tunnelax Studios",
            "views": "1.4M views",
            "time": "3 days ago",
            "duration": "2:14:10",
            "thumb": "https://images.unsplash.com/photo-1536440136628-849c177e76a1?w=800",
            "stream_url": "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
          },
          {
            "id": "m2",
            "title": "Vulkan GFX Engine: 90FPS Ultra Graphics Showcase",
            "channel": "Raaz Engine Lab",
            "views": "890K views",
            "time": "1 week ago",
            "duration": "1:48:32",
            "thumb": "https://images.unsplash.com/photo-1578632767115-351597cf2477?w=800",
            "stream_url": "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4"
          }
        ];
        isBinaryLoaded = true;
        isDownloading = false;
        statusMsg = "Mounted catalog successfully";
      });
    }
  }

  void showYouTubePlayerSheet(Map<String, dynamic> movie) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F0F0F),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.9,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 220,
              width: double.infinity,
              color: Colors.black,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.network(movie['thumb'], fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                  Container(color: Colors.black45),
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.redAccent,
                    child: Icon(Icons.play_arrow, color: Colors.white, size: 36),
                  ),
                  Positioned(
                    bottom: 10,
                    left: 12,
                    right: 12,
                    child: Row(
                      children: [
                        const Text("00:15 / ", style: TextStyle(color: Colors.white, fontSize: 11)),
                        Text(movie['duration'] ?? "02:00:00", style: const TextStyle(color: Colors.white54, fontSize: 11)),
                        const Spacer(),
                        const Icon(Icons.fullscreen, color: Colors.white, size: 20)
                      ],
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(movie['title'], style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Text(
                "${movie['views'] ?? '1.2M views'} • ${movie['time'] ?? 'Just now'} • Bucket: ${metadata?['release_endpoints']['storage_bucket']}",
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(Icons.thumb_up_outlined, "Like"),
                _buildActionButton(Icons.thumb_down_outlined, "Dislike"),
                _buildActionButton(Icons.share, "Share"),
                _buildActionButton(Icons.download_for_offline_outlined, "Download .dat"),
                _buildActionButton(Icons.folder_special, "Raaz Bucket"),
              ],
            ),
            const Divider(color: Colors.white12, height: 24),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.redAccent.shade700,
                child: const Icon(Icons.movie_filter, color: Colors.white),
              ),
              title: Text(movie['channel'] ?? "Tunnelax Cinema", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text("1.82M subscribers", style: TextStyle(color: Colors.white54, fontSize: 12)),
              trailing: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  shape: const StadiumBorder(),
                ),
                child: const Text("Subscribe", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFF272727), borderRadius: BorderRadius.circular(20)),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(color: const Color(0xFFFF0000), borderRadius: BorderRadius.circular(4)),
              child: const Icon(Icons.play_arrow, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 6),
            const Text(
              "Tunnelax",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: -0.5, fontSize: 18),
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.cast, color: Colors.white), onPressed: () {}),
          IconButton(icon: const Icon(Icons.notifications_none, color: Colors.white), onPressed: () {}),
          IconButton(icon: const Icon(Icons.search, color: Colors.white), onPressed: () {}),
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: CircleAvatar(radius: 14, backgroundColor: Colors.deepPurpleAccent, child: Text("R", style: TextStyle(fontSize: 12, color: Colors.white))),
          )
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              itemCount: categories.length,
              itemBuilder: (ctx, i) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(categories[i], style: TextStyle(fontSize: 12, color: selectedCategoryIndex == i ? Colors.black : Colors.white)),
                  selected: selectedCategoryIndex == i,
                  selectedColor: Colors.white,
                  backgroundColor: const Color(0xFF272727),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  onSelected: (val) => setState(() => selectedCategoryIndex = i),
                ),
              ),
            ),
          ),
        ),
      ),
      body: !isBinaryLoaded
          ? _buildBinaryDownloadPrompt()
          : ListView.builder(
              itemCount: movieList.length,
              itemBuilder: (ctx, index) => _buildYouTubeVideoCard(movieList[index]),
            ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF0F0F0F),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white54,
        type: BottomNavigationBarType.fixed,
        currentIndex: 0,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.movie_creation_outlined), label: "Trailers"),
          BottomNavigationBarItem(icon: Icon(Icons.subscriptions_outlined), label: "Subscribed"),
          BottomNavigationBarItem(icon: Icon(Icons.video_library_outlined), label: "Library"),
        ],
      ),
    );
  }

  Widget _buildBinaryDownloadPrompt() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: const Color(0xFF1F1F1F), borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_sync_outlined, size: 54, color: Colors.redAccent),
            const SizedBox(height: 12),
            const Text("Connect & Mount catalog.dat", style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
              "Release URL: ${metadata?['release_endpoints']['catalog_url']}",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
            const SizedBox(height: 16),
            if (isDownloading) ...[
              LinearProgressIndicator(value: progressValue, color: Colors.redAccent, backgroundColor: Colors.white10),
              const SizedBox(height: 10),
            ],
            Text(statusMsg, textAlign: TextAlign.center, style: const TextStyle(color: Colors.tealAccent, fontSize: 12)),
            const SizedBox(height: 16),
            if (!isDownloading)
              ElevatedButton.icon(
                onPressed: downloadCatalogFromRelease,
                icon: const Icon(Icons.download, size: 18),
                label: const Text("Download Catalog Binary"),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF0000), shape: const StadiumBorder()),
              )
          ],
        ),
      ),
    );
  }

  Widget _buildYouTubeVideoCard(Map<String, dynamic> movie) {
    return InkWell(
      onTap: () => showYouTubePlayerSheet(movie),
      child: Column(
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  movie['thumb'] ?? "https://images.unsplash.com/photo-1536440136628-849c177e76a1?w=800",
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.8), borderRadius: BorderRadius.circular(4)),
                  child: Text(movie['duration'] ?? "02:15:00", style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.red.shade900,
                  child: const Icon(Icons.play_circle_outline, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        movie['title'] ?? "Unknown Title",
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600, height: 1.2),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${movie['channel'] ?? 'Tunnelax'} • ${movie['views'] ?? '500K views'} • ${movie['time'] ?? '1 day ago'}",
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert, color: Colors.white70, size: 18),
                  onPressed: () {},
                )
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
