import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../data/repositories/audio_repository.dart';

class DetailScreen extends StatefulWidget {
  final String itemId;

  const DetailScreen({super.key, required this.itemId});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  final AudioPlayer _englishPlayer = AudioPlayer();
  final AudioPlayer _swahiliPlayer = AudioPlayer();
  final AudioRecorder _recorder = AudioRecorder();

  late final AudioRepository _repo = Get.find<AudioRepository>();

  String? _recordedPath;
  bool _hasTestedPlayback = false;
  bool _isRecording = false;
  bool _isPlayingEnglish = false;
  bool _isPlayingSwahili = false;
  bool _isSubmitting = false;
  String? _submitError;

  @override
  void dispose() {
    _englishPlayer.dispose();
    _swahiliPlayer.dispose();
    super.dispose();
  }

  Future<void> _playEnglish() async {
    final url = _repo.getEnglishAudioUrl(widget.itemId);
    setState(() => _isPlayingEnglish = true);
    try {
      await _englishPlayer.play(UrlSource(url));
      await _englishPlayer.onPlayerComplete.first;
    } catch (_) {}
    if (mounted) {
      setState(() => _isPlayingEnglish = false);
    }
  }

  Future<void> _startRecording() async {
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/swahili_${widget.itemId}.wav';
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission required')),
        );
      }
      return;
    }
    setState(() {
      _isRecording = true;
      _recordedPath = null;
      _hasTestedPlayback = false;
    });
    try {
      await _recorder.start(const RecordConfig(encoder: AudioEncoder.wav), path: path);
    } catch (e) {
      if (mounted) {
        setState(() => _isRecording = false);
      }
      return;
    }
    setState(() => _recordedPath = path);
  }

  Future<void> _stopRecording() async {
    await _recorder.stop();
    setState(() => _isRecording = false);
  }

  Future<void> _playRecordedSwahili() async {
    if (_recordedPath == null || !await File(_recordedPath!).exists()) return;
    setState(() => _isPlayingSwahili = true);
    try {
      await _swahiliPlayer.play(DeviceFileSource(_recordedPath!));
      await _swahiliPlayer.onPlayerComplete.first;
      if (mounted) {
        setState(() => _hasTestedPlayback = true);
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _isPlayingSwahili = false);
    }
  }

  Future<void> _submit() async {
    if (_recordedPath == null || !_hasTestedPlayback) {
      Get.snackbar(
        'Required',
        'Record Swahili and play it back to verify before submitting',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    final file = File(_recordedPath!);
    if (!await file.exists()) return;
    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });
    try {
      await _repo.submitSwahili(widget.itemId, file);
      if (mounted) {
        Get.snackbar('Success', 'Submitted successfully', snackPosition: SnackPosition.BOTTOM);
        Get.back(result: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _submitError = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _recordedPath != null && _hasTestedPlayback && !_isSubmitting;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Submit Swahili'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StepCard(
              step: 1,
              title: 'Play English',
              subtitle: 'Listen to the source clip',
              child: FilledButton(
                onPressed: _isPlayingEnglish ? null : _playEnglish,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isPlayingEnglish)
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator.adaptive(
                          strokeWidth: 2,
                        ),
                      )
                    else
                      Icon(Icons.play_arrow_rounded, color: colorScheme.onPrimary),
                    const SizedBox(width: 10),
                    Text(_isPlayingEnglish ? 'Playing…' : 'Play English'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _StepCard(
              step: 2,
              title: 'Record Swahili',
              subtitle: 'Record your translation',
              child: _isRecording
                  ? FilledButton.tonal(
                      onPressed: _stopRecording,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: colorScheme.errorContainer,
                        foregroundColor: colorScheme.onErrorContainer,
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.stop_rounded),
                          SizedBox(width: 10),
                          Text('Stop recording'),
                        ],
                      ),
                    )
                  : FilledButton(
                      onPressed: _startRecording,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.mic_rounded),
                          const SizedBox(width: 10),
                          Text(_recordedPath != null ? 'Re-record' : 'Record Swahili'),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            _StepCard(
              step: 3,
              title: 'Verify playback',
              subtitle: 'Play back your recording (required before submit)',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.tonal(
                    onPressed: _recordedPath == null || _isPlayingSwahili
                        ? null
                        : _playRecordedSwahili,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isPlayingSwahili)
                          SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator.adaptive(
                              strokeWidth: 2,
                            ),
                          )
                        else
                          const Icon(Icons.play_arrow_rounded),
                        const SizedBox(width: 10),
                        Text(
                          _hasTestedPlayback
                              ? 'Play again'
                              : (_isPlayingSwahili ? 'Playing…' : 'Play to verify'),
                        ),
                      ],
                    ),
                  ),
                  if (_hasTestedPlayback) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 20,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Verified — ready to submit',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (_submitError != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded, color: colorScheme.error, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _submitError!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 28),
            FilledButton(
              onPressed: canSubmit ? _submit : null,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
              ),
              child:                   _isSubmitting
                      ? SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator.adaptive(
                            strokeWidth: 2,
                          ),
                        )
                  : const Text('Submit Swahili'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final int step;
  final String title;
  final String subtitle;
  final Widget child;

  const _StepCard({
    required this.step,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$step',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
