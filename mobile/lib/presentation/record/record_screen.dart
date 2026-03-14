import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/repositories/audio_repository.dart';
import '../controllers/dashboard_controller.dart';
import '../detail/detail_screen.dart';

/// Dedicated recording screen: type English (backend TTS) or pick a pending sentence to record Swahili.
class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  final _textController = TextEditingController();
  bool _speakLoading = false;
  String? _speakError;
  int _mode = 0; // 0 = Type English, 1 = Pick sentence

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _generateAndRecord() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      Get.snackbar('Required', 'Enter an English sentence', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    setState(() {
      _speakLoading = true;
      _speakError = null;
    });
    try {
      final repo = Get.find<AudioRepository>();
      final id = await repo.createFromTextAndSpeak(text);
      if (!mounted) return;
      setState(() => _speakLoading = false);
      Get.snackbar('Ready', 'Opening record screen…', snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 1));
      await Get.to(() => DetailScreen(itemId: id, initialTextEnglish: text));
      final ctrl = Get.find<DashboardController>();
      ctrl.load();
      ctrl.loadStats();
    } catch (e) {
      if (mounted) {
        final is404 = e is DioException && e.response?.statusCode == 404;
        setState(() {
          _speakLoading = false;
          _speakError = is404
              ? 'Backend doesn\'t support "Generate from text" yet. Redeploy your backend (Railway) so the /api/audio/english/speak endpoint is available.'
              : e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final controller = Get.find<DashboardController>();

    return Obx(() {
      final pendingItems = controller.items.where((e) => !e.isSubmitted).toList();
      final loading = controller.loading.value;

      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Type English'), icon: Icon(Icons.edit_rounded)),
                ButtonSegment(value: 1, label: Text('Pick sentence'), icon: Icon(Icons.list_rounded)),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
            const SizedBox(height: 24),
            if (_mode == 0) ...[
              Text('English sentence:', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              TextField(
                controller: _textController,
                decoration: const InputDecoration(
                  hintText: 'e.g. Where are you going?',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
                textInputAction: TextInputAction.done,
              ),
              if (_speakError != null) ...[
                const SizedBox(height: 8),
                Text(_speakError!, style: TextStyle(color: colorScheme.error, fontSize: 12)),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _speakLoading ? null : _generateAndRecord,
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: _speakLoading
                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator.adaptive(strokeWidth: 2))
                    : const Text('Generate & record Swahili'),
              ),
              const SizedBox(height: 16),
              Text(
                'Backend will generate English audio from your text, then you can record the Swahili translation.',
                style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ] else ...[
              if (loading && controller.items.isEmpty)
                const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator.adaptive()))
              else if (pendingItems.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No pending sentences. Type your own above or run the script to add English sentences.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                )
              else
                ...pendingItems.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        onTap: () async {
                          await Get.to(() => DetailScreen(itemId: item.id, item: item));
                          controller.load();
                          controller.loadStats();
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              Icon(Icons.mic_rounded, color: colorScheme.primary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  item.textEnglish != null && item.textEnglish!.isNotEmpty
                                      ? (item.textEnglish!.length > 50
                                            ? '${item.textEnglish!.substring(0, 50)}…'
                                            : item.textEnglish!)
                                      : item.id,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                              Icon(Icons.chevron_right_rounded, color: colorScheme.onSurfaceVariant),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              if (controller.hasMore && !loading)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextButton(
                    onPressed: controller.loadMore,
                    child: const Text('Load more'),
                  ),
                ),
            ],
          ],
        ),
      );
    });
  }
}
