import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controller/user_controller.dart';
import '../controller/video_controller.dart';
import '../theme/admin_theme.dart';
import '../utils/account_role_policy.dart';
import '../widgets/admin_ui.dart';

class StatisticsOverviewPanel extends StatelessWidget {
  const StatisticsOverviewPanel({
    required this.userController,
    required this.videoController,
    super.key,
  });

  final UserController userController;
  final VideoController videoController;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (userController.isLoading.value || videoController.isLoading.value) {
        return const Center(
          child: AdminLoadingState(
            message: 'Chargement des statistiques...',
          ),
        );
      }

      final users = userController.userList;
      final videos = videoController.videoList;
      final reportedVideos = videoController.getReportedVideos();
      final authDisabledUsers = users.where((user) => user.authDisabled).length;
      final managedUsers = users
          .where(
            (user) => user.createdByAdmin || isManagedAccountRole(user.role),
          )
          .length;
      final activeUsers =
          users.where((user) => user.isEffectivelyActiveAccount).length;

      // totalUsersSample/totalVideosSample restent la fenêtre chargée
      // (plafonnée, voir UserController/VideoController) : c'est le seul
      // dénominateur disponible pour les ratios ci-dessous, qui portent sur
      // des champs (actif, suspendu, géré, signalé) qu'on ne peut pas agréger
      // côté Firestore sans lire les documents. Les totaux "Utilisateurs" et
      // "Vidéos publiées" affichés, eux, viennent d'un compte exact
      // (totalUsersCount/totalVideosCount) : avant ce correctif, l'écran
      // affichait silencieusement la taille de la fenêtre chargée comme si
      // c'était le total de la plateforme.
      final totalUsersSample = users.length;
      final totalVideosSample = videos.length;
      final exactTotalUsers = userController.totalUsersCount.value;
      final exactTotalVideos = videoController.totalVideosCount.value;
      final displayedTotalUsers = exactTotalUsers ?? totalUsersSample;
      final displayedTotalVideos = exactTotalVideos ?? totalVideosSample;
      final sampleTruncated =
          userController.hasMoreUsers.value || videoController.hasMore.value;

      final reportRate = totalVideosSample == 0
          ? 0.0
          : reportedVideos.length / totalVideosSample;
      final cleanVideoRate = totalVideosSample == 0 ? 0.0 : 1 - reportRate;
      final managedRate =
          totalUsersSample == 0 ? 0.0 : managedUsers / totalUsersSample;
      final activeRate =
          totalUsersSample == 0 ? 0.0 : activeUsers / totalUsersSample;
      final disabledRate =
          totalUsersSample == 0 ? 0.0 : authDisabledUsers / totalUsersSample;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (sampleTruncated) ...[
            AdminInfoBanner(
              title: 'Indicateurs partiels',
              message:
                  'Les totaux « Utilisateurs » et « Vidéos publiées » sont exacts. '
                  'Les autres chiffres (actifs, gérés, suspendus, signalées) restent '
                  'calculés sur les $totalUsersSample derniers comptes et '
                  '$totalVideosSample dernières vidéos chargés — chargez-en davantage '
                  "depuis les onglets Utilisateurs et Vidéos pour affiner ces ratios.",
              icon: Icons.warning_amber_rounded,
              tone: AdminBannerTone.warning,
            ),
            const SizedBox(height: 18),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth =
                  constraints.maxWidth < 280 ? constraints.maxWidth : 280.0;
              final metricCards = <Widget>[
                AdminMetricCard(
                  title: 'Utilisateurs',
                  value: '$displayedTotalUsers',
                  subtitle: sampleTruncated
                      ? '$activeUsers actifs sur $totalUsersSample chargés'
                      : '$activeUsers actifs dans le portail',
                  icon: Icons.groups_2_rounded,
                  progress: activeRate,
                ),
                AdminMetricCard(
                  title: "Comptes créés par l'administration",
                  value: '$managedUsers',
                  subtitle: sampleTruncated
                      ? 'Sur $totalUsersSample comptes chargés'
                      : 'Comptes administrés',
                  icon: Icons.manage_accounts_rounded,
                  progress: managedRate,
                  accentColor: AdminTheme.cyan,
                ),
                AdminMetricCard(
                  title: 'Vidéos publiées',
                  value: '$displayedTotalVideos',
                  subtitle: sampleTruncated
                      ? '${reportedVideos.length} signalées sur $totalVideosSample chargées'
                      : '${reportedVideos.length} vidéos signalées',
                  icon: Icons.play_circle_outline_rounded,
                  progress: cleanVideoRate,
                  accentColor: AdminTheme.accentSoft,
                ),
                AdminMetricCard(
                  title: 'Accès suspendus',
                  value: '$authDisabledUsers',
                  subtitle: sampleTruncated
                      ? 'Sur $totalUsersSample comptes chargés'
                      : 'Comptes temporairement bloqués',
                  icon: Icons.lock_person_rounded,
                  progress: disabledRate,
                  accentColor: AdminTheme.warning,
                ),
              ];

              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: metricCards
                    .map(
                      (card) => SizedBox(
                        width: cardWidth,
                        child: card,
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final isStacked = constraints.maxWidth < 1100;

              final chartPanel = AdminGlassPanel(
                padding: const EdgeInsets.all(22),
                highlight: true,
                accentColor: AdminTheme.accent,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AdminSectionHeader(
                      title: 'Activité globale',
                      subtitle: 'Lecture rapide des volumes clés du portail.',
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 280,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: [
                            displayedTotalUsers.toDouble(),
                            managedUsers.toDouble(),
                            displayedTotalVideos.toDouble(),
                            reportedVideos.length.toDouble(),
                            authDisabledUsers.toDouble(),
                          ].fold<double>(10, (current, value) {
                            return value > current ? value + 2 : current;
                          }),
                          borderData: FlBorderData(show: false),
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            getDrawingHorizontalLine: (value) {
                              return FlLine(
                                color: AdminTheme.borderSoft
                                    .withValues(alpha: 0.45),
                                strokeWidth: 1,
                              );
                            },
                          ),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 34,
                                getTitlesWidget: (value, meta) {
                                  return Text(
                                    value.toInt().toString(),
                                    style: const TextStyle(
                                      color: AdminTheme.textSecondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  );
                                },
                              ),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  const labels = [
                                    'Utilisateurs',
                                    'Gérés',
                                    'Vidéos',
                                    'Signalés',
                                    'Suspendus',
                                  ];
                                  final index = value.toInt();
                                  if (index < 0 || index >= labels.length) {
                                    return const SizedBox.shrink();
                                  }

                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      labels[index],
                                      style: const TextStyle(
                                        color: AdminTheme.textSecondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          barGroups: [
                            _barGroup(0, displayedTotalUsers, AdminTheme.accent),
                            _barGroup(1, managedUsers, AdminTheme.cyan),
                            _barGroup(
                                2, displayedTotalVideos, AdminTheme.accentSoft),
                            _barGroup(
                                3, reportedVideos.length, AdminTheme.warning),
                            _barGroup(4, authDisabledUsers, AdminTheme.danger),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );

              final sidePanel = Column(
                children: [
                  // Pas de highlight ici : le graphique ci-dessus porte déjà
                  // l'accent de l'écran, ce second panneau reste au second
                  // plan plutôt que de rivaliser avec lui.
                  AdminGlassPanel(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AdminSectionHeader(
                          title: 'Signaux clés',
                          subtitle:
                              "Quelques ratios utiles pour lire l'état de la plateforme.",
                        ),
                        const SizedBox(height: 18),
                        _SignalRow(
                          label: 'Utilisateurs actifs',
                          value: '${(activeRate * 100).round()}%',
                          progress: activeRate,
                          color: AdminTheme.accent,
                        ),
                        const SizedBox(height: 14),
                        _SignalRow(
                          label: 'Comptes administrés',
                          value: '${(managedRate * 100).round()}%',
                          progress: managedRate,
                          color: AdminTheme.cyan,
                        ),
                        const SizedBox(height: 14),
                        _SignalRow(
                          label: 'Vidéos signalées',
                          value: '${(reportRate * 100).round()}%',
                          progress: reportRate,
                          color: AdminTheme.warning,
                        ),
                        const SizedBox(height: 14),
                        _SignalRow(
                          label: 'Accès suspendus',
                          value: '${(disabledRate * 100).round()}%',
                          progress: disabledRate,
                          color: AdminTheme.danger,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const AdminInfoBanner(
                    title: 'Lecture opérationnelle',
                    message:
                        "Ces indicateurs aident à suivre l'activité, la modération et les accès sensibles.",
                    icon: Icons.auto_graph_rounded,
                    tone: AdminBannerTone.neutral,
                  ),
                ],
              );

              if (isStacked) {
                return Column(
                  children: [
                    chartPanel,
                    const SizedBox(height: 16),
                    sidePanel,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 7, child: chartPanel),
                  const SizedBox(width: 16),
                  Expanded(flex: 5, child: sidePanel),
                ],
              );
            },
          ),
        ],
      );
    });
  }

  BarChartGroupData _barGroup(int index, int value, Color color) {
    return BarChartGroupData(
      x: index,
      barRods: [
        BarChartRodData(
          toY: value.toDouble(),
          width: 18,
          borderRadius: BorderRadius.circular(10),
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              color.withValues(alpha: 0.64),
              color,
            ],
          ),
        ),
      ],
    );
  }
}

class _SignalRow extends StatelessWidget {
  const _SignalRow({
    required this.label,
    required this.value,
    required this.progress,
    required this.color,
  });

  final String label;
  final String value;
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: AdminTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress.clamp(0, 1),
            minHeight: 10,
            color: color,
            backgroundColor: AdminTheme.borderSoft,
          ),
        ),
      ],
    );
  }
}
