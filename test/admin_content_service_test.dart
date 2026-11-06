// Aucun test de ce service n'existait avant l'audit du 2026-11-06 : la
// conversion d'erreur de _callable (point central pour 5 des 6 contrôleurs de
// contenu) pouvait diverger sans qu'aucun test ne le signale -- c'est
// exactement ce qui s'était produit pour VideoController (voir aussi
// video_controller_test.dart).
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:show_talent/services/admin_content_service.dart';

class _MockFirebaseFunctions extends Mock implements FirebaseFunctions {}

class _MockHttpsCallable extends Mock implements HttpsCallable {}

class _MockHttpsCallableResult extends Mock
    implements HttpsCallableResult<dynamic> {}

void main() {
  late _MockFirebaseFunctions functions;
  late _MockHttpsCallable callable;
  late AdminContentService service;

  setUp(() {
    functions = _MockFirebaseFunctions();
    callable = _MockHttpsCallable();
    when(() => functions.httpsCallable(any())).thenReturn(callable);
    service = AdminContentService(functions: functions);
  });

  test('une reponse reussie est renvoyee telle quelle', () async {
    final result = _MockHttpsCallableResult();
    when(() => result.data).thenReturn(<String, dynamic>{
      'success': true,
      'code': 'ok',
      'message': 'Offre supprimee.',
    });
    when(() => callable.call(any())).thenAnswer((_) async => result);

    final response = await service.deleteOffer(offerId: 'offer-1');

    expect(response.success, isTrue);
    expect(response.message, 'Offre supprimee.');
    verify(() => functions.httpsCallable('adminDeleteOffer')).called(1);
  });

  test(
    'une exception inattendue devient un echec type, jamais une exception qui remonte',
    () async {
      when(() => callable.call(any())).thenThrow(Exception('reseau coupe'));

      final response = await service.deleteOffer(offerId: 'offer-1');

      expect(response.success, isFalse);
      expect(response.retriable, isTrue);
      expect(
        response.message,
        "Suppression de l’offre impossible pour le moment.",
      );
    },
  );

  test('le mode QA visuelle ne tente jamais d appel reseau', () async {
    final qaService = AdminContentService.visualQa();

    final response = await qaService.deleteOffer(offerId: 'offer-1');

    expect(response.success, isFalse);
    verifyNever(() => functions.httpsCallable(any()));
  });
}
