import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:show_talent/controller/user_controller.dart';
import 'package:show_talent/models/message_converstion.dart';
import 'package:show_talent/models/user.dart';

class ChatController extends GetxController {
  final RxList<Conversation> _conversations = <Conversation>[].obs;
  List<Conversation> get conversations => _conversations;

  final RxList<Message> _messages = <Message>[].obs;
  List<Message> get messages => _messages;

  AppUser? currentUser;
  final Map<String, AppUser> _userCache = <String, AppUser>{};

  @override
  void onInit() {
    super.onInit();
    if (_initializeCurrentUser()) {
      fetchConversations();
    }
  }

  bool _initializeCurrentUser() {
    currentUser = Get.find<UserController>().user;
    if (currentUser == null) {
      Get.snackbar('Erreur', 'Aucun utilisateur connecté.');
      return false;
    }
    return true;
  }

  AppUser? _requireCurrentUser() {
    final user = currentUser;
    if (user != null) {
      return user;
    }

    if (_initializeCurrentUser()) {
      return currentUser;
    }

    return null;
  }

  void fetchConversations() {
    final user = _requireCurrentUser();
    if (user == null) {
      return;
    }

    FirebaseFirestore.instance
        .collection('conversations')
        .where('utilisateurIds', arrayContains: user.uid)
        .snapshots()
        .listen((snapshot) {
      _conversations.assignAll(
        snapshot.docs.map((doc) => Conversation.fromMap(doc.data())).toList(),
      );
    });
  }

  Future<void> markMessagesAsRead(String conversationId) async {
    final user = _requireCurrentUser();
    if (user == null) {
      return;
    }

    final messagesSnapshot = await FirebaseFirestore.instance
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .where('destinataireId', isEqualTo: user.uid)
        .where('estLu', isEqualTo: false)
        .get();

    for (final doc in messagesSnapshot.docs) {
      await doc.reference.update({'estLu': true});
    }
  }

  void fetchMessages(String conversationId) {
    FirebaseFirestore.instance
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('dateEnvoi')
        .snapshots()
        .listen((snapshot) {
      _messages.assignAll(
        snapshot.docs.map((doc) => Message.fromMap(doc.data())).toList(),
      );
      _messages.refresh();
    });
  }

  Future<int> getUnreadMessagesCount(String conversationId) async {
    final user = _requireCurrentUser();
    if (user == null) {
      return 0;
    }

    final messagesSnapshot = await FirebaseFirestore.instance
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .where('destinataireId', isEqualTo: user.uid)
        .where('estLu', isEqualTo: false)
        .get();

    return messagesSnapshot.docs.length;
  }

  Future<String> createConversation(AppUser otherUser) async {
    final user = _requireCurrentUser();
    if (user == null) {
      throw StateError('Aucun utilisateur connecté.');
    }

    final existingConversations = await FirebaseFirestore.instance
        .collection('conversations')
        .where('utilisateurIds', arrayContains: user.uid)
        .get();

    for (final doc in existingConversations.docs) {
      final conversation = Conversation.fromMap(doc.data());
      if (conversation.utilisateurIds.contains(otherUser.uid)) {
        return conversation.id;
      }
    }

    final conversationId =
        FirebaseFirestore.instance.collection('conversations').doc().id;

    final newConversation = Conversation(
      id: conversationId,
      utilisateur1Id: user.uid,
      utilisateur2Id: otherUser.uid,
      utilisateurIds: [user.uid, otherUser.uid],
    );

    await FirebaseFirestore.instance
        .collection('conversations')
        .doc(conversationId)
        .set(newConversation.toMap());

    return conversationId;
  }

  Future<void> sendMessage(String conversationId, Message message) async {
    await FirebaseFirestore.instance
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .add(message.toMap());

    await FirebaseFirestore.instance
        .collection('conversations')
        .doc(conversationId)
        .update({
      'lastMessage': message.contenu,
      'lastMessageDate': Timestamp.fromDate(message.dateEnvoi),
    });

    _messages.add(message);
    _messages.refresh();
  }

  Future<void> deleteMessage(String conversationId, String messageId) async {
    try {
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .doc(messageId)
          .delete();
      Get.snackbar('Succès', 'Message supprimé.');
    } catch (_) {
      Get.snackbar('Erreur', 'Impossible de supprimer le message.');
    }
  }

  Future<void> deleteConversation(String conversationId) async {
    try {
      final messagesSnapshot = await FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .get();

      for (final doc in messagesSnapshot.docs) {
        await doc.reference.delete();
      }

      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId)
          .delete();

      Get.snackbar('Succès', 'Conversation supprimée avec succès.');
    } catch (_) {
      Get.snackbar('Erreur', 'Impossible de supprimer la conversation.');
    }
  }

  Future<AppUser?> getUserById(String userId) async {
    if (_userCache.containsKey(userId)) {
      return _userCache[userId];
    }

    try {
      final userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      final data = userSnapshot.data();
      if (data == null) {
        return null;
      }

      final user = AppUser.fromMap(data);
      _userCache[userId] = user;
      return user;
    } catch (_) {
      Get.snackbar(
        'Erreur',
        "Impossible de récupérer les informations de l'utilisateur.",
      );
      return null;
    }
  }
}
