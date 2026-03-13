import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/config/api_config.dart';
import '../../data/datasources/audio_api_client.dart';
import '../../domain/entities/speech_item.dart';
import '../controllers/dashboard_controller.dart';
import '../detail/detail_screen.dart';
import '../record/record_screen.dart';

class DashboardScreen extends GetView<DashboardController> {
  const DashboardScreen({super.key});

  Future<void> _showServerUrlDialog(BuildContext context) async {
    final url = await getSavedBaseUrl() ?? kBaseUrl;
    if (!context.mounted) return;
    final textController = TextEditingController(text: url);

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Server URL'),
        content: TextField(
          controller: textController,
          decoration: const InputDecoration(
            hintText: 'http://192.168.1.5:8000',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.url,
          autofocus: true,
          onSubmitted: (_) => Navigator.of(ctx).pop(true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved != true || !context.mounted) return;
    final newUrl = textController.text.trim();
    if (newUrl.isEmpty) return;
    await setSavedBaseUrl(newUrl);
    Get.find<AudioApiClient>().updateBaseUrl(newUrl);
    controller.load();
    controller.loadStats();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Server set to $newUrl. Data refreshed.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final titles = ['Home', 'Record', 'Recordings'];
      final title = titles[controller.currentTabIndex.value.clamp(0, 2)];
      return Scaffold(
        appBar: AppBar(
          title: Text(title),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_ethernet_rounded),
              tooltip: 'Server URL',
              onPressed: () => _showServerUrlDialog(context),
            ),
          ],
        ),
        body: IndexedStack(
          index: controller.currentTabIndex.value.clamp(0, 2),
          children: [
            _HomeTab(controller: controller),
            const RecordScreen(),
            _RecordingsListTab(controller: controller),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: NavigationBar(
            selectedIndex: controller.currentTabIndex.value.clamp(0, 2),
            onDestinationSelected: controller.setTab,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.mic_none_outlined),
                selectedIcon: Icon(Icons.mic_rounded),
                label: 'Record',
              ),
              NavigationDestination(
                icon: Icon(Icons.queue_music_outlined),
                selectedIcon: Icon(Icons.queue_music_rounded),
                label: 'Recordings',
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _HomeTab extends StatelessWidget {
  final DashboardController controller;

  const _HomeTab({required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Obx(() {
      if (controller.statsLoading.value) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator.adaptive(),
              const SizedBox(height: 16),
              Text(
                'Loading progress…',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      }
      final s = controller.stats.value;
      if (s == null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.cloud_off_rounded,
                  size: 64,
                  color: colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  'Could not load progress',
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => controller.loadStats(),
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      }

      return RefreshIndicator(
        onRefresh: () => controller.loadStats(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Your progress',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Swahili recordings submitted',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${s.submitted} of ${s.total}',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${s.progressPercent}%',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: s.progressFraction,
                          minHeight: 10,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: _StatChip(
                              icon: Icons.check_circle_rounded,
                              label: 'Submitted',
                              value: '${s.submitted}',
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatChip(
                              icon: Icons.pending_rounded,
                              label: 'Pending',
                              value: '${s.pending}',
                              color: colorScheme.tertiary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: () => controller.setTab(1),
                icon: const Icon(Icons.queue_music_rounded, size: 22),
                label: const Text('Go to Recordings'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 28, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordingsListTab extends StatelessWidget {
  final DashboardController controller;

  const _RecordingsListTab({required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Obx(() {
      if (controller.loading.value && controller.items.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator.adaptive(),
              const SizedBox(height: 16),
              Text(
                'Loading recordings…',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      }
      if (controller.error.isNotEmpty && controller.items.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 64,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  controller.error.value,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => controller.load(),
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      }
      if (controller.items.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.queue_music_rounded,
                size: 80,
                color: theme.colorScheme.outline.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'No recordings yet',
                style: theme.textTheme.titleMedium,
              ),
              Text(
                'Upload English audio from the API to get started',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }

      return RefreshIndicator(
        onRefresh: () => controller.load(),
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: controller.items.length + (controller.loadingMore.value ? 1 : 0) + 1,
          itemBuilder: (context, index) {
            if (index == controller.items.length) {
              if (controller.loadingMore.value) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator.adaptive()),
                );
              }
              if (controller.hasMore) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: OutlinedButton(
                      onPressed: controller.loadMore,
                      child: const Text('Load more'),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            }
            if (index > controller.items.length) {
              return const SizedBox.shrink();
            }
            final item = controller.items[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SpeechItemTile(
                item: item,
                onTap: () {
                  Get.to(() => DetailScreen(itemId: item.id, item: item))?.then((_) {
                    controller.load();
                  });
                },
              ),
            );
          },
        ),
      );
    });
  }
}

class _SpeechItemTile extends StatelessWidget {
  final SpeechItem item;
  final VoidCallback onTap;

  const _SpeechItemTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: item.isSubmitted
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  item.isSubmitted ? Icons.check_rounded : Icons.mic_rounded,
                  color: item.isSubmitted
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.textEnglish != null && item.textEnglish!.isNotEmpty
                          ? (item.textEnglish!.length > 40
                                ? '${item.textEnglish!.substring(0, 40)}…'
                                : item.textEnglish!)
                          : (item.id.length > 10 ? '${item.id.substring(0, 10)}…' : item.id),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.lengthEnglish.toStringAsFixed(1)}s • ${item.status}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: item.isSubmitted
                      ? colorScheme.primaryContainer
                      : colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  item.status,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: item.isSubmitted
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onTertiaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
