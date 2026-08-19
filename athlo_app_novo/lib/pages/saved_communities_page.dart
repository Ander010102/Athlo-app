// saved_communities_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// IMPORT: ajuste o caminho se necessário
import 'chat_page.dart';

class SavedCommunitiesPage extends StatefulWidget {
  const SavedCommunitiesPage({super.key});

  @override
  State<SavedCommunitiesPage> createState() => _SavedCommunitiesPageState();
}

class _SavedCommunitiesPageState extends State<SavedCommunitiesPage> {
  String searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: Text('Você precisa entrar para ver suas comunidades')),
      );
    }

    final savedRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('savedCommunities')
        .orderBy('joinedAt', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas comunidades'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // 🔍 Campo de busca
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              onChanged: (value) => setState(() => searchQuery = value.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Buscar comunidade...',
                prefixIcon: const Icon(Icons.search, color: Colors.black54),
                filled: true,
                fillColor: Colors.grey.shade200,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // 🔽 Lista das comunidades
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: savedRef.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Erro: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Center(
                      child: Text('Você ainda não salvou nenhuma comunidade.'));
                }

                // Aplica o filtro de busca (nome contém o texto)
                final filteredDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>? ?? {};
                  final nome = (data['nome'] ?? '').toString().toLowerCase();
                  return nome.contains(searchQuery);
                }).toList();

                if (filteredDocs.isEmpty) {
                  return const Center(
                      child: Text('Nenhuma comunidade encontrada.'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredDocs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final savedDoc = filteredDocs[index];
                    final data = savedDoc.data() as Map<String, dynamic>? ?? {};
                    final commId = (data['communityId'] ?? savedDoc.id).toString();
                    final nome = (data['nome'] ?? 'Comunidade').toString();
                    final imagem = (data['imagem'] ?? '').toString();
                    final lastReadAt = data['lastReadAt'] as Timestamp?;

                    final communityRef =
                        FirebaseFirestore.instance.collection('communities').doc(commId);

                    final userSavedRef = FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .collection('savedCommunities')
                        .doc(commId);

                    return StreamBuilder<DocumentSnapshot>(
                      stream: communityRef.snapshots(),
                      builder: (context, commSnap) {
                        if (commSnap.hasError) return const SizedBox.shrink();
                        if (!commSnap.hasData) {
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const LinearProgressIndicator(),
                          );
                        }

                        final commDoc = commSnap.data!;
                        if (!commDoc.exists) return const SizedBox.shrink();

                        final commData =
                            commDoc.data() as Map<String, dynamic>? ?? {};

                        // ✅ Atualiza nome e imagem com dados reais do Firestore
                        final commNome = (commData['nome'] ?? nome).toString();
                        final commImagem = (commData['imagem'] ?? imagem).toString();

                        int memberCount = 0;
                        if (commData['memberCount'] is int) {
                          memberCount = commData['memberCount'] as int;
                        } else if (commData['members'] is List) {
                          memberCount = (commData['members'] as List).length;
                        }

                        final messagesRef = FirebaseFirestore.instance
                            .collection('communities')
                            .doc(commId)
                            .collection('messages');

                        Stream<int> getUnreadCountStream() {
                          Query query;
                          if (lastReadAt != null) {
                            query = messagesRef
                                .where('timestamp', isGreaterThan: lastReadAt)
                                .orderBy('timestamp');
                          } else {
                            query = messagesRef.orderBy('timestamp');
                          }

                          return query.snapshots().map((snap) {
                            final unreadDocs = snap.docs.where((d) {
                              final m = d.data() as Map<String, dynamic>? ?? {};
                              final senderId = (m['senderId'] as String?) ?? '';
                              return senderId != user.uid;
                            }).toList();
                            return unreadDocs.length;
                          });
                        }

                        return StreamBuilder<int>(
                          stream: getUnreadCountStream(),
                          builder: (context, msgSnap) {
                            final isLoadingMsgs =
                                msgSnap.connectionState == ConnectionState.waiting;
                            final unreadCount = msgSnap.data ?? 0;

                            return InkWell(
                              onTap: () async {
                                final currentUser = FirebaseAuth.instance.currentUser;
                                if (currentUser == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Faça login para abrir a comunidade.')),
                                  );
                                  return;
                                }

                                try {
                                  // verifica se ainda é membro
                                  final memberDoc = await FirebaseFirestore.instance
                                      .collection('communities')
                                      .doc(commId)
                                      .collection('members')
                                      .doc(currentUser.uid)
                                      .get();

                                  if (!memberDoc.exists) {
                                    // usuário não é mais membro — tenta deletar savedCommunities localmente
                                    try {
                                      await userSavedRef.delete();
                                    } catch (_) {}
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text('Você não é mais membro desta comunidade.')),
                                    );
                                    return;
                                  }

                                  // se é membro, atualiza lastReadAt e navega
                                  await userSavedRef.set({
                                    'lastReadAt': FieldValue.serverTimestamp(),
                                  }, SetOptions(merge: true));

                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ChatPage(
                                        communityId: commId,
                                        nomeComunidade: commNome, // ✅ usa o nome atualizado
                                      ),
                                    ),
                                  );
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Erro ao verificar membro: $e')),
                                  );
                                }
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: commImagem.isNotEmpty
                                          ? Image.network(
                                              commImagem,
                                              width: 56,
                                              height: 56,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  Container(
                                                      width: 56,
                                                      height: 56,
                                                      color: Colors.grey),
                                            )
                                          : Container(
                                              width: 56,
                                              height: 56,
                                              color: Colors.grey),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            commNome,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '$memberCount membros',
                                            style: const TextStyle(
                                                color: Color(0xFF2ED573)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isLoadingMsgs)
                                      const SizedBox(width: 16)
                                    else if (unreadCount > 0)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEBCC6E),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          unreadCount.toString(),
                                          style: const TextStyle(
                                            color: Colors.black,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      )
                                    else
                                      const SizedBox(width: 16),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.arrow_forward_ios,
                                        color: Colors.white70, size: 16),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
