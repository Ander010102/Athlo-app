import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'community_detail_page.dart';
import 'create_community_page.dart';
import 'main_navigation.dart'; // <- ADICIONADO
import 'saved_communities_page.dart';


class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  String searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          Container(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Campo de busca
                  TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      hintText: "Busque sua comunidade",
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.grey[200],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() => searchQuery = value.toLowerCase());
                    },
                  ),

                  const SizedBox(height: 40),

                  const Text(
                    'Comunidades Sugeridas:',
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('communities')
                          .orderBy('criadoEm', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return const Center(
                              child: Text("Erro ao carregar comunidades"));
                        }

                        final communities = snapshot.data?.docs ?? [];

                        final filtered = communities.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final nome =
                              (data['nome'] ?? '').toString().toLowerCase();
                          return nome.contains(searchQuery);
                        }).toList();

                        // Se estiver vazio, mostra mensagem + botões
                        if (filtered.isEmpty) {
                          return ListView(
                            padding: const EdgeInsets.only(bottom: 140),
                            children: [
                              const SizedBox(height: 40),
                              const Center(
                                child: Text(
                                  "Nenhuma comunidade encontrada",
                                  style: TextStyle(color: Colors.black54),
                                ),
                              ),
                              const SizedBox(height: 40),
                              _buildCriarComunidadeButton(context),
                              _buildMinhasComunidadesButton(),
                            ],
                          );
                        }

                        final limited = filtered.take(6).toList();

                        return ListView.builder(
                          padding: const EdgeInsets.only(bottom: 140),
                          itemCount: limited.length + 2,
                          itemBuilder: (context, index) {
                            if (index == limited.length) {
                              return _buildCriarComunidadeButton(context);
                            }

                            if (index == limited.length + 1) {
                              return _buildMinhasComunidadesButton();
                            }

                            final data =
                                limited[index].data() as Map<String, dynamic>;

                            final nome = (data['nome'] ?? 'Sem nome').toString();
                            final imagem = (data['imagem'] ??
                                    'https://via.placeholder.com/150?text=Comunidade')
                                .toString();

                            final membersCount = (data['memberCount'] is int)
                                ? data['memberCount'] as int
                                : int.tryParse(data['memberCount']?.toString() ?? '0') ?? 0;

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: GestureDetector(
                                onTap: () {
                                  // Abrir CommunityDetailPage DENTRO do MainNavigation
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => MainNavigation(
                                        currentIndex: 1, // mantém a aba de busca selecionada
                                        child: CommunityDetailPage(
                                          communityId: limited[index].id,
                                          nome: nome,
                                          imagem: imagem,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black,
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12, horizontal: 12),
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          imagem,
                                          width: 56,
                                          height: 56,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              Container(
                                            width: 56,
                                            height: 56,
                                            color: Colors.grey[300],
                                            child: const Icon(Icons.groups,
                                                color: Colors.grey),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              nome,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              '$membersCount membros',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: Color(0xFF2ED573),
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Logo fixa no rodapé
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 35.0),
              child: Image.asset(
                'assets/images/logo.png',
                width: 80,
                height: 80,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCriarComunidadeButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18.0, left: 4.0),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CreateCommunityPage(),
            ),
          );
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: const [
            Text(
              'Criar comunidade',
              style: TextStyle(
                fontSize: 19.93,
                color: Color(0xFFFF914D),
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.double_arrow, color: Color(0xFFFF914D)),
          ],
        ),
      ),
    );
  }

    Widget _buildMinhasComunidadesButton() {
  return Padding(
    padding: const EdgeInsets.only(top: 12.0, left: 4.0),
    child: GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MainNavigation(currentIndex: 2),
          ),
        );
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: const [
          Text(
            'Minhas comunidades',
            style: TextStyle(
              fontSize: 19.93,
              color: Colors.black,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(width: 8),
          Icon(Icons.chevron_right, color: Colors.black),
        ],
      ),
    ),
  );
}

}
