// lib/widgets/app_dialogs.dart
import 'package:flutter/material.dart';
import '../shared/theme.dart'; // ajuste se seu theme está em outro lugar

class AppDialogs {
  /// Dialogo de confirmação simples. Retorna true se confirmar.
  static Future<bool?> confirmation(
    BuildContext context, {
    required String title,
    required String message,
    String cancelText = 'Cancelar',
    String confirmText = 'Confirmar',
    Color? confirmColor,
    Color? cancelColor,
  }) {
    final theme = Theme.of(context);
    final cConfirm = confirmColor ?? AppPalette.accent;
    final cCancel = cancelColor ?? AppPalette.primary;

    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text(title, style: theme.textTheme.titleMedium?.copyWith(color: AppPalette.primary)),
          content: Text(message, style: theme.textTheme.bodyMedium),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(cancelText),
              style: TextButton.styleFrom(foregroundColor: cCancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(confirmText),
              style: ElevatedButton.styleFrom(
                backgroundColor: cConfirm,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  /// Snack helper (opcional) para mensagens rápidas com paleta
  static void snack(BuildContext context, String text, {Duration duration = const Duration(seconds: 3)}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppPalette.primary,
        duration: duration,
      ),
    );
  }
}
