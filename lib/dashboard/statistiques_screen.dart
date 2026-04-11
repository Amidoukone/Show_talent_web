import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controller/user_controller.dart';
import '../controller/video_controller.dart';
import '../theme/admin_theme.dart';
import '../utils/account_role_policy.dart';
import '../widgets/admin_ui.dart';

class StatisticsScreen extends StatelessWidget {
  StatisticsScreen({super.key});

  final UserController userController = Get.find<UserController>();
  final VideoController videoController = Get.find<VideoController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AdminAppBackground(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1380),
            child: SingleChildScrollView(
              child: StatisticsOverviewPanel(
                userController: userController,
                videoController: videoController,
                showStandaloneHeader: true,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class StatisticsOverviewPanel extends StatelessWidget {
  const StatisticsOverviewPanel({
    required this.userController,
    required this.videoController,
    this.showStandaloneHeader = false,
    super.key,
  });

  final UserController userController;
  final VideoController videoController;
  final bool showStandaloneHeader;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
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

      final totalUsers = users.length;
      final totalVideos = videos.length;
      final reportRate =
          totalVideos == 0 ? 0.0 : reportedVideos.length / totalVideos;
      final managedRate = totalUsers == 0 ? 0.0 : managedUsers / totalUsers;
      final activeRate = totalUsers == 0 ? 0.0 : activeUsers / totalUsers;
      final disabledRate =
          totalUsers == 0 ? 0.0 : authDisabledUsers / totalUsers;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showStandaloneHeader) ...[
            AdminGlassPanel(
              padding: const EdgeInsets.all(26),
              highlight: true,
              accentColor: AdminTheme.accent,
              child: const AdminSectionHeader(
                badge: 'Pilotage',
                title: 'Tableau de statistiques',
                subtitle:
                    'Vue consolidée sur les utilisateurs, la modération et les comptes gérés.',
              ),
            ),
            const SizedBox(height: 20),
          ],
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              SizedBox(
                width: 280,
                child: AdminMetricCard(
                  title: 'Utilisateurs',
                  value: '$totalUsers',
                  subtitle: '$activeUsers actifs dans le portail',
                  icon: Icons.groups_2_rounded,
                  progress: activeRate,
                ),
              ),
              SizedBox(
                width: 280,
                child: AdminMetricCard(
                  title: 'Comptes gérés',
                  value: '$managedUsers',
                  subtitle: 'Club, recruteur et agent',
                  icon: Icons.manage_accounts_rounded,
                  progress: managedRate,
                  accentColor: AdminTheme.cyan,
                ),
              ),
              SizedBox(
                width: 280,
                child: AdminMetricCard(
                  title: 'Vidéos publiées',
                  value: '$totalVideos',
                  subtitle: '${reportedVideos.length} vidéos signalées',
                  icon: Icons.play_circle_outline_rounded,
                  progress: 1,
                  accentColor: AdminTheme.accentSoft,
                ),
              ),
              SizedBox(
                width: 280,
                child: AdminMetricCard(
                  title: 'Alertes moderation',
                  value: '$authDisabledUsers',
                  subtitle: 'Accès Auth désactivés',
                  icon: Icons.lock_person_rounded,
                  progress: disabledRate,
                  accentColor: AdminTheme.warning,
                ),
              ),
            ],
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
                      subtitle:
                          'Lecture rapide des volumes admin actuellement exposés dans le portail.',
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 280,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: [
                            totalUsers.toDouble(),
                            managedUsers.toDouble(),
                            totalVideos.toDouble(),
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
                                      color: AdminTheme.textMuted,
                                      fontSize: 11,
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
                                    'Auth off',
                                  ];

                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      labels[value.toInt()],
                                      style: const TextStyle(
                                        color: AdminTheme.textSecondary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          barGroups: [
                            _barGroup(0, totalUsers, AdminTheme.accent),
                            _barGroup(1, managedUsers, AdminTheme.cyan),
                            _barGroup(2, totalVideos, AdminTheme.accentSoft),
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
                  AdminGlassPanel(
                    padding: const EdgeInsets.all(22),
                    highlight: true,
                    accentColor: AdminTheme.cyan,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AdminSectionHeader(
                          title: 'Signaux clés',
                          subtitle:
                              'Quelques ratios utiles pour lire l’état de la plateforme.',
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
                          label: 'Comptes gérés',
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
                          label: 'Auth désactivée',
                          value: '${(disabledRate * 100).round()}%',
                          progress: disabledRate,
                          color: AdminTheme.danger,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const AdminInfoBanner(
                    title: 'Lecture admin',
                    message:
                        'Cette vue reste purement front et n’impacte aucune logique métier. Elle reformule uniquement les données déjà présentes dans les controllers.',
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
