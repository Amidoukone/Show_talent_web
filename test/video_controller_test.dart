// Verrouille la correction de l'audit du 2026-11-06 : VideoController etait
// le seul des 3 controleurs de contenu (avec Offre/Event) a rompre le contrat
// de retour type d'AdminContentService en levant une exception au lieu de
// renvoyer une AdminActionResponse d'echec. Un appelant qui ne s'y attendait
// pas affichait alors une chaine d'erreur brute au lieu du message propre.
// Ce test figerait une regression si cette divergence etait reintroduite.
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:show_talent/controller/video_controller.dart';
import 'package:show_talent/models/video.dart';
import 'package:show_talent/services/admin_content_service.dart';

class _MockFirebaseFunctions extends Mock implements FirebaseFunctions {}

class _MockHttpsCallable extends Mock implements HttpsCallable {}

class _MockHttpsCallableResult extends Mock
    implements HttpsCallableResult<dynamic> {}

void main() {
  late _MockFirebaseFunctions functions;
  late _MockHttpsCallable callable;
  late VideoController controller;

  setUp(() {
    functions = _MockFirebaseFunctions();
    callable = _MockHttpsCallable();
    when(() => functions.httpsCallable(any())).thenReturn(callable);
    controller = VideoController(
      adminContentService: AdminContentService(functions: functions),
    );
  });

  test(
    'deleteVideo renvoie un echec type au lieu de lever une exception',
    () async {
      when(() => callable.call(any())).thenThrow(Exception('reseau coupe'));

      final response = await controller.deleteVideo('video-1');

      expect(response.success, isFalse);
    },
  );

  test(
    'setVideoStatus renvoie un echec type au lieu de lever une exception',
    () async {
      when(() => callable.call(any())).thenThrow(Exception('reseau coupe'));

      final response = await controller.setVideoStatus('video-1', 'approved');

      expect(response.success, isFalse);
    },
  );

  test(
    'rejectVideo renvoie un echec type au lieu de lever une exception',
    () async {
      when(() => callable.call(any())).thenThrow(Exception('reseau coupe'));

      final response = await controller.rejectVideo('video-1', reason: 'x');

      expect(response.success, isFalse);
    },
  );

  test('deleteVideo retire la video de la liste seulement si succes', () async {
    final result = _MockHttpsCallableResult();
    when(() => result.data).thenReturn(<String, dynamic>{'success': true});
    when(() => callable.call(any())).thenAnswer((_) async => result);
    controller.videoList.add(
      Video(
        id: 'video-1',
        videoUrl: 'https://example.test/clip.mp4',
        uid: 'u1',
      ),
    );

    final response = await controller.deleteVideo('video-1');

    expect(response.success, isTrue);
    expect(controller.videoList.any((v) => v.id == 'video-1'), isFalse);
  });
}
