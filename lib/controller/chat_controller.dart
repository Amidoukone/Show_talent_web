import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:show_talent/controller/user_controller.dart';
import 'package:show_talent/models/message_converstion.dart';
import 'package:show_talent/models/user.dart';

class ChatController extends GetxController {
  final Rx<List<Conversation>> _conversations = Rx<List<Conversation>>([]);
  List<Conversation> get conversations => _conversations.value;

  final Rx<List<Message>> _messages = Rx<List<Message>>([]); // Liste des messages observable
  List<Message> get messages => _messages.value; // Getter pour accéder aux messages dans l'UI

  late AppUser currentUser; // Utilisateur courant
  final Map<String, AppUser> _userCache = {}; // Cache pour éviter de recharger les mêmes utilisateurs plusieurs fois

  @override
  void onInit() {
    super.onInit();
    _initializeCurrentUser();
    fetchConversations();  // Appel de la méthode sans le préfixe privé
  }

  // Initialiser l'utilisateur actuel
  void _initializeCurrentUser() {
    currentUser = Get.find<UserController>().user!;
  }

  // Méthode pour récupérer les conversations depuis Firestore
  void fetchConversations() {  // La méthode est désormais publique
    FirebaseFirestore.instance
        .collection('conversations')
        .where('utilisateurIds', arrayContains: currentUser.uid)
        .snapshots()
        .listen((snapshot) {
      _conversations.value = snapshot.docs.map((doc) {
        return Conversation.fromMap(doc.data());
      }).toList();
    });
  }

  // Marquer tous les messages comme "Lu" pour une conversation
  Future<void> markMessagesAsRead(String conversationId) async {
    QuerySnapshot messagesSnapshot = await FirebaseFirestore.instance
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .where('destinataireId', isEqualTo: currentUser.uid)  // Messages envoyés à l'utilisateur actuel
        .where('estLu', isEqualTo: false)  // Filtrer uniquement les messages non lus
        .get();

    // Mettre à jour tous les messages non lus
    for (var doc in messagesSnapshot.docs) {
      await doc.reference.update({'estLu': true});
    }
  }

  // Récupérer les messages pour une conversation spécifique
  void fetchMessages(String conversationId) {
    FirebaseFirestore.instance
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('dateEnvoi', descending: false) // Les messages doivent être triés par ordre d'envoi
        .snapshots()
        .listen((snapshot) {
      _messages.value = snapshot.docs.map((doc) {
        return Message.fromMap(doc.data());
      }).toList();
      _messages.refresh();
    });
  }

  // Obtenir le nombre de messages non lus pour une conversation
  Future<int> getUnreadMessagesCount(String conversationId) async {
    QuerySnapshot messagesSnapshot = await FirebaseFirestore.instance
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .where('destinataireId', isEqualTo: currentUser.uid)  // Filtrer les messages non lus destinés à l'utilisateur actuel
        .where('estLu', isEqualTo: false)
        .get();

    return messagesSnapshot.docs.length;  // Retourner le nombre de messages non lus
  }

  // Créer une nouvelle conversation ou retourner l'ID d'une conversation existante
  Future<String> createConversation(AppUser otherUser) async {
    // Chercher si une conversation existe déjà entre les deux utilisateurs
    QuerySnapshot existingConversations = await FirebaseFirestore.instance
        .collection('conversations')
        .where('utilisateurIds', arrayContains: currentUser.uid)
        .get();

    for (var doc in existingConversations.docs) {
      Conversation conversation = Conversation.fromMap(doc.data() as Map<String, dynamic>);
      if (conversation.utilisateurIds.contains(otherUser.uid)) {
        return conversation.id; // Retourner l'ID de la conversation existante
      }
    }

    // Si aucune conversation n'existe, en créer une nouvelle
    String conversationId = FirebaseFirestore.instance.collection('conversations').doc().id;

    Conversation newConversation = Conversation(
      id: conversationId,
      utilisateur1Id: currentUser.uid,
      utilisateur2Id: otherUser.uid,
      utilisateurIds: [currentUser.uid, otherUser.uid], // Liste des deux utilisateurs
    );

    await FirebaseFirestore.instance
        .collection('conversations')
        .doc(conversationId)
        .set(newConversation.toMap());

    return conversationId;
  }

  // Méthode pour envoyer un message dans une conversation
  Future<void> sendMessage(String conversationId, Message message) async {
    await FirebaseFirestore.instance
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .add(message.toMap());

    // Mettre à jour la conversation avec le dernier message
    await FirebaseFirestore.instance.collection('conversations').doc(conversationId).update({
      'lastMessage': message.contenu,
      'lastMessageDate': Timestamp.fromDate(message.dateEnvoi),
    });

    _messages.value.add(message);
    _messages.refresh();
  }

  // Méthode pour supprimer un message spécifique dans une conversation
  Future<void> deleteMessage(String conversationId, String messageId) async {
    try {
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .doc(messageId)
          .delete();
      Get.snackbar('Succès', 'Message supprimé.');
    } catch (e) {
      Get.snackbar('Erreur', 'Impossible de supprimer le message.');
    }
  }

  // Méthode pour supprimer une conversation entière
  Future<void> deleteConversation(String conversationId) async {
    try {
      // Supprimer tous les messages dans la conversation
      var messagesSnapshot = await FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .get();

      for (var doc in messagesSnapshot.docs) {
        await doc.reference.delete();
      }

      // Supprimer la conversation elle-même
      await FirebaseFirestore.instance.collection('conversations').doc(conversationId).delete();

      Get.snackbar('Succès', 'Conversation supprimée avec succès.');
    } catch (e) {
      Get.snackbar('Erreur', 'Impossible de supprimer la conversation.');
    }
  }

  // Méthode pour récupérer un utilisateur à partir de son ID
  Future<AppUser?> getUserById(String userId) async {
    if (_userCache.containsKey(userId)) {
      return _userCache[userId];
    }

    try {
      DocumentSnapshot userSnapshot =
          await FirebaseFirestore.instance.collection('users').doc(userId).get();
      AppUser user = AppUser.fromMap(userSnapshot.data() as Map<String, dynamic>);

      _userCache[userId] = user;
      return user;
    } catch (e) {
      Get.snackbar('Erreur', 'Impossible de récupérer les informations utilisateur.');
      return null;
    }
  }
}
