import 'package:flutter/material.dart';

/// Compact inline banner pinned to the top of the terminal during mid-session
/// reconnection ([SshReconnecting] state).
///
/// Shows attempt counter, countdown, and a Cancel button in a single row. The
/// terminal scrollback remains fully visible below this banner (RECON-02).
/// Uses [AnimatedContainer] for a smooth slide-in transition (200 ms).
class ReconnectBanner extends StatelessWidget {
  const ReconnectBanner({
    super.key,
    required this.attempt,
    required this.maxAttempts,
    required this.secondsLeft,
    required this.onCancel,
  });

  /// Current reconnection attempt number (1-based).
  final int attempt;

  /// Maximum number of mid-session reconnection attempts (3 per RECON-02).
  final int maxAttempts;

  /// Seconds remaining before the next retry fires. When <= 0, reconnection is
  /// actively in progress (no countdown to show).
  final int secondsLeft;

  /// Called when the user taps Cancel. Should invoke notifier.cancel().
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final bannerText = secondsLeft > 0
        ? 'Connection lost · Attempt $attempt/$maxAttempts · Retry in ${secondsLeft}s'
        : 'Connection lost · Attempt $attempt/$maxAttempts · Reconnecting…';

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        top: true,
        bottom: false,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 44,
          color: colorScheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.onErrorContainer,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    bannerText,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onErrorContainer,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: onCancel,
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.onErrorContainer,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
