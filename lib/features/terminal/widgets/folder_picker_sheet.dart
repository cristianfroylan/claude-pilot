import 'package:flutter/material.dart';

/// Dialog shown when the user wants to navigate to a project folder.
/// Displays subdirectory names as a 4-column grid of small cards.
/// Dismissible via the X button or tapping outside.
class FolderPickerSheet extends StatelessWidget {
  final List<(String basePath, String name)> folders;
  final void Function(String basePath, String name) onFolderSelected;

  const FolderPickerSheet({
    super.key,
    required this.folders,
    required this.onFolderSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  '¿Dónde quieres iniciar?',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              ],
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.85,
              ),
              itemCount: folders.length,
              itemBuilder: (_, i) {
                final (basePath, name) = folders[i];
                return _FolderCard(
                  name: name,
                  bgColor: colorScheme.primaryContainer,
                  iconColor: colorScheme.onPrimaryContainer,
                  textColor: colorScheme.onPrimaryContainer,
                  onTap: () {
                    Navigator.of(context).pop();
                    onFolderSelected(basePath, name);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FolderCard extends StatelessWidget {
  final String name;
  final Color bgColor;
  final Color iconColor;
  final Color textColor;
  final VoidCallback onTap;

  const _FolderCard({
    required this.name,
    required this.bgColor,
    required this.iconColor,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.all(6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_rounded, size: 22, color: iconColor),
            const SizedBox(height: 4),
            Text(
              name,
              style: TextStyle(fontSize: 9, color: textColor, height: 1.2),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
