import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:show_talent/dashboard/user_management_widget.dart';
import 'package:show_talent/services/managed_account_service.dart';

import 'test_support/admin_test_helpers.dart';

/// La date de naissance est le seul fait dont l'absence retire une fiche de
/// toutes les recherches : `birthYear` en est dérivé côté serveur, et un
/// dossier sans année n'est renvoyé à aucun recruteur. Le portail ne pouvait
/// pas la corriger ; seul le joueur le pouvait, depuis son téléphone.
///
/// Elle vit dans `users/{uid}/private/contact`, hors du flux qui alimente la
/// liste. Tout ce qui suit tient à cette phrase.
void main() {
  ManagedAccountService buildService(List<Map<String, dynamic>> recorded) {
    return ManagedAccountService(
      callableExecutor: (callableName, payload) async {
        recorded.add({'callableName': callableName, 'payload': payload});
        return <String, dynamic>{'success': true};
      },
    );
  }

  Future<void> pumpDashboard(
    WidgetTester tester,
    TestUserController controller,
    ManagedAccountService service,
  ) async {
    await pumpAdminTestApp(
      tester,
      UserManagementWidget(
        selectedRole: 'Tous',
        userController: controller,
        managedAccountService: service,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openEditDialog(WidgetTester tester) async {
    final actionMenu = find.byType(PopupMenuButton<String>);
    await tester.ensureVisible(actionMenu);
    await tester.tap(actionMenu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Modifier le profil'));
    await tester.pumpAndSettle();
  }

  TestUserController controllerWithPlayer({
    bool profileVerified = false,
    String? birthDate,
  }) {
    final controller = TestUserController(
      users: [
        buildTestUser(
          uid: 'player-1',
          nom: 'Player One',
          email: 'player@example.com',
          role: 'joueur',
          createdByAdmin: true,
          profileVerified: profileVerified,
        ),
      ],
    );
    if (birthDate != null) {
      controller.privateContactByUid['player-1'] = <String, dynamic>{
        'birthDate': birthDate,
      };
    }
    return controller;
  }

  testWidgets('the dialog opens on the date the contact document carries', (
    tester,
  ) async {
    // Le dialogue recevait l'utilisateur de la liste, qui ne porte jamais ce
    // champ. Sans la lecture privée, il s'ouvrirait vide sur une fiche qui a
    // une date — et l'administration corrigerait un fait déjà correct.
    final controller = controllerWithPlayer(birthDate: '2004-05-17T00:00:00Z');

    await pumpDashboard(tester, controller, buildService([]));
    await openEditDialog(tester);

    expect(controller.privateFieldFetches, contains('player-1'));
    expect(find.text('Date de naissance : 17/05/2004'), findsOneWidget);
  });

  testWidgets('a missing date says so, and says what it costs', (tester) async {
    await pumpDashboard(tester, controllerWithPlayer(), buildService([]));
    await openEditDialog(tester);

    expect(find.text('Date de naissance : non renseignée'), findsOneWidget);
    expect(
      find.textContaining('n’apparaît dans aucune recherche'),
      findsOneWidget,
    );
  });

  testWidgets('clearing the date sends an explicit null', (tester) async {
    // Effacer est un geste légitime : une date inventée vaut moins que pas de
    // date. Le callable lit `null` comme un effacement, le trigger en dérive
    // une année nulle, et la fiche sort des recherches — ce qui est exact.
    final recorded = <Map<String, dynamic>>[];
    final controller = controllerWithPlayer(birthDate: '2004-05-17T00:00:00Z');

    await pumpDashboard(tester, controller, buildService(recorded));
    await openEditDialog(tester);

    await tester.tap(find.byTooltip('Effacer la date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(recorded, hasLength(1));
    expect(recorded.single['callableName'], 'updateManagedAccountProfile');
    expect(
      (recorded.single['payload'] as Map<String, dynamic>)['patch'],
      {'birthDate': null},
    );
  });

  testWidgets('a chosen date leaves as an ISO-8601 string', (tester) async {
    // Jamais un DateTime : le callable attend une chaîne, la valide contre la
    // fonction dont le trigger dérive l'année, et la stocke en Timestamp.
    final recorded = <Map<String, dynamic>>[];
    final expectedYear = DateTime.now().year - 18;

    await pumpDashboard(tester, controllerWithPlayer(), buildService(recorded));
    await openEditDialog(tester);

    await tester.tap(find.text('Renseigner'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    final patch =
        (recorded.single['payload'] as Map<String, dynamic>)['patch']
            as Map<String, dynamic>;
    expect(patch.keys, ['birthDate']);
    expect(patch['birthDate'], isA<String>());
    expect(patch['birthDate'], startsWith('$expectedYear-01-01'));
  });

  testWidgets('reopening and saving nothing sends nothing', (tester) async {
    // Le sélecteur rend une date à minuit, le document en porte une avec
    // l'heure conservée par le Timestamp. Comparer les DateTime entiers
    // enverrait un patch à chaque ouverture, et ferait tomber une
    // certification sans que rien n'ait changé.
    final recorded = <Map<String, dynamic>>[];
    final controller = controllerWithPlayer(birthDate: '2004-05-17T09:32:11Z');

    await pumpDashboard(tester, controller, buildService(recorded));
    await openEditDialog(tester);
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    // Rien ne part : le patch est vide, et l'écran s'arrête avant l'appel.
    expect(recorded, isEmpty);
  });

  testWidgets('a verified profile is told the badge will fall', (tester) async {
    final controller = controllerWithPlayer(
      profileVerified: true,
      birthDate: '2004-05-17T00:00:00Z',
    );

    await pumpDashboard(tester, controller, buildService([]));
    await openEditDialog(tester);

    expect(
      find.textContaining('retire la certification'),
      findsOneWidget,
    );
  });

  testWidgets('an unreadable contact document hides the field', (tester) async {
    // Affiché vide, il dirait « ce joueur n'a pas de date de naissance », ce
    // qui est une autre affirmation que « je n'ai pas pu lire ».
    final controller = controllerWithPlayer(birthDate: '2004-05-17T00:00:00Z')
      ..privateFieldsError = StateError('permission-denied');

    await pumpDashboard(tester, controller, buildService([]));
    await openEditDialog(tester);

    expect(find.textContaining('Date de naissance :'), findsNothing);
    expect(
      find.textContaining('Date de naissance indisponible'),
      findsOneWidget,
    );
    // Le reste de la fiche reste corrigeable : une lecture privée refusée ne
    // doit pas bloquer la correction d'un club ou d'un poste.
    expect(find.text('Club actuel'), findsOneWidget);
  });
}
