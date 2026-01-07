import 'package:flutter/material.dart';

// Material 3 confirm UX: modal bottom sheet with a destructive action.
// Returns true if the user confirms.

Future<bool> showDestructiveConfirmSheet(
  BuildContext context, {
    required String title,
    required String message,
    required String confirmText,
    String cancelText = 'Cancel',
    IconData icon = Icons.warning_amber_rounded,
  }) async
{
  final result = await showModalBottomSheet<bool>(
    context: context,
    useSafeArea: true,
    isScrollControlled: false,
    showDragHandle: true,
    builder: (ctx)
    {
      final theme = Theme.of(ctx);
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon( icon, color: theme.colorScheme.error),
              title: Text(title, style: theme.textTheme.titleLarge),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(message),
              )
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text(cancelText),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.error,
                      foregroundColor: theme.colorScheme.onError,
                    ),
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: Text(confirmText),
                  )
                )
              ]
            )
          ]
        )
      );
    }
  );

  return result ?? false;
}