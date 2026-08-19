// lib/pages/community_admin_page.dart
import 'dart:io';

import 'package:athlo_app_novo/shared/theme.dart'; // ajuste o caminho conforme sua estrutura

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart' as fb_storage;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class CommunityAdminPage extends StatefulWidget {
  final String communityId;
  final String? communityName;

  const CommunityAdminPage({
    super.key,
    required this.communityId,
    this.communityName,
  });

  @override
  State<CommunityAdminPage> createState() => _CommunityAdminPageState();
}

class _CommunityAdminPageState extends State<CommunityAdminPage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final fb_storage.FirebaseStorage _storage = fb_storage.FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  String? _uid;
  bool _loadingAction = false;

  // Palet

  final Map<String, Map<String, String>> _profileCache = {};

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid;
  }

  bool _isOwner(Map<String, dynamic>? commData) {
    if (commData == null) return false;
    final owner = (commData['ownerId'] ?? commData['creatorId']) as String? ?? '';
    return _uid != null && _uid == owner;
  }

  bool _isAdmin(Map<String, dynamic>? commData) {
    if (commData == null) return false;
    final admins = (commData['admins'] is List)
        ? List<String>.from(commData['admins'])
        : <String>[];
    return _uid != null && admins.contains(_uid);
  }

  Future<Map<String, String>> _getProfile(String userId, {Map<String, dynamic>? memberDocData}) async {
    if (_profileCache.containsKey(userId)) return _profileCache[userId]!;

    String name = 'Usuário';
    String photo = '';

    try {
      final userDoc = await _db.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final d = userDoc.data()!;
        name = (d['nome'] ?? d['displayName'] ?? d['name'] ?? name).toString();
        photo = (d['fotoPerfil'] ?? d['photoUrl'] ?? d['photo'] ?? '').toString();
      }
    } catch (_) {}

    if ((name == 'Usuário' || name.isEmpty) && memberDocData != null) {
      final alt = (memberDocData['name'] ?? memberDocData['nome'] ?? memberDocData['displayName']) as String?;
      if (alt != null && alt.isNotEmpty) name = alt;
    }
    if ((photo.isEmpty) && memberDocData != null) {
      final altp = (memberDocData['photoUrl'] ?? memberDocData['fotoPerfil'] ?? memberDocData['photo']) as String?;
      if (altp != null && altp.isNotEmpty) photo = altp;
    }

    final result = {'name': name, 'photo': photo};
    _profileCache[userId] = result;
    return result;
  }
Future<void> _promoteToAdmin(String userId, Map<String, dynamic>? commData) async {
  if (!_isOwner(commData)) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Apenas o dono pode promover admins.')));
    return;
  }

  if (widget.communityId == null) return;

  setState(() => _loadingAction = true);
  try {
    final commRef = _db.collection('communities').doc(widget.communityId);

    // Atualiza o campo de admins
    await commRef.update({
      'admins': FieldValue.arrayUnion([userId]),
    });

    // Busca o nome do usuário promovido
    final userDoc = await _db.collection('users').doc(userId).get();
    final promotedName = (userDoc.data()?['nome'] as String?) ?? 'Usuário';

    // Envia mensagem de sistema ao chat
    await commRef.collection('messages').add({
      'text': '🔧 $promotedName agora é administrador da comunidade.',
      'senderId': 'system',
      'senderName': 'Sistema',
      'system': true,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Atualiza lastMessage e lastMessageTime
    await commRef.update({
      'lastMessage': '🔧 $promotedName agora é administrador da comunidade.',
      'lastMessageTime': FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Usuário promovido a admin.')));
  } catch (e) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Erro ao promover: $e')));
  } finally {
    setState(() => _loadingAction = false);
  }
}

  Future<void> _removeAdmin(String userId, Map<String, dynamic>? commData) async {
    setState(() => _loadingAction = true);
    try {
      final db = FirebaseFirestore.instance;
      final commRef = db.collection('communities').doc(widget.communityId);
      final me = FirebaseAuth.instance.currentUser;
      if (me == null) throw Exception('Usuário não autenticado.');

      await db.runTransaction((tx) async {
        final snapshot = await tx.get(commRef);
        if (!snapshot.exists) throw Exception('Comunidade não encontrada.');

        final data = snapshot.data() as Map<String, dynamic>? ?? {};
        final ownerId = (data['ownerId'] ?? data['creatorId'] ?? '') as String;

        if (userId == ownerId) {
          throw Exception('Não é possível remover o dono dos admins.');
        }
        if (me.uid != ownerId) {
          throw Exception('Apenas o dono pode remover admins.');
        }

        tx.update(commRef, {
          'admins': FieldValue.arrayRemove([userId]),
        });
      });

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Admin removido.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    } finally {
      if (mounted) setState(() => _loadingAction = false);
    }
  }

  Future<void> _removeMember(String memberId) async {
    try {
      final me = FirebaseAuth.instance.currentUser;
      if (me == null) return;

      final commRef = _db.collection('communities').doc(widget.communityId);
      final userRef = _db.collection('users').doc(memberId);

      await _db.runTransaction((tx) async {
        final commSnap = await tx.get(commRef);
        final userSnap = await tx.get(userRef);

        if (!commSnap.exists) throw Exception('Comunidade não encontrada');

        final commData = commSnap.data() as Map<String, dynamic>? ?? {};
        final ownerId = (commData['ownerId'] ?? commData['creatorId'] ?? '') as String;
        final admins = (commData['admins'] is List)
            ? List<String>.from(commData['admins'])
            : <String>[];

        final isOwner = me.uid == ownerId;
        final isAdmin = admins.contains(me.uid);

        if (!isOwner && !isAdmin) {
          throw Exception('Apenas administradores podem remover membros.');
        }

        tx.delete(commRef.collection('members').doc(memberId));
        tx.update(commRef, {'memberCount': FieldValue.increment(-1)});

        if (userSnap.exists) {
          final userData = userSnap.data() as Map<String, dynamic>? ?? {};

          if (userData.containsKey('joinedCommunities')) {
            tx.update(userRef, {
              'joinedCommunities': FieldValue.arrayRemove([widget.communityId])
            });
          }
          if (userData.containsKey('communities')) {
            tx.update(userRef, {
              'communities': FieldValue.arrayRemove([widget.communityId])
            });
          }

          final savedCommRef = _db
              .collection('users')
              .doc(memberId)
              .collection('savedCommunities')
              .doc(widget.communityId);
          tx.delete(savedCommRef);
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Membro removido com sucesso.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao remover: $e')),
        );
      }
    }
  }

  /// Propaga nome/imagem novos para savedCommunities (cliente).
  Future<void> _propagateCommunityUpdate(String communityId, String newName, String? newImage) async {
    final db = FirebaseFirestore.instance;
    try {
      // 1) collectionGroup update (todos com campo communityId)
      final usersWithSaved =
          await db.collectionGroup('savedCommunities').where('communityId', isEqualTo: communityId).get();

      WriteBatch batch = db.batch();
      int count = 0;
      for (final doc in usersWithSaved.docs) {
        batch.update(doc.reference, {
          'nome': newName,
          'imagem': newImage ?? '',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        count++;
        if (count >= 400) {
          await batch.commit();
          batch = db.batch();
          count = 0;
        }
      }
      if (count > 0) await batch.commit();

      // 2) varre users e atualiza savedCommunities dentro de cada usuário (caso saved tenha sido guardado com doc.id != auto e sem communityId)
      final usersSnap = await db.collection('users').get();
      batch = db.batch();
      count = 0;

      for (final userDoc in usersSnap.docs) {
        final savedColl = db.collection('users').doc(userDoc.id).collection('savedCommunities');

        // a) documentos onde 'communityId' == communityId (query local ao usuário)
        final qSnap = await savedColl.where('communityId', isEqualTo: communityId).get();
        for (final s in qSnap.docs) {
          batch.update(s.reference, {
            'nome': newName,
            'imagem': newImage ?? '',
            'updatedAt': FieldValue.serverTimestamp(),
          });
          count++;
          if (count >= 400) {
            await batch.commit();
            batch = db.batch();
            count = 0;
          }
        }

        // b) fallback: doc com id == communityId
        final fallbackDocRef = savedColl.doc(communityId);
        final fallbackDoc = await fallbackDocRef.get();
        if (fallbackDoc.exists) {
          batch.update(fallbackDocRef, {
            'nome': newName,
            'imagem': newImage ?? '',
            'updatedAt': FieldValue.serverTimestamp(),
          });
          count++;
          if (count >= 400) {
            await batch.commit();
            batch = db.batch();
            count = 0;
          }
        }
      }

      if (count > 0) await batch.commit();
    } catch (e) {
      debugPrint('Falha ao propagar savedCommunities: $e');
      // não interrompe a UX; logs apenas
    }
  }

  Future<void> _editName(String currentName, Map<String, dynamic>? commData) async {
    if (!_isOwner(commData)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Apenas o dono pode editar o nome.')));
      return;
    }

    final controller = TextEditingController(text: currentName);
    final res = await showDialog<String?>(
  context: context,
  builder: (_) => AlertDialog(
    backgroundColor: Colors.white,
    titleTextStyle: const TextStyle(
      color: AppPalette.primary,
      fontWeight: FontWeight.bold,
      fontSize: 18,
    ),
    contentTextStyle: const TextStyle(color: Colors.black87, fontSize: 14),
    title: const Text('Editar nome da comunidade'),
    content: TextField(
      controller: controller,
      decoration: const InputDecoration(hintText: 'Novo nome'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar', style: TextStyle(color: AppPalette.primary)),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, controller.text.trim()),
        child: const Text('Salvar', style: TextStyle(color: AppPalette.accent)),
      ),
    ],
  ),
);

    if (res != null && res.isNotEmpty) {
      setState(() => _loadingAction = true);
      try {
        await _db.collection('communities').doc(widget.communityId).update({'nome': res});
        await _propagateCommunityUpdate(widget.communityId, res, null);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nome atualizado.')));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao atualizar nome: $e')));
      } finally {
        setState(() => _loadingAction = false);
      }
    }
  }

  // Helper to parse image lists (compatible with List or comma-separated String)
  List<String> _parseImages(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) {
      return raw.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
    }
    if (raw is String && raw.trim().isNotEmpty) {
      return raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    }
    return [];
  }

  /// Upload unificado - retorna URL (e atualiza 'imagem' se isCarousel == false)
  Future<String?> _uploadCommunityImage(File file, {bool isCarousel = false}) async {
    setState(() => _loadingAction = true);
    try {
      final filename = isCarousel
          ? 'carousel_${DateTime.now().millisecondsSinceEpoch}_${widget.communityId}.jpg'
          : 'cover_${DateTime.now().millisecondsSinceEpoch}_${widget.communityId}.jpg';
      final path = 'communities/${widget.communityId}/$filename';
      final ref = _storage.ref().child(path);

      final uploadTask = ref.putFile(file, fb_storage.SettableMetadata(contentType: 'image/jpeg'));
      final snapshot = await uploadTask.whenComplete(() {});
      final url = await snapshot.ref.getDownloadURL();

      if (!isCarousel) {
        // atualiza imagem principal e propaga
        await _db.collection('communities').doc(widget.communityId).update({'imagem': url});
        // pega nome atual pra propagar
        final current = (await _db.collection('communities').doc(widget.communityId).get()).data() ?? {};
        final currentName = (current['nome'] as String?) ?? widget.communityName ?? '';
        await _propagateCommunityUpdate(widget.communityId, currentName, url);
      }

      return url;
    } on fb_storage.FirebaseException catch (e) {
      debugPrint('Erro storage upload: ${e.code} - ${e.message}');
      String msg = 'Erro ao atualizar imagem: ${e.message ?? e.code}';
      if (e.code == 'unauthorized' || e.code == 'permission-denied') {
        msg = 'Erro ao atualizar imagem: sem permissão (verifique as regras do Firebase Storage).';
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return null;
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao enviar imagem: $e')));
      return null;
    } finally {
      if (mounted) setState(() => _loadingAction = false);
    }
  }

  // Gerencia upload/remoção/reordenação das imagens de carrossel (campo: 'imagensExtras')
  Future<void> _manageCarouselDialog(Map<String, dynamic>? commData) async {
    if (!_isOwner(commData)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Apenas o dono pode editar o carrossel.')));
      return;
    }

    final initial = _parseImages(commData?['imagensExtras']);
    final List<String> urls = List<String>.from(initial);

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          Future<void> _pickAndUpload() async {
            try {
              final XFile? picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
              if (picked == null) return;
              final file = File(picked.path);
              setState(() => _loadingAction = true);
              final uploaded = await _uploadCommunityImage(file, isCarousel: true);
              if (uploaded != null) {
                setStateDialog(() => urls.add(uploaded));
              }
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao adicionar imagem: $e')));
            } finally {
              if (mounted) setState(() => _loadingAction = false);
            }
          }

          void _removeAt(int i) {
            setStateDialog(() => urls.removeAt(i));
          }

          return AlertDialog(
           backgroundColor: Colors.white,
              titleTextStyle: const TextStyle(
              color: AppPalette.primary,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
            title: const Text('Gerenciar carrossel (detalhes)'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (urls.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Nenhuma imagem ainda.'),
                    )
                  else
                    SizedBox(
                      height: 200,
                      child: ReorderableListView.builder(
                        onReorder: (oldIndex, newIndex) {
                          if (newIndex > oldIndex) newIndex -= 1;
                          final item = urls.removeAt(oldIndex);
                          urls.insert(newIndex, item);
                          setStateDialog(() {});
                        },
                        itemCount: urls.length,
                        itemBuilder: (context, index) {
                          final u = urls[index];
                          return ListTile(
                            key: ValueKey(u),
                            leading: SizedBox(width: 64, height: 64, child: Image.network(u, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image))),
                            title: Text('Imagem ${index + 1}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: AppPalette.accent),
                              onPressed: () => _removeAt(index),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _pickAndUpload,
                    icon: const Icon(Icons.add_photo_alternate),
                    label: const Text('Adicionar imagem'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppPalette.primary),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () async {
                  // salva em firestore campo 'imagensExtras'
                  try {
                    setState(() => _loadingAction = true);
                    await _db.collection('communities').doc(widget.communityId).update({'imagensExtras': urls});
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Carrossel atualizado.')));
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar carrossel: $e')));
                  } finally {
                    if (mounted) setState(() => _loadingAction = false);
                  }
                },
                child: const Text('Salvar'),
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> _changeCommunityImage(Map<String, dynamic>? commData) async {
    if (!_isOwner(commData)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Apenas o dono pode alterar a imagem.')));
      return;
    }

    try {
      final XFile? picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (picked == null) return;

      setState(() => _loadingAction = true);

      final file = File(picked.path);
      final url = await _uploadCommunityImage(file, isCarousel: false);
      if (url != null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Imagem atualizada.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao atualizar imagem: $e')));
    } finally {
      setState(() => _loadingAction = false);
    }
  }

  Future<void> _leaveCommunity() async {
    if (_uid == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
  backgroundColor: Colors.white,
  titleTextStyle: const TextStyle(
    color: AppPalette.primary,
    fontWeight: FontWeight.bold,
    fontSize: 18,
  ),
  contentTextStyle: const TextStyle(color: Colors.black87, fontSize: 14),
  title: const Text('Sair da comunidade'),
  content: const Text('Tem certeza de que deseja sair desta comunidade?'),
  actions: [
    TextButton(
      onPressed: () => Navigator.pop(ctx, false),
      child: const Text('Cancelar', style: TextStyle(color: AppPalette.primary)),
    ),
    TextButton(
      onPressed: () => Navigator.pop(ctx, true),
      child: const Text('Sair', style: TextStyle(color: AppPalette.accent)),
    ),
  ],
),
    );

    if (confirm != true) return;

    setState(() => _loadingAction = true);
    try {
      final db = FirebaseFirestore.instance;
      final commRef = db.collection('communities').doc(widget.communityId);
      final userRef = db.collection('users').doc(_uid);

      await db.runTransaction((tx) async {
        tx.delete(commRef.collection('members').doc(_uid));
        tx.update(commRef, {'memberCount': FieldValue.increment(-1)});
        tx.delete(userRef.collection('savedCommunities').doc(widget.communityId));
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Você saiu da comunidade.')),
        );
        Navigator.of(context).pop(); // volta ao sair
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro ao sair: $e')));
      }
    } finally {
      if (mounted) setState(() => _loadingAction = false);
    }
  }


  Future<void> _confirmAndDeleteCommunity(Map<String, dynamic>? commData) async {
    if (!_isOwner(commData)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Apenas o dono pode excluir a comunidade.')));
      return;
    }



    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir comunidade'),
        content: const Text('Tem certeza? Essa ação não pode ser desfeita. A comunidade será removida permanentemente.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Excluir', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => _loadingAction = true);
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('deleteCommunity');
      final res = await callable.call({'communityId': widget.communityId});

      // Resposta esperada: { success: true } (ajuste conforme sua função)
      final data = res.data;
      final success = (data is Map && data['success'] == true) || (data == true);
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Comunidade excluída com sucesso.')));
          Navigator.of(context).pop(); // volta do admin
        }
      } else {
        throw Exception('Erro ao excluir (resposta inesperada).');
      }
    } on FirebaseFunctionsException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao excluir: ${e.message}')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao excluir: $e')));
    } finally {
      if (mounted) setState(() => _loadingAction = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final commRef = _db.collection('communities').doc(widget.communityId);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppPalette.primary,
        title: Text(widget.communityName ?? 'Painel da Comunidade', style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: commRef.snapshots(),
        builder: (context, commSnap) {
          if (commSnap.hasError) return Center(child: Text('Erro: ${commSnap.error}'));
          if (!commSnap.hasData) return const Center(child: CircularProgressIndicator());

          final commDoc = commSnap.data!;
          if (!commDoc.exists) return const Center(child: Text('Comunidade não encontrada'));
          final commData = commDoc.data() as Map<String, dynamic>? ?? {};

          final communityName = commData['nome'] as String? ?? widget.communityName ?? 'Comunidade';
          final communityImage = commData['imagem'] as String? ?? '';
          final admins = (commData['admins'] is List) ? (commData['admins'] as List).cast<String>() : <String>[];
          final ownerId = (commData['ownerId'] ?? commData['creatorId']) as String? ?? '';

          final amIOwner = _uid != null && _uid == ownerId;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        if (communityImage.isNotEmpty)
                          CircleAvatar(radius: 36, backgroundImage: NetworkImage(communityImage))
                        else
                          CircleAvatar(radius: 36, child: Text(communityName.isNotEmpty ? communityName[0] : 'C')),

                        if (amIOwner)
                          Positioned(
                            right: -6,
                            bottom: -6,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () => _changeCommunityImage(commData),
                                child: Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: AppPalette.accent,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: const Icon(Icons.edit, color: Colors.white, size: 18),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),


                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  communityName,
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                                ),
                              ),
                              if (amIOwner)
                                IconButton(
                                  icon: const Icon(Icons.edit, color: AppPalette.primary),
                                  onPressed: () => _editName(communityName, commData),
                                  tooltip: 'Editar nome',
                                ),
                              if (amIOwner)
                                IconButton(
                                  icon: const Icon(Icons.photo_library, color: AppPalette.primary),
                                  onPressed: () => _manageCarouselDialog(commData),
                                  tooltip: 'Gerenciar carrossel',
                                ),
                                if (amIOwner)
                                IconButton(
                                  icon: const Icon(Icons.delete_forever, color: AppPalette.accent),
                                  onPressed: () => _confirmAndDeleteCommunity(commData),
                                  tooltip: 'Excluir comunidade',
                                ),
                              if (!amIOwner)
                                IconButton(
                                  icon: const Icon(Icons.logout, color:AppPalette.accent),
                                  tooltip: 'Sair da comunidade',
                                  onPressed: _leaveCommunity,
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          FutureBuilder<Map<String, String>>(
                            future: _getProfile(ownerId),
                            builder: (context, ownerSnap) {
                              final ownerName = ownerSnap.data?['name'] ?? ownerId;
                              return Text('Dono: $ownerName', style: const TextStyle(fontSize: 12, color: Colors.grey));
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: commRef.collection('members').orderBy('joinedAt', descending: false).snapshots(),
                  builder: (context, snap) {
                    if (snap.hasError) return Center(child: Text('Erro: ${snap.error}'));
                    if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                    final docs = snap.data!.docs;
                    if (docs.isEmpty) return const Center(child: Text('Sem membros ainda.'));

                    return ListView.separated(
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => Divider(color: AppPalette.light, height: 1),
                      itemBuilder: (context, idx) {
                        final doc = docs[idx];
                        final memberId = doc.id;
                        final data = doc.data() as Map<String, dynamic>? ?? {};
                        final isOwner = memberId == ownerId;
                        final isAdmin = admins.contains(memberId);

                        return FutureBuilder<Map<String, String>>(
                          future: _getProfile(memberId, memberDocData: data),
                          builder: (context, profileSnap) {
                            final profile = profileSnap.data ?? {'name': 'Usuário', 'photo': ''};
                            final displayName = profile['name'] ?? 'Usuário';
                            final photoUrl = profile['photo'] ?? '';

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              leading: CircleAvatar(
                                radius: 22,
                                backgroundColor: AppPalette.light,
                                backgroundImage: (photoUrl.isNotEmpty) ? NetworkImage(photoUrl) : null,
                                child: (photoUrl.isEmpty)
                                    ? Text(displayName.isNotEmpty ? displayName[0] : 'U', style: const TextStyle(color: Colors.white))
                                    : null,
                              ),
                              title: Row(
                                children: [
                                  Expanded(child: Text(displayName, style: const TextStyle(fontSize: 16, color: Colors.black))),
                                  if (isOwner)
                                    Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: AppPalette.primary, borderRadius: BorderRadius.circular(12)),
                                      child: const Text('Dono', style: TextStyle(color: Colors.white, fontSize: 12)),
                                    )
                                  else if (isAdmin)
                                    Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: AppPalette.green, borderRadius: BorderRadius.circular(12)),
                                      child: const Text('Admin do grupo', style: TextStyle(color: Colors.white, fontSize: 12)),
                                    ),
                                ],
                              ),
                              trailing: ((amIOwner) || (_isAdmin(commData))) && !isOwner
    ? PopupMenuButton<String>(
        onSelected: (val) async {
          if (val == 'promote') {
            await _promoteToAdmin(memberId, commData);
          } else if (val == 'demote') {
            await _removeAdmin(memberId, commData);
          } else if (val == 'kick') {
            await _removeMember(memberId);
          }
        },
        itemBuilder: (_) {
          final list = <PopupMenuEntry<String>>[];
          
          // Apenas o dono pode promover/rebaixar
          if (amIOwner) {
            if (!isAdmin) {
              list.add(const PopupMenuItem(value: 'promote', child: Text('Promover a admin')));
            } else {
              list.add(const PopupMenuItem(value: 'demote', child: Text('Remover admin')));
            }
            list.add(const PopupMenuDivider());
          }

          // Admins podem remover membros comuns (mas não admins nem dono)
          final isMyselfAdmin = _isAdmin(commData);
          if ((amIOwner) || (isMyselfAdmin && !isAdmin && !isOwner)) {
            list.add(const PopupMenuItem(value: 'kick', child: Text('Remover membro')));
          }

          return list;
        },
      )
    : null,
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
              if (!amIOwner)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.logout, color: Colors.white),
                  label: const Text('Sair da comunidade'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppPalette.accent,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _leaveCommunity,
                ),
              ),
              if (_loadingAction)
              const LinearProgressIndicator(
                color: AppPalette.primary,
                backgroundColor: AppPalette.light,
              ),
            ],
          );
        },
      ),
    );
  }
}
