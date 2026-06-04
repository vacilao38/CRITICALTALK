import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import 'package:critical_talk/main.dart';

void main() {
  test('sanitizes obsidian links while preserving visible labels', () {
    expect(
      sanitizeObsidianMarkdown(
        '**ritual** [[arquivo]] [portal](https://obsidian.md)',
      ),
      '**ritual** arquivo portal',
    );
  });

  testWidgets('renders the base session layout', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1366, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(CriticalTalkApp());

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

    await tester.pumpWidget(CriticalTalkApp());

    expect(find.text('Voz'), findsOneWidget);
    expect(find.text('Mensagem para a mesa'), findsOneWidget);
  });

  testWidgets('sends a local message and receives the test bot reply', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1366, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(CriticalTalkApp());

    await tester.enterText(
      find.widgetWithText(TextField, 'Mensagem para a mesa'),
      'ola bot',
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    expect(find.text('ola bot'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    expect(find.text('mensagem recebida'), findsOneWidget);
  });

  testWidgets('renders obsidian-style markdown and strips link syntax', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1366, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(CriticalTalkApp());

    await tester.enterText(
      find.widgetWithText(TextField, 'Mensagem para a mesa'),
      '**ritual** [[arquivo]] [portal](https://obsidian.md)',
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    expect(find.byType(MarkdownBody), findsWidgets);
    expect(
      find.text('**ritual** [[arquivo]] [portal](https://obsidian.md)'),
      findsNothing,
    );

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
  });

  testWidgets('sends an image through the picker and shows it in chat', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1366, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      CriticalTalkApp(
        imagePicker: () async =>
            SelectedChatImage(name: 'mapa.png', bytes: _fakeImageBytes),
      ),
    );

    await tester.tap(find.byIcon(Icons.add_photo_alternate));
    await tester.pump();

    expect(find.text('mapa.png'), findsOneWidget);
    expect(find.byType(Image), findsWidgets);

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    expect(find.text('mensagem recebida'), findsOneWidget);
  });
}

final Uint8List _fakeImageBytes = Uint8List.fromList(<int>[
  137,
  80,
  78,
  71,
  13,
  10,
  26,
  10,
  0,
  0,
  0,
  13,
  73,
  72,
  68,
  82,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  1,
  8,
  4,
  0,
  0,
  0,
  181,
  28,
  12,
  2,
  0,
  0,
  0,
  11,
  73,
  68,
  65,
  84,
  120,
  218,
  99,
  252,
  255,
  31,
  0,
  3,
  3,
  2,
  0,
  239,
  166,
  226,
  91,
  0,
  0,
  0,
  0,
  73,
  69,
  78,
  68,
  174,
  66,
  96,
  130,
]);
