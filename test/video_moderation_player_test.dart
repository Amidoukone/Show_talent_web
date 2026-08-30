import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:show_talent/screens/video_player.dart';
import 'package:show_talent/utils/browser_fullscreen.dart';
import 'package:show_talent/theme/admin_theme.dart';
import 'package:show_talent/utils/video_moderation_playback.dart';
import 'package:show_talent/widgets/admin_video_ui.dart';
import 'package:video_player/video_player.dart';

/// Un contrôleur qui n'ouvre aucun flux.
///
/// `VideoPlayer` ne touche la plateforme qu'une fois un lecteur créé : tant
/// que [initialize] ne passe pas par le plugin, l'écran entier est
/// vérifiable en test.
class _FakeVideoPlayerController extends VideoPlayerController {
  _FakeVideoPlayerController({this.failsToInitialize = false})
    : super.networkUrl(Uri.parse('https://example.test/clip.mp4'));

  final bool failsToInitialize;

  final List<String> calls = <String>[];

  @override
  Future<void> initialize() async {
    if (failsToInitialize) {
      calls.add('initialize:failed');
      return;
    }

    calls.add('initialize');
    value = const VideoPlayerValue(
      duration: Duration(seconds: 60),
      size: Size(640, 360),
      isInitialized: true,
    );
  }

  @override
  Future<void> play() async {
    calls.add('play');
    value = value.copyWith(isPlaying: true);
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    value = value.copyWith(isPlaying: false);
  }

  @override
  Future<void> seekTo(Duration position) async {
    calls.add('seekTo:${position.inMilliseconds}');
    value = value.copyWith(position: position);
  }

  @override
  Future<void> setPlaybackSpeed(double speed) async {
    calls.add('speed:$speed');
    value = value.copyWith(playbackSpeed: speed);
  }

  @override
  Future<void> setVolume(double volume) async {
    calls.add('volume:$volume');
    value = value.copyWith(volume: volume);
  }

  @override
  Future<void> setLooping(bool looping) async {
    calls.add('looping:$looping');
    value = value.copyWith(isLooping: looping);
  }
}

void main() {
  group('logique de lecture', () {
    test('un saut avant le début se cale sur le début', () {
      expect(
        seekBy(
          position: const Duration(seconds: 3),
          step: -videoModerationCoarseStep,
          total: const Duration(seconds: 60),
        ),
        Duration.zero,
      );
    });

    test('un saut après la fin se cale sur la fin', () {
      expect(
        seekBy(
          position: const Duration(seconds: 58),
          step: videoModerationCoarseStep,
          total: const Duration(seconds: 60),
        ),
        const Duration(seconds: 60),
      );
    });

    test('une durée inconnue ne produit jamais de position négative', () {
      expect(
        clampSeekTarget(
          target: const Duration(seconds: 5),
          total: Duration.zero,
        ),
        Duration.zero,
      );
    });

    test('les positions se lisent en minutes, les longues en heures', () {
      expect(formatPlaybackTimestamp(const Duration(seconds: 7)), '0:07');
      expect(formatPlaybackTimestamp(const Duration(seconds: 65)), '1:05');
      expect(
        formatPlaybackTimestamp(const Duration(hours: 1, minutes: 2)),
        '1:02:00',
      );
      expect(formatPlaybackTimestamp(const Duration(seconds: -5)), '0:00');
    });

    test('les vitesses s’affichent à la française et bouclent', () {
      expect(formatPlaybackSpeed(1), '1x');
      expect(formatPlaybackSpeed(0.5), '0,5x');
      expect(nextPlaybackSpeed(1), 1.5);
      expect(nextPlaybackSpeed(videoModerationSpeeds.last), 0.25);
      expect(nextPlaybackSpeed(3), 1.0);
    });

    test('la progression reste bornée, même durée inconnue', () {
      expect(
        playbackProgress(
          position: const Duration(seconds: 30),
          total: const Duration(seconds: 60),
        ),
        0.5,
      );
      // Une durée nulle donnerait NaN, et une barre pilotée par NaN lève une
      // assertion en plein écran de modération.
      expect(
        playbackProgress(
          position: const Duration(seconds: 30),
          total: Duration.zero,
        ),
        0,
      );
    });
  });

  group('lecteur de modération', () {
    late _FakeVideoPlayerController controller;

    Future<void> pumpPlayer(
      WidgetTester tester, {
      List<AdminVideoDecision> decisions = const <AdminVideoDecision>[],
      bool failsToInitialize = false,
    }) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1600, 1200);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      controller = _FakeVideoPlayerController(
        failsToInitialize: failsToInitialize,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AdminTheme.buildTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => VideoPlayerScreen(
                        videoUrl: 'https://example.test/clip.mp4',
                        userId: 'player-1',
                        videoId: 'video-1',
                        title: 'Action de but',
                        authorName: 'Adama',
                        decisions: decisions,
                        controllerFactory: (_) => controller,
                      ),
                    ),
                  ),
                  child: const Text('ouvrir'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('ouvrir'));
      await tester.pumpAndSettle();
    }

    testWidgets('la lecture démarre en boucle, sur la vidéo demandée', (
      tester,
    ) async {
      await pumpPlayer(tester);

      expect(controller.calls, contains('initialize'));
      expect(controller.calls, contains('looping:true'));
      expect(controller.calls, contains('play'));
      expect(find.text('Action de but'), findsOneWidget);
      expect(find.textContaining('Adama'), findsOneWidget);
    });

    testWidgets('la position et la durée sont affichées', (tester) async {
      await pumpPlayer(tester);

      expect(find.text('0:00'), findsOneWidget);
      expect(find.text('1:00'), findsWidgets);
    });

    testWidgets('avancer de dix secondes déplace la lecture', (tester) async {
      await pumpPlayer(tester);

      await tester.tap(find.byTooltip('Avancer de 10 s (L)'));
      await tester.pumpAndSettle();

      expect(controller.value.position, const Duration(seconds: 10));
      expect(find.text('0:10'), findsOneWidget);
    });

    testWidgets('reculer près du début revient au début, sans erreur', (
      tester,
    ) async {
      await pumpPlayer(tester);

      await tester.tap(find.byTooltip('Avancer d’une seconde (Maj + droite)'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Reculer de 10 s (J)'));
      await tester.pumpAndSettle();

      expect(controller.value.position, Duration.zero);
    });

    testWidgets('la vitesse de lecture est réglable', (tester) async {
      await pumpPlayer(tester);

      await tester.tap(find.byTooltip('Vitesse de lecture (S)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('0,5x').last);
      await tester.pumpAndSettle();

      expect(controller.value.playbackSpeed, 0.5);
      expect(find.text('0,5x'), findsOneWidget);
    });

    testWidgets('le son se coupe et se rétablit', (tester) async {
      await pumpPlayer(tester);

      await tester.tap(find.byTooltip('Couper le son (M)'));
      await tester.pumpAndSettle();
      expect(controller.value.volume, 0);

      await tester.tap(find.byTooltip('Réactiver le son (M)'));
      await tester.pumpAndSettle();
      expect(controller.value.volume, 1);
    });

    testWidgets('une décision appliquée referme le lecteur', (tester) async {
      var invoked = 0;
      await pumpPlayer(
        tester,
        decisions: [
          AdminVideoDecision(
            label: 'Approuver',
            icon: Icons.check_circle_outline_rounded,
            onInvoke: () async {
              invoked++;
              return true;
            },
          ),
        ],
      );

      await tester.tap(find.text('Approuver'));
      await tester.pumpAndSettle();

      expect(invoked, 1);
      expect(find.byType(VideoPlayerScreen), findsNothing);
      // La lecture s'arrête avant la décision : le son d'une vidéo qu'on
      // refuse n'aide personne.
      expect(controller.calls, contains('pause'));
    });

    testWidgets('une décision annulée laisse le lecteur ouvert', (
      tester,
    ) async {
      await pumpPlayer(
        tester,
        decisions: [
          AdminVideoDecision(
            label: 'Refuser',
            icon: Icons.delete_outline_rounded,
            onInvoke: () async => false,
          ),
        ],
      );

      await tester.tap(find.text('Refuser'));
      await tester.pumpAndSettle();

      expect(find.byType(VideoPlayerScreen), findsOneWidget);
    });

    testWidgets('le plein écran masque le reste, Échap le rétablit', (
      tester,
    ) async {
      await pumpPlayer(tester);

      expect(find.text('Retour'), findsOneWidget);
      expect(find.text('Action de but'), findsOneWidget);

      await tester.tap(find.byTooltip('Plein écran (F)'));
      await tester.pumpAndSettle();

      // Plus de barre du haut ni de panneau latéral : l'image occupe la place.
      expect(find.text('Retour'), findsNothing);
      expect(find.text('Action de but'), findsNothing);
      expect(find.byTooltip('Quitter le plein écran (Échap)'), findsWidgets);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.text('Retour'), findsOneWidget);
      expect(find.text('Action de but'), findsOneWidget);
    });

    testWidgets('une vidéo illisible se décide quand même', (tester) async {
      await pumpPlayer(
        tester,
        failsToInitialize: true,
        decisions: [
          AdminVideoDecision(
            label: 'Supprimer',
            icon: Icons.delete_outline_rounded,
            onInvoke: () async => true,
          ),
        ],
      );

      expect(find.text('Impossible de lire cette vidéo.'), findsOneWidget);
      // Une source morte est précisément un cas où il faut pouvoir trancher.
      expect(find.text('Supprimer'), findsOneWidget);
    });
  });

  group('plein écran navigateur', () {
    test('hors web, l’API existe mais ne fait rien', () async {
      // Le portail se compile aussi pour Windows, macOS et Linux : le lecteur
      // appelle la même API partout, et c'est le bouchon qui doit rendre
      // l'appel inoffensif.
      expect(browserFullscreenSupported, isFalse);
      expect(browserFullscreenActive, isFalse);
      await expectLater(setBrowserFullscreen(true), completes);

      var notified = false;
      final stop = listenBrowserFullscreen((_) => notified = true);
      stop();
      expect(notified, isFalse);
    });

    test('le lecteur accompagne le plein écran applicatif du navigateur', () {
      final source = File('lib/screens/video_player.dart').readAsStringSync();

      // Le vrai plein écran passe par un import conditionnel : le brancher en
      // dur casserait la compilation des cibles bureau.
      expect(source, contains("import '../utils/browser_fullscreen.dart'"));
      expect(source, contains('setBrowserFullscreen(next)'));
      // Et une sortie décidée par le navigateur doit défaire la mise en page.
      expect(source, contains('listenBrowserFullscreen('));
      expect(source, contains('_onBrowserFullscreenChanged'));
    });

    test('l’implémentation web n’est chargée que sur le web', () {
      final barrel = File('lib/utils/browser_fullscreen.dart')
          .readAsStringSync();

      expect(
        barrel,
        contains(
          "export 'browser_fullscreen_stub.dart'\n"
          "    if (dart.library.js_interop) 'browser_fullscreen_web.dart';",
        ),
      );
    });
  });

  group('file de modération', () {
    late Map<String, _FakeVideoPlayerController> controllers;

    List<AdminVideoQueueEntry> buildEntries(
      int count, {
      Future<bool> Function(String videoId)? onDecision,
    }) {
      return [
        for (var index = 1; index <= count; index++)
          AdminVideoQueueEntry(
            videoUrl: 'https://example.test/clip-$index.mp4',
            userId: 'player-$index',
            videoId: 'video-$index',
            title: 'Vidéo numéro $index',
            decisions: onDecision == null
                ? const <AdminVideoDecision>[]
                : [
                    AdminVideoDecision(
                      label: 'Approuver',
                      icon: Icons.check_circle_outline_rounded,
                      onInvoke: () => onDecision('video-$index'),
                    ),
                  ],
          ),
      ];
    }

    Future<void> pumpQueue(
      WidgetTester tester,
      List<AdminVideoQueueEntry> entries, {
      int initialIndex = 0,
    }) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1600, 1200);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      controllers = <String, _FakeVideoPlayerController>{};

      await tester.pumpWidget(
        MaterialApp(
          theme: AdminTheme.buildTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => VideoPlayerScreen.queue(
                        entries: entries,
                        initialIndex: initialIndex,
                        // Un contrôleur neuf à chaque chargement, comme en
                        // vrai : revenir sur une vidéo déjà vue en rouvre un
                        // autre. La table garde le dernier créé par source,
                        // qui est celui qu'on interroge ensuite.
                        controllerFactory: (uri) =>
                            controllers[uri.toString()] =
                                _FakeVideoPlayerController(),
                      ),
                    ),
                  ),
                  child: const Text('ouvrir'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('ouvrir'));
      await tester.pumpAndSettle();
    }

    testWidgets('la file s’ouvre sur la vidéo demandée', (tester) async {
      await pumpQueue(tester, buildEntries(3), initialIndex: 1);

      expect(find.text('Vidéo numéro 2'), findsOneWidget);
      expect(find.text('2 / 3'), findsOneWidget);
      expect(find.text('Vidéo 2 sur 3'), findsOneWidget);
      expect(
        controllers.keys,
        contains('https://example.test/clip-2.mp4'),
      );
    });

    testWidgets('« Suivante » et « Précédente » changent de vidéo', (
      tester,
    ) async {
      await pumpQueue(tester, buildEntries(3));

      expect(find.text('1 / 3'), findsOneWidget);

      await tester.tap(find.text('Suivante'));
      await tester.pumpAndSettle();

      expect(find.text('Vidéo numéro 2'), findsOneWidget);
      expect(find.text('2 / 3'), findsOneWidget);
      expect(
        controllers['https://example.test/clip-2.mp4']!.calls,
        contains('play'),
      );

      await tester.tap(find.text('Précédente'));
      await tester.pumpAndSettle();

      expect(find.text('Vidéo numéro 1'), findsOneWidget);
      expect(find.text('1 / 3'), findsOneWidget);
    });

    testWidgets('aux extrémités, la navigation est désactivée', (tester) async {
      await pumpQueue(tester, buildEntries(2));

      final previous = tester.widget<OutlinedButton>(
        find.ancestor(
          of: find.text('Précédente'),
          matching: find.byType(OutlinedButton),
        ),
      );
      expect(previous.onPressed, isNull);

      await tester.tap(find.text('Suivante'));
      await tester.pumpAndSettle();

      final next = tester.widget<OutlinedButton>(
        find.ancestor(
          of: find.text('Suivante'),
          matching: find.byType(OutlinedButton),
        ),
      );
      expect(next.onPressed, isNull);
    });

    testWidgets('une décision appliquée enchaîne sur la vidéo suivante', (
      tester,
    ) async {
      final decided = <String>[];
      await pumpQueue(
        tester,
        buildEntries(
          3,
          onDecision: (videoId) async {
            decided.add(videoId);
            return true;
          },
        ),
      );

      await tester.tap(find.text('Approuver'));
      await tester.pumpAndSettle();

      expect(decided, ['video-1']);
      // La vidéo traitée quitte la file : il en reste deux, et on est sur la
      // suivante sans repasser par la liste.
      expect(find.byType(VideoPlayerScreen), findsOneWidget);
      expect(find.text('Vidéo numéro 2'), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);
    });

    testWidgets('la dernière décision de la file referme le lecteur', (
      tester,
    ) async {
      await pumpQueue(
        tester,
        buildEntries(1, onDecision: (_) async => true),
      );

      await tester.tap(find.text('Approuver'));
      await tester.pumpAndSettle();

      expect(find.byType(VideoPlayerScreen), findsNothing);
    });

    testWidgets('une décision annulée ne fait pas avancer la file', (
      tester,
    ) async {
      await pumpQueue(
        tester,
        buildEntries(3, onDecision: (_) async => false),
      );

      await tester.tap(find.text('Approuver'));
      await tester.pumpAndSettle();

      expect(find.text('Vidéo numéro 1'), findsOneWidget);
      expect(find.text('1 / 3'), findsOneWidget);
    });

    testWidgets('les réglages de lecture survivent au changement de vidéo', (
      tester,
    ) async {
      await pumpQueue(tester, buildEntries(2));

      await tester.tap(find.byTooltip('Vitesse de lecture (S)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('0,5x').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Couper le son (M)'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Suivante'));
      await tester.pumpAndSettle();

      // Un opérateur qui a choisi 0,5x et coupé le son ne veut pas le refaire
      // à chaque vidéo de la file.
      final next = controllers['https://example.test/clip-2.mp4']!;
      expect(next.value.playbackSpeed, 0.5);
      expect(next.value.volume, 0);
      expect(find.text('0,5x'), findsOneWidget);
    });
  });
}
