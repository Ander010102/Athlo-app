// chat_page_with_videos.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:athlo_app_novo/shared/theme.dart'; 
import 'package:athlo_app_novo/widgets/app_dialogs.dart';

import 'community_admin_page.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:audioplayers/audioplayers.dart';

/// -----------------------
/// Constantes de estilo
/// -----------------------
const Color kAppBarColor = Colors.black;
const Color kBodyBackground = Colors.white;
const Color kCommunityAvatarBg = Color(0xFF424242);
const Color kMemberCountColor = Color(0xFF2ED573);

const Color kReceivedBubbleColor = Color(0xFFE5E5E5);
const Color kSentBubbleColor = Color(0xFF4A4A3C);
const Color kReceivedTextColor = Colors.black87;
const Color kSentTextColor = Colors.white;

const Color kInputBgColor = Color(0xFFE5E5E5);
const Color kPlaceholderColor = Color(0xFFA1A1A1);
const Color kAvatarFallback = Color(0xFFDCC7F7);

class ChatPage extends StatefulWidget {
  final String communityId;
  final String nomeComunidade;

  const ChatPage({
    super.key,
    required this.communityId,
    required this.nomeComunidade,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Se você usa outra API do pacote `record`, adapte o tipo/uso conforme necessário.
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  bool _isRecording = false;
  String? _senderNameCache;

  String? _communityPhoto;
  int? _memberCount;

  String? _currentRecordingPath; // guarda caminho temporário durante gravação

  // Key para detectar se o pointer up ocorreu dentro do botão
  final GlobalKey _micKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _ensureSignedInAnonymously();
    _loadCommunityMeta();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _ensureSignedInAnonymously() async {
  final auth = FirebaseAuth.instance;
  User? user;

  // 🔎 Garante que existe um usuário auth (anônimo se necessário)
  if (auth.currentUser == null) {
    final userCred = await auth.signInAnonymously();
    user = userCred.user;
  } else {
    user = auth.currentUser;
  }

  if (user == null) return;

  final memberRef = FirebaseFirestore.instance
      .collection('communities')
      .doc(widget.communityId)
      .collection('members')
      .doc(user.uid);

  final memberDoc = await memberRef.get();

  // NÃO recriar automático o memberDoc: se não existe, o usuário não é membro.
  if (!memberDoc.exists) {
    // usuário não é membro — não permitir acesso automático ao chat.
    if (!mounted) return;

    // mostra feedback e volta (pode mudar para navegar pra uma rota específica)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Você não é membro desta comunidade. Toque em Entrar para participar.')),
    );

    // navega pra trás (fecha ChatPage)
    Navigator.of(context).maybePop();
    return;
  }

  // Se existir, tudo ok — carrega meta (mantém o resto do fluxo)
  // (Se você tiver mais inicializações que dependem do membro, coloque aqui)
}

Future<void> _sairDaComunidade() async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;

  final communityRef =
      FirebaseFirestore.instance.collection('communities').doc(widget.communityId);
  final memberRef = communityRef.collection('members').doc(uid);
  final userSavedRef = FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('savedCommunities')
      .doc(widget.communityId);

  try {
    await FirebaseFirestore.instance.runTransaction((tx) async {
      tx.delete(memberRef);
      tx.delete(userSavedRef);
      tx.update(communityRef, {
        'memberCount': FieldValue.increment(-1),
      });
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Você saiu da comunidade.')),
    );
    Navigator.of(context).pop(); // 🔹 Fecha o chat
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Erro ao sair: $e')),
    );
  }
}

  Future<bool> isCurrentUserAdmin() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return false;

  final doc = await FirebaseFirestore.instance
      .collection('communities')
      .doc(widget.communityId)
      .get();

  final data = doc.data();
  if (data == null) return false;

  final admins = List<String>.from(data['admins'] ?? []);
    return admins.contains(user.uid);
  }


  Future<void> _loadCommunityMeta() async {
  try {
    final communityRef = FirebaseFirestore.instance.collection('communities').doc(widget.communityId);
    final doc = await communityRef.get();

    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      String? photo = data['imagem'] as String? ?? data['photo'] as String?;

      // 🔹 Primeiro tenta pegar o número de membros salvos diretamente no doc
      int count = 0;
      if (data['memberCount'] is int) {
        count = data['memberCount'];
      } 
      // 🔹 Se não houver, tenta ver se há uma lista no campo "members"
      else if (data['members'] is List) {
        count = (data['members'] as List).length;
      } 
      // 🔹 Se não houver lista, tenta contar a subcoleção "members"
      else {
        final membersSnap = await communityRef.collection('members').get();
        count = membersSnap.docs.length;
      }

      setState(() {
        _communityPhoto = photo;
        _memberCount = count;
      });
    }
  } catch (e) {
    debugPrint('Erro ao carregar meta: $e');
  }
}

  String _slugify(String input) {
    final s = input
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '_');
    return s.isEmpty ? 'comunidade' : s;
  }

  Future<String> _getSenderName() async {
    if (_senderNameCache != null && _senderNameCache!.isNotEmpty) return _senderNameCache!;
    final user = FirebaseAuth.instance.currentUser;
    final authName = user?.displayName?.trim();
    if (authName != null && authName.isNotEmpty) {
      _senderNameCache = authName;
      return authName;
    }
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final data = doc.data();
        final n = (data?['nome'] as String?)?.trim();
        if (n != null && n.isNotEmpty) {
          _senderNameCache = n;
          return n;
        }
      } catch (_) {}
    }
    _senderNameCache = 'Usuário';
    return 'Usuário';
  }

Future<void> _enviarMensagem({
  String? text,
  String? imageUrl,
  String? videoUrl,
  String? videoThumbUrl,
  String? audioUrl,
}) async {
  if ((text == null || text.trim().isEmpty) &&
      imageUrl == null &&
      videoUrl == null &&
      audioUrl == null) return;

  if (FirebaseAuth.instance.currentUser == null) {
    await _ensureSignedInAnonymously();
  }

  final senderName = await _getSenderName();
  final sender = FirebaseAuth.instance.currentUser!;

  try {
    String? senderPhoto;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(sender.uid)
          .get();
      senderPhoto = (doc.data()?['fotoPerfil'] as String?) ?? null;
    } catch (_) {
      senderPhoto = null;
    }

    final Map<String, dynamic> payload = {
      'text': text,
      'imageUrl': imageUrl,
      'videoUrl': videoUrl,
      'videoThumbUrl': videoThumbUrl,
      'audioUrl': audioUrl,
      'senderId': sender.uid,
      'senderName': senderName,
      'senderPhoto': senderPhoto,
      'timestamp': FieldValue.serverTimestamp(),
    };

    try {
      await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('messages')
          .add(payload);

      // 🔹 Atualiza informações no documento da comunidade
      try {
        final communityRef = FirebaseFirestore.instance
            .collection('communities')
            .doc(widget.communityId);

        await communityRef.update({
          'lastMessage': text ?? '[mídia]',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'messageCount': FieldValue.increment(1),
        });
      } catch (e) {
        debugPrint('Erro ao atualizar metadados da comunidade: $e');
      }

      _controller.clear();
      _focusNode.requestFocus();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Sem permissão para enviar mensagens — você pode não ser mais membro desta comunidade.'),
        ));
        Navigator.of(context).maybePop();
        return;
      }
      rethrow;
    }
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Erro ao enviar: $e')),
    );
  }
}

  /// Retorna contentType baseado na extensão / MIME sniffing
  String _contentTypeFromPath(String path, {String? fallback}) {
    final mimeType = lookupMimeType(path);
    if (mimeType != null) return mimeType;
    return fallback ?? 'application/octet-stream';
  }

  Future<String?> _uploadFileToStorage({
  required String localPath,
  required String folder,
  String? forcedContentType,
}) async {
  try {
    final file = File(localPath);
    if (!await file.exists()) return null;
    final fileName = localPath.split('/').last;
    final ref = _storage.ref().child(
  '   communities/${widget.communityId}/$folder/${DateTime.now().millisecondsSinceEpoch}_$fileName',
    );


    // Detecta tipo automaticamente ou usa forcedContentType se informado
    String contentType;
    if (forcedContentType != null) {
      contentType = forcedContentType;
    } else if (folder == 'images') {
      contentType = 'image/jpeg';
    } else if (folder == 'videos') {
      contentType = 'video/mp4';
    } else if (folder == 'audios') {
      contentType = 'audio/m4a';
    } else {
      contentType = _contentTypeFromPath(localPath);
    }

    final metadata = SettableMetadata(contentType: contentType);

    final uploadTask = ref.putFile(file, metadata);
    final snapshot = await uploadTask.whenComplete(() {});
    final url = await snapshot.ref.getDownloadURL();
    return url;
  } catch (e) {
    if (!mounted) return null;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Falha no upload: $e')),
    );
    return null;
  }
}

  Future<String?> _uploadBytesToStorage({
    required Uint8List bytes,
    required String folder,
    required String filename,
    required String contentType,
  }) async {
    try {
      final ref = _storage.ref().child('communities/${widget.communityId}/$folder/${DateTime.now().millisecondsSinceEpoch}_$filename');
      final metadata = SettableMetadata(contentType: contentType);
      final snapshot = await ref.putData(bytes, metadata);
      final url = await snapshot.ref.getDownloadURL();
      return url;
    } catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Falha no upload (bytes): $e')));
      return null;
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (picked == null) return;
      final url = await _uploadFileToStorage(localPath: picked.path, folder: 'images');
      if (url != null) await _enviarMensagem(imageUrl: url);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao selecionar imagem: $e')));
    }
  }

  Future<void> _pickVideo() async {
    try {
      final XFile? picked = await _picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(minutes: 2));
      if (picked == null) return;

      // 1) gerar thumbnail localmente (bytes)
      Uint8List? thumbBytes;
      try {
        final data = await VideoThumbnail.thumbnailData(
          video: picked.path,
          imageFormat: ImageFormat.PNG,
          maxWidth: 720,
          quality: 80,
        );
        if (data != null) thumbBytes = data;
      } catch (e) {
        // fallback: sem thumbnail local
        thumbBytes = null;
      }

      // 2) upload do vídeo com contentType correto
      final videoContentType = _contentTypeFromPath(picked.path, fallback: 'video/mp4');
      final videoUrl = await _uploadFileToStorage(localPath: picked.path, folder: 'videos', forcedContentType: videoContentType);

      // 3) upload da thumbnail (se gerada) como png (putData)
      String? thumbUrl;
      if (thumbBytes != null) {
        // usar nome derivado do vídeo para facilitar organização
        final filename = picked.path.split('/').last.replaceAll(RegExp(r'\W+'), '');
        thumbUrl = await _uploadBytesToStorage(bytes: thumbBytes, folder: 'thumbnails', filename: '${filename}_thumb.png', contentType: 'image/png');
      }

      // 4) enviar mensagem com ambos (videoUrl e videoThumbUrl)
      if (videoUrl != null) {
        await _enviarMensagem(videoUrl: videoUrl, videoThumbUrl: thumbUrl);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro: não foi possível enviar o vídeo.')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao selecionar vídeo: $e')));
    }
  }

  /// Abre menu de anexos (galeria foto / galeria vídeo)
  Future<void> _pickAttachment() async {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo),
                title: const Text("Foto da galeria"),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickImage();
                },
              ),
              ListTile(
                leading: const Icon(Icons.video_library),
                title: const Text("Vídeo da galeria"),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickVideo();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Captura direta da câmera (foto). Para vídeo, descomente a parte indicada.
  Future<void> _captureMedia() async {
    try {
      final XFile? captured = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
      if (captured != null) {
        final url = await _uploadFileToStorage(localPath: captured.path, folder: 'images');
        if (url != null) await _enviarMensagem(imageUrl: url);
      }
      // Se quiser capturar vídeo direto da câmera, use:
      // final XFile? capturedVideo = await _picker.pickVideo(source: ImageSource.camera, maxDuration: const Duration(minutes: 2));
      // if (capturedVideo != null) { upload como vídeo... }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao abrir câmera: $e')));
    }
  }

  // -------------- gravação: START / STOP+SEND / CANCEL --------------
  Future<void> _startRecord() async {
    if (_isRecording) return; // já gravando
    try {
      final micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permita o microfone para gravar áudio.')),
        );
        return;
      }

      final dir = await getTemporaryDirectory();
      _currentRecordingPath = '${dir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _currentRecordingPath!,
      );

      setState(() => _isRecording = true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao iniciar gravação: $e')));
      _currentRecordingPath = null;
      setState(() => _isRecording = false);
    }
  }

  Future<void> _stopAndSendRecord() async {
    if (!_isRecording && _currentRecordingPath == null) return;
    try {
      final path = await _recorder.stop();
      setState(() => _isRecording = false);

      final effectivePath = path ?? _currentRecordingPath;
      if (effectivePath == null) {
        _currentRecordingPath = null;
        return;
      }

      final file = File(effectivePath);
      if (!await file.exists()) {
        _currentRecordingPath = null;
        return;
      }

      final url = await _uploadFileToStorage(localPath: effectivePath, folder: 'audios', forcedContentType: 'audio/m4a');
      if (url != null) await _enviarMensagem(audioUrl: url);

      // apaga arquivo temporário local
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {}
      _currentRecordingPath = null;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao finalizar gravação: $e')));
      _currentRecordingPath = null;
      setState(() => _isRecording = false);
    }
  }

  Future<void> _cancelRecord() async {
    try {
      // para o recorder (se estiver gravando)
      try {
        await _recorder.stop();
      } catch (_) {}

      setState(() => _isRecording = false);

      // remove arquivo temporário se existir
      if (_currentRecordingPath != null) {
        final file = File(_currentRecordingPath!);
        try {
          if (await file.exists()) await file.delete();
        } catch (_) {}
        _currentRecordingPath = null;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao cancelar gravação: $e')));
    }
  }
  // ------------------------------------------------------------------

  // BUILD MESSAGE BUBBLE: received left with circular avatar + name above, sent right dark
  Widget _buildMessageBubble({
    required bool isMe,
    required String senderId,
    required String senderName,
    String? senderPhoto,
    String? text,
    String? imageUrl,
    String? videoUrl,
    String? videoThumbUrl,
    String? audioUrl,
  }) {
    final maxWidth = MediaQuery.of(context).size.width * 0.72;

    if (senderId == 'system') {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            text ?? '',
            style: const TextStyle(
              color: Colors.white,
              fontStyle: FontStyle.italic,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

    final bubble = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe ? kSentBubbleColor : kReceivedBubbleColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(senderName, style: const TextStyle(fontSize: 12, color: Color(0xFF333333))),
              ),
            if (text != null && text.trim().isNotEmpty)
              Text(text, style: TextStyle(color: isMe ? kSentTextColor : kReceivedTextColor)),
            if (imageUrl != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ImageFullScreen(imageUrl: imageUrl),
                      ));
                    },
                    child: CachedNetworkImage(
                      key: ValueKey(imageUrl),
                      imageUrl: imageUrl,
                      width: maxWidth * 0.95,
                      fit: BoxFit.cover,
                      placeholder: (c, s) => Container(
                        color: Colors.grey.shade300,
                        width: maxWidth * 0.95,
                        height: (maxWidth * 0.95) * 0.6,
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (c, s, e) => Container(
                        color: Colors.grey.shade300,
                        width: maxWidth * 0.95,
                        height: (maxWidth * 0.95) * 0.6,
                        child: const Center(child: Icon(Icons.broken_image)),
                      ),
                    ),
                  ),
                ),
              ),
            if (videoUrl != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: VideoBubble(
                  key: ValueKey(videoUrl),
                  url: videoUrl,
                  thumbUrl: videoThumbUrl,
                  maxWidth: maxWidth * 0.95,
                  isDark: isMe,
                ),
              ),
            if (audioUrl != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _AudioBubble(url: audioUrl, isDark: isMe, player: _player),
              ),
          ],
        ),
      ),
    );

    if (isMe) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [bubble],
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // circular avatar for received messages
            CircleAvatar(
              radius: 17,
              backgroundColor: kAvatarFallback,
              backgroundImage: (senderPhoto != null && senderPhoto.isNotEmpty) ? NetworkImage(senderPhoto) : null,
            ),
            const SizedBox(width: 10),
            bubble,
            const Spacer(),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    print('🆔 communityId recebido: ${widget.communityId}');
    return Scaffold(
      backgroundColor: kBodyBackground,
 appBar: AppBar(
  backgroundColor: kAppBarColor,
  elevation: 0,
  leading: IconButton(
    icon: const Icon(Icons.arrow_back, color: Colors.white),
    onPressed: () => Navigator.of(context).pop(),
  ),
  titleSpacing: 0,

  // 🔹 Exibe o nome, imagem e contador de membros
  title: StreamBuilder<DocumentSnapshot>(
    stream: FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .snapshots(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return const Text('Carregando...', style: TextStyle(color: Colors.white));
      }

      if (!snapshot.data!.exists) {
        return const Text('Comunidade não encontrada', style: TextStyle(color: Colors.white));
      }

      final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
      final photoUrl = (data['imagem'] ?? data['photo']) as String?;
      final ownerId = (data['ownerId'] ?? data['creatorId'] ?? '') as String;
      final adminsList = (data['admins'] is List)
          ? (data['admins'] as List).cast<String>()
          : <String>[];

      final uid = FirebaseAuth.instance.currentUser?.uid;
      final bool isAdmin = uid != null && (uid == ownerId || adminsList.contains(uid));

      // Contagem de membros
      final membersField = data['members'];
      int memberCount = 0;
      if (membersField is List) {
        memberCount = membersField.length;
      } else if (membersField is Map) {
        memberCount = membersField.length;
      } else if (data['memberCount'] is int) {
        memberCount = data['memberCount'];
      }

      // 🔹 Layout do cabeçalho
      Widget communityInfo = Row(
        children: [
          const SizedBox(width: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 36,
              height: 36,
              color: photoUrl != null ? Colors.transparent : kCommunityAvatarBg,
              child: (photoUrl != null && photoUrl.isNotEmpty)
                  ? CachedNetworkImage(
                      imageUrl: photoUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: Colors.grey.shade700),
                      errorWidget: (_, __, ___) =>
                          const Icon(Icons.broken_image, color: Colors.white),
                    )
                  : const Icon(Icons.people, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                (data['nome'] as String?) ?? widget.nomeComunidade,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                '$memberCount membros',
                style: const TextStyle(fontSize: 12, color: kMemberCountColor),
              ),
            ],
          ),
        ],
      );

      // 🔹 Se for admin, o título leva ao painel
      if (isAdmin) {
        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CommunityAdminPage(
                  communityId: widget.communityId,
                ),
              ),
            );
          },
          child: communityInfo,
        );
      }

      // 🔹 Caso contrário, apenas exibe info
      return communityInfo;
    },
  ),

  // substitua o bloco actions atual por este
actions: [
  StreamBuilder<DocumentSnapshot>(
    stream: FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .snapshots(),
    builder: (context, snap) {
      if (!snap.hasData || !snap.data!.exists) {
        return const SizedBox.shrink();
      }

      final data = snap.data!.data() as Map<String, dynamic>? ?? {};
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final ownerId = (data['ownerId'] ?? data['creatorId'] ?? '') as String;
      final admins = (data['admins'] is List) ? (data['admins'] as List).cast<String>() : <String>[];

      final amIAdmin = uid != null && (uid == ownerId || admins.contains(uid));
      final amIOwner = uid != null && uid == ownerId;

      // botão admin (só para admin/dono)
      final adminButton = amIAdmin
          ? IconButton(
              icon: const Icon(Icons.settings, color: Colors.white),
              tooltip: 'Painel administrativo',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CommunityAdminPage(
                      communityId: widget.communityId,
                      communityName: widget.nomeComunidade,
                    ),
                  ),
                );
              },
            )
          : const SizedBox.shrink();

      // botão sair: mostrar para todos exceto o dono (IMPORTANTE: não verifica admins aqui)
      final leaveButton = (!amIOwner && uid != null)
          ? IconButton(
              icon: const Icon(Icons.exit_to_app, color: Colors.white),
              tooltip: 'Sair da comunidade',
              onPressed: () async {
                final confirmed = await AppDialogs.confirmation(
                  context,
                  title: 'Sair da comunidade',
                  message: 'Tem certeza de que deseja sair desta comunidade?',
                  confirmText: 'Sair',
                  cancelText: 'Cancelar',
                  confirmColor: AppPalette.accent,
                );
                if (confirmed == true) {
                  // chama a função que remove o membro — garanta que ela exista e seja async
                  await _sairDaComunidade();
                }
              },
            )
          : const SizedBox.shrink();

      return Row(mainAxisSize: MainAxisSize.min, children: [adminButton, leaveButton]);
    },
  ),
],
),
      body: Column(
        children: [
          // MANTIVE O STREAMBUILDER/EXPANDED AQUI para garantir que o footer fique embaixo corretamente
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('communities')
                  .doc(widget.communityId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .limit(200)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text('Erro ao carregar mensagens'));
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final docs = snapshot.data!.docs;
                if (docs.isEmpty) return const Center(child: Text('Seja o primeiro a enviar uma mensagem 👋'));

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.only(top: 8, bottom: 110, left: 6, right: 6),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>? ?? {};
                    final msg = (data['text'] as String?) ?? '';
                    final imageUrl = data['imageUrl'] as String?;
                    final videoUrl = data['videoUrl'] as String?;
                    final videoThumbUrl = data['videoThumbUrl'] as String?;
                    final audioUrl = data['audioUrl'] as String?;
                    final senderId = data['senderId'] as String? ?? '';
                    final senderName = data['senderName'] as String? ?? 'Usuário';
                    final senderPhoto = data['senderPhoto'] as String?;
                    final isMe = senderId == uid;

                    return _buildMessageBubble(
                      isMe: isMe,
                      senderId: senderId,
                      senderName: senderName,
                      senderPhoto: senderPhoto,
                      text: msg,
                      imageUrl: imageUrl,
                      videoUrl: videoUrl,
                      videoThumbUrl: videoThumbUrl,
                      audioUrl: audioUrl,
                    );
                  },
                );
              },
            ),
          ),

          // footer: white bar, input area with icons INSIDE the input (inside same rounded container)
          SafeArea(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  // input container: icons placed inside this rounded box (attach / textfield / camera / mic)
                  Expanded(
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: kInputBgColor,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          // attach icon inside the field (left)
                          IconButton(
                            icon: const Icon(Icons.attach_file, color: Colors.black),
                            splashRadius: 18,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                            onPressed: _pickAttachment,
                          ),

                          // text field
                          Expanded(
                            child: TextField(
                              focusNode: _focusNode,
                              controller: _controller,
                              style: const TextStyle(color: Colors.black87),
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _enviarMensagem(text: _controller.text),
                              decoration: const InputDecoration(
                                hintText: "Digite sua mensagem",
                                hintStyle: TextStyle(color: kPlaceholderColor),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                              ),
                            ),
                          ),

                          // camera inside field (right)
                          IconButton(
                            icon: const Icon(Icons.camera_alt, color: Colors.black),
                            splashRadius: 18,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                            onPressed: _captureMedia,
                          ),

                          // mic inside field (right) - segurar para gravar
                          // Listener com key para checar se o pointer up ficou dentro do botão
                          Listener(
                            key: _micKey,
                            onPointerDown: (_) {
                              _startRecord();
                            },
                            onPointerUp: (details) {
                              // determina se o pointer up ocorreu dentro do botão pelo box do micKey
                              final box = _micKey.currentContext?.findRenderObject() as RenderBox?;
                              if (box != null) {
                                final local = box.globalToLocal(details.position);
                                final size = box.size;
                                final inside = local.dx >= 0 && local.dy >= 0 && local.dx <= size.width && local.dy <= size.height;
                                if (inside) {
                                  _stopAndSendRecord();
                                } else {
                                  _cancelRecord();
                                }
                              } else {
                                // fallback: cancelar
                                _cancelRecord();
                              }
                            },
                            onPointerCancel: (_) {
                              _cancelRecord();
                            },
                            child: Container(
                              width: 36,
                              height: 36,
                              alignment: Alignment.center,
                              child: Icon(
                                _isRecording ? Icons.mic_none : Icons.mic,
                                color: _isRecording ? Colors.red : Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // send circle
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: () => _enviarMensagem(text: _controller.text),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget para reproduzir áudio (mantive a lógica)
class _AudioBubble extends StatefulWidget {
  const _AudioBubble({
    required this.url,
    required this.isDark,
    required this.player,
  });

  final String url;
  final bool isDark;
  final AudioPlayer player;

  @override
  State<_AudioBubble> createState() => _AudioBubbleState();
}

class _AudioBubbleState extends State<_AudioBubble> {
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    widget.player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
  }

  Future<void> _toggle() async {
    if (_playing) {
      await widget.player.stop();
    } else {
      await widget.player.play(UrlSource(widget.url));
    }
    if (mounted) setState(() => _playing = !_playing);
  }



  @override
  Widget build(BuildContext context) {
    final fg = widget.isDark ? kSentTextColor : kReceivedTextColor;
    return InkWell(
      onTap: _toggle,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_playing ? Icons.pause_circle_filled : Icons.play_circle_fill, color: fg),
          const SizedBox(width: 8),
          Text('Áudio', style: TextStyle(color: fg)),
        ],
      ),
    );
  }
}

/// Widget de vídeo inline com lazy init (chewie + video_player)
class VideoBubble extends StatefulWidget {
  final String url;
  final String? thumbUrl;
  final double maxWidth;
  final bool isDark;

  const VideoBubble({
    super.key,
    required this.url,
    required this.maxWidth,
    required this.isDark,
    this.thumbUrl,
  });

  @override
  State<VideoBubble> createState() => _VideoBubbleState();
}

class _VideoBubbleState extends State<VideoBubble> with AutomaticKeepAliveClientMixin {
  VideoPlayerController? _vController;
  ChewieController? _chewieController;
  bool _initializing = false;
  bool _hasError = false;

  @override
  bool get wantKeepAlive => false; // não mantenha controle pesado fora de cena

  @override
  void dispose() {
    _chewieController?.dispose();
    _vController?.dispose();
    super.dispose();
  }

  Future<void> _initializeController() async {
    if (_vController != null) return;
    setState(() => _initializing = true);
    try {
      _vController = VideoPlayerController.network(widget.url, videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));
      await _vController!.initialize();
      _chewieController = ChewieController(
        videoPlayerController: _vController!,
        autoPlay: true,
        looping: false,
        showControls: true,
        allowFullScreen: true,
        allowMuting: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.white,
          handleColor: Theme.of(context).colorScheme.secondary,
          bufferedColor: Colors.white70,
        ),
      );
      if (mounted) {
        setState(() {
          _initializing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _initializing = false;
          _hasError = true;
        });
      }
    }
  }

  // Ao tocar, inicializa e abre inline; também permitimos abrir full screen via Chewie
  Future<void> _onTapPlay() async {
    await _initializeController();
    if (_chewieController != null && mounted) {
      // abrir full screen em nova rota para melhor experiência
      Navigator.of(context).push(MaterialPageRoute(
        builder: (ctx) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.black),
          body: Center(
            child: AspectRatio(aspectRatio: _vController!.value.aspectRatio == 0 ? 16 / 9 : _vController!.value.aspectRatio,
                child: Chewie(controller: _chewieController!)),
          ),
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final displayHeight = widget.maxWidth * 9 / 16;

    // Se já inicializou e está ok, mostra player inline
    if (_chewieController != null && _vController != null && _vController!.value.isInitialized && !_hasError) {
      final ar = _vController!.value.aspectRatio == 0 ? 16 / 9 : _vController!.value.aspectRatio;
      return Container(width: widget.maxWidth, child: AspectRatio(aspectRatio: ar, child: Chewie(controller: _chewieController!)));
    }

    // Se inicializando, mostra loader
    if (_initializing) {
      return Container(
        width: widget.maxWidth,
        height: displayHeight,
        decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(10)),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_hasError) {
      return Container(
        width: widget.maxWidth,
        height: displayHeight,
        decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(10)),
        child: const Center(child: Icon(Icons.error, color: Colors.red)),
      );
    }

    // Mostra thumbnail (se existir) com botão de play, lazy init ao tocar
    return GestureDetector(
      onTap: _onTapPlay,
      child: Container(
        width: widget.maxWidth,
        height: displayHeight,
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // thumbnail remoto (preferível)
            if (widget.thumbUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: widget.thumbUrl!,
                  width: widget.maxWidth,
                  height: displayHeight,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: Colors.black12),
                  errorWidget: (_, __, ___) => Container(color: Colors.black12),
                ),
              )
            else
              // fallback visual se não houver thumbnail
              Container(
                width: widget.maxWidth,
                height: displayHeight,
                decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.videocam, size: 36, color: Colors.white70),
              ),

            // botão play
            Container(
              decoration: BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
              padding: const EdgeInsets.all(6),
              child: Icon(Icons.play_arrow, size: 36, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fullscreen image viewer (Hero opcional)
class ImageFullScreen extends StatelessWidget {
  final String imageUrl;

  const ImageFullScreen({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black),
      body: Center(
        child: Hero(
          tag: imageUrl,
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            placeholder: (c, s) => const Center(child: CircularProgressIndicator()),
            errorWidget: (c, s, e) => const Center(child: Icon(Icons.broken_image, color: Colors.white)),
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

/// Perfil simplificado (mantive igual)
class ProfilePage extends StatelessWidget {
  final String userId;

  const ProfilePage({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final nome = data['nome'] ?? 'Usuário';
          final bio = data['bio'] ?? '';
          final fotoPerfil = data['fotoPerfil'] ?? '';
          final fotosGrid = List<String>.from(data['fotosGrid'] ?? List.generate(6, (_) => ''));

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (fotoPerfil.isNotEmpty) CircleAvatar(radius: 50, backgroundImage: NetworkImage(fotoPerfil)),
                const SizedBox(height: 12),
                Text(nome, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(bio),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: fotosGrid.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
                  itemBuilder: (context, index) {
                    final url = fotosGrid[index];
                    if (url.isEmpty) {
                      return Container(color: Colors.grey.shade300, child: const Icon(Icons.image, color: Colors.white));
                    }
                    return ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(url, fit: BoxFit.cover));
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
