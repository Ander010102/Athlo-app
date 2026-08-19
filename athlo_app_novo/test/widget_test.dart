import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:athlo_app_novo/main.dart'; // Certifique-se que o nome bate com o do pubspec.yaml

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Coloca o MyApp na tela para o teste
    await tester.pumpWidget(const MyApp());

    // Verifica se existe pelo menos um MaterialApp na árvore de widgets
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
