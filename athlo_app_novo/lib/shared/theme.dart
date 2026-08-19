import 'package:flutter/material.dart';

class AppPalette {
  static const Color primary = Color(0xFF595643); // #595643
  static const Color green = Color(0xFF4E6B66);   // #4E6B66
  static const Color accent = Color(0xFFED834E);  // #ED834E
  static const Color yellow = Color(0xFFEBCC6E);  // #EBCC6E
  static const Color light = Color(0xFFEBE1C5);   // #EBE1C5
}

// Small helper to style AlertDialogs consistently
/* class AppDialogs {
  static AlertDialog confirmation({
    required BuildContext context,
    required String title,
    required String content,
    required VoidCallback onConfirm,
    String confirmLabel = 'Confirmar',
    String cancelLabel = 'Cancelar',
    Color confirmColor = AppPalette.accent,
  }) {
    return AlertDialog(
      backgroundColor: Colors.white,
      title: Text(title, style: TextStyle(color: AppPalette.primary, fontWeight: FontWeight.bold)),
      content: Text(content, style: TextStyle(color: AppPalette.primary)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(cancelLabel, style: TextStyle(color: AppPalette.primary)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: confirmColor,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            Navigator.pop(context);
            onConfirm();
          },
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}
*/