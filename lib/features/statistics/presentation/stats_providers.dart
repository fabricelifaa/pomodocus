import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../domain/stats_summary.dart';

final statsProvider = StreamProvider<StatsSummary>((ref) {
  final clock = ref.watch(clockProvider);
  final repo = ref.watch(sessionRepositoryProvider);
  final since = StatsSummary.windowStart(clock.now());
  return repo
      .watchSince(since)
      .map((sessions) => StatsSummary.from(sessions, clock.now()));
});
