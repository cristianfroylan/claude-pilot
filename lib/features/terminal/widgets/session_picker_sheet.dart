import 'package:flutter/material.dart';

/// Bottom sheet shown once after SSH connects (shell ready) if the machine has
/// at least one configured folder path.
///
/// Non-dismissible — the user must tap a folder or "Start blank" to exit.
/// Drag handle is decorative only (enableDrag is false in the caller — PICK-01).
class SessionPickerSheet extends StatelessWidget {
  /// The list of folder paths to display.
  final List<String> folderPaths;

  /// Called with the selected path when the user taps a folder row.
  /// The caller is responsible for sending `cd <path>\n` to the SSH shell.
  final void Function(String path) onFolderSelected;

  const SessionPickerSheet({
    super.key,
    required this.folderPaths,
    required this.onFolderSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle — decorative, matches VoiceBottomSheet exactly.
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // lg (24 dp) spacing between handle and title.
              const SizedBox(height: 24),

              // Sheet title — left-aligned, semibold.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Choose a project',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),

              const SizedBox(height: 16),

              // Folder list — shrinkWrap so it doesn't fight the SingleChildScrollView.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: folderPaths.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    return Semantics(
                      label: 'Open session in ${folderPaths[index]}',
                      child: ListTile(
                        tileColor: colorScheme.surfaceContainerHighest,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        leading: Icon(
                          Icons.folder_outlined,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        title: Text(
                          folderPaths[index],
                          style: const TextStyle(fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () {
                          Navigator.of(context).pop(); // pop FIRST (synchronous)
                          onFolderSelected(folderPaths[index]); // callback AFTER pop
                        },
                      ),
                    );
                  },
                ),
              ),

              // Divider with sm (8 dp) vertical padding above and below.
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(),
              ),

              // "Start blank" — full-width button, left-aligned text.
              Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  32 + MediaQuery.of(context).padding.bottom,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.onSurfaceVariant,
                    ),
                    child: const Text('Start blank'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
