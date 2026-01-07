import 'package:flutter/material.dart';

// Material 3 add UX: modal bottom sheet with an input + autocomplete.
// Returns the exercise name if the user confirms, otherwise null.
Future<String?> showAddExerciseSheet(
  BuildContext context, {
    required List<String> suggestions,
    required Set<String> alreadyAddedKeysLower,
    bool loadingSuggestions = false,
    String title = 'Add exercise',
    String hintText = 'Exercise name',
    String confirmText = 'Add',
    String cancelText = 'Cancel',
    IconData icon = Icons.fitness_center_rounded,
  }) async
{
  String? errorText;
  TextEditingController? fieldController;

  final result = await showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx)
    {
      final theme = Theme.of(ctx);
      final mq = MediaQuery.of(ctx);
      final bottomInset = (mq.viewInsets.bottom > 0)
          ? mq.viewInsets.bottom
          : mq.viewPadding.bottom;

      void tryAdd(StateSetter setSheetState)
      {
        final raw = fieldController?.text ?? '';
        final name = raw.trim();

        if (name.isEmpty)
        {
          setSheetState(() => errorText = 'Name cannot be empty.');
          return;
        }

        final key = name.toLowerCase();
        if (alreadyAddedKeysLower.contains(key))
        {
          setSheetState(() => errorText = 'Exercise already added.');
          return;
        }

        Navigator.of(ctx).pop(name);
      }

      return StatefulBuilder(
        builder: (context, setSheetState)
        {
          return AnimatedPadding(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(bottom: bottomInset),
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(icon, color: theme.colorScheme.primary),
                    title: Text(title, style: theme.textTheme.titleLarge),
                    subtitle: const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text('Type a new exercise.'),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Autocomplete<String>(
                    optionsBuilder: (value)
                    {
                      final q = value.text.trim().toLowerCase();
                      if (q.isEmpty) return const Iterable<String>.empty();

                      return suggestions.where((s)
                      {
                        final key = s.toLowerCase();
                        if (alreadyAddedKeysLower.contains(key)) return false;
                        return key.contains(q);
                      });
                    },
                    displayStringForOption: (s) => s,
                    onSelected: (selection)
                    {
                      fieldController?.text = selection;
                      setSheetState(() => errorText = null);
                    },
                    fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted)
                    {
                      // ADDED: capture the controller so tryAdd() can read it
                      fieldController ??= textController;

                      return TextField(
                        controller: textController,
                        focusNode: focusNode,
                        autofocus: true,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: hintText,
                          errorText: errorText,
                          suffixIcon: loadingSuggestions
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                )
                              : null,
                        ),
                        onChanged: (_) {
                          if (errorText != null) {
                            setSheetState(() => errorText = null);
                          }
                        },
                        onSubmitted: (_) => tryAdd(setSheetState),
                      );
                    },
                  ),

                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(ctx).pop(null),
                          child: Text(cancelText),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => tryAdd(setSheetState),
                          child: Text(confirmText),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  return result;
}