import 'package:flutter/material.dart';

/// Full-screen semi-transparent overlay shown during initial connection failures.
///
/// Renders over the terminal area while [SshConnecting] state is active, showing
/// the current attempt number, a countdown to the next retry, and a Cancel button.
/// The overlay does not unmount the terminal — it sits in a Stack above it.
class ReconnectOverlay extends StatelessWidget {
  const ReconnectOverlay({
    super.key,
    required this.attempt,
    required this.maxAttempts,
    required this.secondsLeft,
    required this.onCancel,
  });

  /// Current attempt number (1-based).
  final int attempt;

  /// Maximum number of initial connection attempts (5 per RECON-01).
  final int maxAttempts;

  /// Seconds remaining before the next retry fires. When <= 0, connecting is
  /// in progress (no countdown to show).
  final int secondsLeft;

  /// Called when the user taps Cancel. Should invoke notifier.cancel().
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final countdownText = secondsLeft > 0
        ? 'Attempt $attempt/$maxAttempts — retrying in ${secondsLeft}s'
        : 'Attempt $attempt/$maxAttempts — connecting…';

    return Container(
      color: colorScheme.surface.withValues(alpha: 0.85),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              countdownText,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onCancel,
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen overlay shown when all automatic retries have been exhausted.
///
/// Provides a Retry button so the user can attempt one more manual connection
/// (RECON-04). The terminal remains mounted beneath this overlay so the user
/// can read prior output.
class ReconnectFailedOverlay extends StatelessWidget {
  const ReconnectFailedOverlay({
    super.key,
    required this.onRetry,
  });

  /// Called when the user taps Retry. Should invoke notifier.reconnect().
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      color: colorScheme.surface.withValues(alpha: 0.85),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off,
              size: 48,
              color: colorScheme.onSurface,
            ),
            const SizedBox(height: 16),
            Text(
              'Connection lost',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'All retry attempts failed.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
