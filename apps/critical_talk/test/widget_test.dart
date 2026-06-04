import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:critical_talk/main.dart';

void main() {
  testWidgets('renders the base session layout', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1366, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const CriticalTalkApp());

    expect(find.text('Critical Talk'), findsOneWidget);
    expect(find.text('Voz'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Trilha'), findsOneWidget);
    expect(find.text('Dados'), findsOneWidget);
    expect(find.text('Perfil'), findsOneWidget);
  });

  testWidgets('keeps the compact layout usable', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1100, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const CriticalTalkApp());

    expect(find.text('Voz'), findsOneWidget);
    expect(find.text('Mensagem para a mesa'), findsOneWidget);
  });
}
