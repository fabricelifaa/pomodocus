import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/providers.dart';
import '../../../core/services/update_service.dart';
import '../../../shared/widgets/pomodocus_logo.dart';

final _versionProvider = FutureProvider<AppVersionInfo>(
  (ref) => ref.read(updateServiceProvider).versionInfo(),
);

class AboutScreen extends ConsumerStatefulWidget {
  const AboutScreen({super.key});

  @override
  ConsumerState<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends ConsumerState<AboutScreen> {
  UpdateState? _state;
  bool _busy = false;

  Future<void> _check() async {
    setState(() => _busy = true);
    final s = await ref.read(updateServiceProvider).check();
    if (!mounted) return;
    setState(() {
      _state = s;
      _busy = false;
    });
  }

  Future<void> _download() async {
    setState(() {
      _state = UpdateState.downloading;
      _busy = true;
    });
    final s = await ref.read(updateServiceProvider).download();
    if (!mounted) return;
    setState(() {
      _state = s;
      _busy = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _check();
  }

  @override
  Widget build(BuildContext context) {
    final version = ref.watch(_versionProvider).value;
    final t = Theme.of(context).textTheme;
    final p = context.phase;
    final (icon, label) = switch (_state) {
      null => (Icons.sync_rounded, 'Vérification…'),
      UpdateState.unavailable => (
        Icons.cloud_off_rounded,
        'Mises à jour instantanées indisponibles sur cette version '
            '(build de développement).',
      ),
      UpdateState.upToDate => (
        Icons.check_circle_rounded,
        'Pomodocus est à jour.',
      ),
      UpdateState.available => (
        Icons.system_update_rounded,
        'Une mise à jour est disponible.',
      ),
      UpdateState.downloading => (Icons.downloading_rounded, 'Téléchargement…'),
      UpdateState.restartRequired => (
        Icons.restart_alt_rounded,
        'Mise à jour téléchargée : elle sera appliquée au prochain démarrage.',
      ),
      UpdateState.failed => (
        Icons.error_outline_rounded,
        'Échec de la vérification. Réessayez plus tard.',
      ),
    };

    return Scaffold(
      appBar: AppBar(title: const Text('À propos')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          const Center(child: PomodocusSymbol(size: 88)),
          const SizedBox(height: 16),
          Center(child: Text('pomodocus', style: t.headlineMedium)),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'FOCUS. WORK. REPEAT.',
              style: t.labelSmall!.copyWith(color: p.focus, letterSpacing: 3),
            ),
          ),
          const SizedBox(height: 4),
          Center(child: Text('Focus on what matters.', style: t.bodySmall)),
          const SizedBox(height: 28),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.tag_rounded),
                  title: const Text('Version'),
                  trailing: Text(version?.label ?? '…', style: t.bodyMedium),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(icon, color: p.muted),
                          const SizedBox(width: 12),
                          Expanded(child: Text(label, style: t.bodyMedium)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          OutlinedButton(
                            onPressed: _busy ? null : _check,
                            child: const Text('Vérifier'),
                          ),
                          const SizedBox(width: 12),
                          if (_state == UpdateState.available)
                            FilledButton(
                              onPressed: _busy ? null : _download,
                              child: const Text('Télécharger'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Les correctifs sont livrés en arrière-plan et appliqués au '
            'redémarrage. Les nouvelles versions majeures passent par le store. '
            'Vos données restent sur votre téléphone : aucun compte, aucune '
            'collecte.',
            style: t.bodySmall,
          ),
        ],
      ),
    );
  }
}
