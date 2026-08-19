import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'community_detail_page.dart';
import 'search_page.dart';

class HomeFeedPage extends StatefulWidget {
  const HomeFeedPage({super.key});

  @override
  State<HomeFeedPage> createState() => _HomeFeedPageState();
}

class _HomeFeedPageState extends State<HomeFeedPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Fallback temporário caso o Firestore esteja vazio
  final List<String> defaultVideos = const [
    "https://youtube.com/shorts/b3OeMC5iKb8?si=FL5swtMhWM869MGn", // Jiu-Jitsu
    "https://youtube.com/shorts/vc2wRHYr9cc?si=VC8ayj1DkOPQZV-z", // Kung Fu
    "https://youtube.com/shorts/shNivqqCo4Y?si=9dEihEYiVre7tMcr", // Muay Thai
  ];

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            "Você precisa estar logado para ver o feed.",
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchPage()),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('posts')
            .where('isForYou', isEqualTo: true)
            .where('type', isEqualTo: 'video')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          // Erro de conexão ou permissão
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Erro ao carregar vídeos.',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          // Carregando dados
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          // Caso o banco ainda não tenha posts
          if (docs.isEmpty) {
            return PageView.builder(
              scrollDirection: Axis.vertical,
              itemCount: defaultVideos.length,
              itemBuilder: (context, index) {
                final controller = WebViewController()
                  ..setJavaScriptMode(JavaScriptMode.unrestricted)
                  ..loadRequest(Uri.parse(defaultVideos[index]));
                return SafeArea(child: WebViewWidget(controller: controller));
              },
            );
          }

          // Se houver posts, monta o feed dinâmico
          return PageView.builder(
            scrollDirection: Axis.vertical,
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final post = docs[index].data() as Map<String, dynamic>;
              final videoUrl = post['videoUrl'] ?? '';
              final controller = WebViewController()
                ..setJavaScriptMode(JavaScriptMode.unrestricted)
                ..loadRequest(Uri.parse(videoUrl));

              return SafeArea(
                child: Stack(
                  children: [
                    WebViewWidget(controller: controller),
                    Positioned(
                      bottom: 40,
                      left: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (post['authorName'] != null)
                            Text(
                              '@${post['authorName']}',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 16),
                            ),
                          if (post['caption'] != null)
                            Text(
                              post['caption'],
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 14),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
