import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:path/path.dart';
import 'package:show_talent/controller/user_controller.dart';

class UploadVideoController extends GetxController {
  var isUploading = false.obs;
  var uploadProgress = 0.0.obs;

  Future<void> uploadVideo(
    String songName,
    String caption,
    String videoPath,
  ) async {
    if (songName.isEmpty || caption.isEmpty) {
      Get.snackbar(
        'Erreur',
        'Le nom de la chanson et la legende ne peuvent pas etre vides',
      );
      return;
    }

    try {
      isUploading(true);
      final videoFile = File(videoPath);

      final fileName = basename(videoPath);
      final storageRef =
          FirebaseStorage.instance.ref().child('videos/$fileName');

      final uploadTask = storageRef.putFile(videoFile);
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        uploadProgress.value = snapshot.bytesTransferred / snapshot.totalBytes;
      });

      final snapshot = await uploadTask;
      final videoUrl = await snapshot.ref.getDownloadURL();
      debugPrint('URL video telechargee: $videoUrl');

      final videoId = FirebaseFirestore.instance.collection('videos').doc().id;

      await FirebaseFirestore.instance.collection('videos').doc(videoId).set({
        'id': videoId,
        'videoUrl': videoUrl,
        'songName': songName,
        'caption': caption,
        'likes': [],
        'shareCount': 0,
        'uid': Get.find<UserController>().user?.uid,
        'thumbnail': '',
        'createdAt': FieldValue.serverTimestamp(),
      });

      Get.snackbar('Succes', 'Video telechargee avec succes.');
    } catch (e) {
      Get.snackbar(
        'Erreur',
        'Une erreur est survenue pendant le telechargement : $e',
      );
    } finally {
      isUploading(false);
      uploadProgress.value = 0.0;
    }
  }
}
