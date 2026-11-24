import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/providers.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/motion.dart';
import '../../focus/domain/entities/focus_session.dart';
import '../../focus/domain/entities/session_type.dart';
import '../domain/stats_summary.dart';
import 'stats_providers.dart';

class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Statistiques')),
      body: switch (stats) {
        AsyncData(:final value) when value.isEmpty => const _EmptyState(),
        AsyncData(:final value) => _StatsBody(
          stats: value,
          now: ref.read(clockProvider).now(),
        ),
        AsyncError() => _ErrorState(
          onRetry: () => ref.invalidate(statsProvider),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _StatsBody extends StatelessWidget {
  const _StatsBody({required this.stats, required this.now});
  final StatsSummary stats;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final p = context.phase;
    final t = Theme.of(context).textTheme;
    var i = 0;
    Duration next() => Duration(milliseconds: 60 * i++);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      children: [
        Text("AUJOURD'HUI", style: t.labelSmall),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: FadeSlideIn(
                  delay: next(),
                  child: _StatCard(
                    icon: Icons.timer_rounded,
                    color: p.focus,
                    value: formatDuration(stats.todayFocusSeconds),
                    label: 'concentré',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FadeSlideIn(
                  delay: next(),
                  child: _StatCard(
                    icon: Icons.check_circle_rounded,
                    color: p.shortBreak,
                    value: '${stats.todayCompleted}',
                    label: stats.todayCompleted > 1
                        ? 'sessions terminées'
                        : 'session terminée',
                    footnote: stats.todayInterrupted > 0
                        ? '${stats.todayInterrupted} interrompue${stats.todayInterrupted > 1 ? 's' : ''}'
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        FadeSlideIn(
          delay: next(),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('7 DERNIERS JOURS', style: t.labelSmall),
                  const SizedBox(height: 6),
                  Text(
                    formatDuration(stats.weekFocusSeconds),
                    style: t.headlineMedium,
                  ),
                  const SizedBox(height: 18),
                  SizedBox(height: 168, child: _WeekChart(days: stats.days)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text('SESSIONS RÉCENTES', style: t.labelSmall),
        const SizedBox(height: 10),
        FadeSlideIn(
          delay: next(),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var k = 0; k < stats.recent.length; k++) ...[
                  if (k > 0) const Divider(height: 1, indent: 64),
                  _SessionTile(session: stats.recent[k], now: now),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    this.footnote,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 14),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: t.headlineMedium),
            ),
            const SizedBox(height: 2),
            Text(label, style: t.bodySmall),
            if (footnote != null) ...[
              const SizedBox(height: 2),
              Text(footnote!, style: t.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

class _WeekChart extends StatelessWidget {
  const _WeekChart({required this.days});
  final List<DayStat> days;

  @override
  Widget build(BuildContext context) {
    final p = context.phase;
    final t = Theme.of(context).textTheme;
    final maxMin = days
        .map((d) => d.focusSeconds / 60)
        .fold<double>(0, (a, b) => a > b ? a : b);
    final top = maxMin < 30 ? 30.0 : (maxMin * 1.15);
    return BarChart(
      BarChartData(
        maxY: top,
        minY: 0,
        alignment: BarChartAlignment.spaceAround,
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: top / 3,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: p.track, strokeWidth: 1, dashArray: [4, 4]),
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => Theme.of(context).colorScheme.onSurface,
            getTooltipItem: (group, _, rod, _) => BarTooltipItem(
              formatDuration((rod.toY * 60).round()),
              t.labelMedium!.copyWith(
                color: Theme.of(context).scaffoldBackgroundColor,
              ),
            ),
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          topTitles: const AxisTitles(),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                final isToday = i == days.length - 1;
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    weekdayShort(days[i].day),
                    style: t.labelMedium!.copyWith(
                      color: isToday ? p.focus : p.muted,
                      fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < days.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: days[i].focusSeconds / 60,
                  width: 18,
                  color: i == days.length - 1
                      ? p.focus
                      : p.focus.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(6),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: top,
                    color: p.track.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
        ],
      ),
      duration: motionDuration(context, const Duration(milliseconds: 500)),
      curve: Curves.easeOutCubic,
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session, required this.now});
  final FocusSession session;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final p = context.phase;
    final t = Theme.of(context).textTheme;
    final color = p.forType(session.type);
    final done = session.isCompleted;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(
          switch (session.type) {
            SessionType.focus => Icons.center_focus_strong_rounded,
            SessionType.shortBreak => Icons.local_cafe_rounded,
            SessionType.longBreak => Icons.self_improvement_rounded,
          },
          color: color,
          size: 20,
        ),
      ),
      title: Text(sessionLabel(session.type), style: t.titleSmall),
      subtitle: Text(
        '${dayLabel(session.startedAt, now)} · ${formatTime(session.startedAt)}',
        style: t.bodySmall,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            formatDuration(session.actualDurationSeconds),
            style: t.titleSmall,
          ),
          const SizedBox(height: 2),
          Text(
            done ? 'Terminée' : 'Interrompue',
            style: t.labelMedium!.copyWith(
              color: done ? p.shortBreak : p.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: FadeSlideIn(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 180,
                height: 180,
                child: Lottie.asset(
                  'assets/lottie/empty_tomato.json',
                  animate: !reduceMotion(context),
                ),
              ),
              const SizedBox(height: 16),
              Text('Pas encore de session', style: t.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'Vos temps de concentration apparaîtront ici dès votre premier Pomodoro.',
                textAlign: TextAlign.center,
                style: t.bodyMedium!.copyWith(color: context.phase.muted),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.go('/focus'),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Lancer ma première session'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 48, color: context.phase.muted),
            const SizedBox(height: 16),
            Text(
              'Impossible de charger les statistiques',
              style: t.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Votre minuteur continue de fonctionner normalement.',
              textAlign: TextAlign.center,
              style: t.bodySmall,
            ),
            const SizedBox(height: 20),
            OutlinedButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}
