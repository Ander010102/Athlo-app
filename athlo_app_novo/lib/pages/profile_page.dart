import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class ProfilePage extends StatefulWidget {
  final String? userId; // se for null = perfil logado

  const ProfilePage({super.key, this.userId});

  @override
  State<ProfilePage> createState() => ProfilePageState();
}

class ProfilePageState extends State<ProfilePage> {
  final user = FirebaseAuth.instance.currentUser!;

  String nome = "";
  String idade = "";
  String bio = "Life is good";
  String fotoPerfil =
      "https://cdn-icons-png.flaticon.com/512/1077/1077114.png"; // padrão
  List<String> fotosGrid = List.generate(6, (_) => "");
  List<String> fotosPosts = [];

  bool carregando = true;
  bool editando = false;

  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _idadeController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  final ImagePicker _picker = ImagePicker();

  bool get isMeuPerfil => widget.userId == null || widget.userId == user.uid;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    try {
      final String uid = widget.userId ?? user.uid;

      final docRef = FirebaseFirestore.instance.collection("users").doc(uid);
      final doc = await docRef.get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          nome = data["nome"] ?? "";
          idade = data["idade"] ?? "";
          bio = data["bio"] ?? "Life is good";
          fotoPerfil = data["fotoPerfil"] ?? fotoPerfil;
          fotosGrid =
              List<String>.from(data["fotosGrid"] ?? List.generate(6, (_) => ""));
        });
      }

      // carregar posts do usuário (coleção "posts")
      final postsSnap = await FirebaseFirestore.instance
          .collection("posts")
          .where("userId", isEqualTo: uid)
          .orderBy("timestamp", descending: true)
          .get();

      setState(() {
        fotosPosts = postsSnap.docs
            .map((doc) => doc.data()["imageUrl"] as String? ?? "")
            .where((url) => url.isNotEmpty)
            .toList();
        carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => carregando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar perfil: $e')),
      );
    }
  }

  Future<String> _uploadImage(File image, String path) async {
    final ref =
        FirebaseStorage.instance.ref().child("users/${user.uid}/$path");
    await ref.putFile(image);
    return await ref.getDownloadURL();
  }

  Future<void> _trocarFotoPerfil() async {
    if (!isMeuPerfil) return;

    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      File imageFile = File(picked.path);

      String url = await _uploadImage(imageFile, "profile.jpg");

      setState(() => fotoPerfil = url);

      await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .update({"fotoPerfil": url});
    }
  }

  Future<void> _adicionarFotoGrid(int index) async {
    if (!isMeuPerfil) return;

    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      File imageFile = File(picked.path);

      String url = await _uploadImage(imageFile, "post_$index.jpg");

      setState(() => fotosGrid[index] = url);

      await FirebaseFirestore.instance.collection("users").doc(user.uid).update({
        "fotosGrid": fotosGrid,
      });
    }
  }

  Future<void> _salvarPerfil() async {
    if (!isMeuPerfil) return;

    setState(() => carregando = true);

    nome = _nomeController.text.isNotEmpty ? _nomeController.text : nome;
    idade = _idadeController.text.isNotEmpty ? _idadeController.text : idade;
    bio = _bioController.text.isNotEmpty ? _bioController.text : bio;

    await FirebaseFirestore.instance.collection("users").doc(user.uid).update({
      "nome": nome,
      "idade": idade,
      "bio": bio,
      "fotoPerfil": fotoPerfil,
      "fotosGrid": fotosGrid,
    });

    setState(() {
      editando = false;
      carregando = false;
    });
  }

  Widget _buildFotoGrid(int index) {
    return GestureDetector(
      onTap: () => _adicionarFotoGrid(index),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          color: fotosGrid[index].isEmpty
              ? Colors.grey.shade200
              : Colors.transparent,
        ),
        child: fotosGrid[index].isEmpty
            ? const Icon(Icons.add, color: Colors.grey)
            : Image.network(fotosGrid[index], fit: BoxFit.cover),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (carregando) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Topo
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text("Perfil",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  if (isMeuPerfil)
                    IconButton(
                      icon: const Icon(Icons.settings),
                      onPressed: () {},
                    ),
                ],
              ),

              // Foto de perfil
              GestureDetector(
                onTap: _trocarFotoPerfil,
                child: CircleAvatar(
                  radius: 60,
                  backgroundImage: NetworkImage(fotoPerfil),
                ),
              ),
              const SizedBox(height: 12),

              // Nome
              Text(
                nome.isNotEmpty ? nome : "Usuário",
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),

              // Bio
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  bio.isNotEmpty ? bio : "Life is good",
                  style: const TextStyle(color: Colors.black54),
                ),
              ),

              if (idade.isNotEmpty) Text("Idade: $idade"),

              const SizedBox(height: 12),

              // Botões (apenas no meu perfil)
              if (isMeuPerfil)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          editando = true;
                          _nomeController.text = nome;
                          _idadeController.text = idade;
                          _bioController.text = bio;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6A1B9A),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("Editar Perfil",
                          style: TextStyle(color: Colors.white)),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade700,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("Compartilhar Perfil",
                          style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),

              const SizedBox(height: 20),

              // Grid de fotos do perfil
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: fotosGrid.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  itemBuilder: (_, i) => _buildFotoGrid(i),
                ),
              ),

              // Seção de posts
              if (fotosPosts.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text("Posts",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: fotosPosts.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  itemBuilder: (_, i) =>
                      Image.network(fotosPosts[i], fit: BoxFit.cover),
                ),
              ],

              // Campos de edição
              if (editando && isMeuPerfil) ...[
                const Divider(),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _nomeController,
                        decoration: const InputDecoration(labelText: "Nome"),
                      ),
                      TextField(
                        controller: _idadeController,
                        decoration: const InputDecoration(labelText: "Idade"),
                        keyboardType: TextInputType.number,
                      ),
                      TextField(
                        controller: _bioController,
                        decoration: const InputDecoration(labelText: "Bio"),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _salvarPerfil,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6A1B9A)),
                        child: const Text("Salvar",
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
