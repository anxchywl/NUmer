@Tags(['images'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_ui/numer_ui.dart';

const _accent = Color.fromARGB(255, 68, 138, 255);
const _width = 390.0;
const _galleryHeight = 1240.0;
const _screenHeight = 700.0;

// the default test font draws every glyph as a square and has no icons
Future<void> _loadFonts() async {
  final fonts =
      '${Platform.environment['FLUTTER_ROOT']}'
      '/bin/cache/artifacts/material_fonts';
  Future<ByteData> read(String name) =>
      File('$fonts/$name').readAsBytes().then(ByteData.sublistView);

  final roboto = FontLoader('Roboto');
  for (final weight in ['Regular', 'Medium', 'Bold']) {
    roboto.addFont(read('Roboto-$weight.ttf'));
  }
  final icons = FontLoader('MaterialIcons')
    ..addFont(read('MaterialIcons-Regular.otf'));
  await Future.wait([roboto.load(), icons.load()]);
}

Widget _gallery() {
  return Scaffold(
    floatingActionButton: NumerFab(
      icon: Icons.add,
      label: 'New listing',
      onPressed: () {},
    ),
    body: CustomScrollView(
      slivers: [
        NumerShellHeader(
          title: const Text('Study'),
          avatar: const CircleAvatar(child: Text('A')),
          avatarTooltip: 'Settings',
          onAvatarPressed: () {},
        ),
        SliverList.list(
          children: [
            _rows(),
            _statuses(),
            NumerEmptyState(
              message: 'No courses yet.',
              actionLabel: 'Add course',
              onAction: () {},
            ),
            NumerErrorState(
              message: 'Could not load news.',
              retryLabel: 'Retry',
              onRetry: () {},
            ),
            const SizedBox(height: NumerSpace.xl),
            const NumerSkeleton(),
          ],
        ),
      ],
    ),
  );
}

Widget _rows() {
  return NumerSection(
    title: 'Today',
    actionLabel: 'All',
    onAction: () {},
    child: NumerBlock(
      children: [
        const NumerRow(
          leading: Icon(Icons.school_outlined),
          title: 'Linear algebra',
          subtitle: 'Room 7.105, 10:30',
        ),
        NumerRow(
          title: 'Weekly goal',
          value: '12 h',
          showChevron: true,
          onTap: () {},
        ),
        NumerRow(
          title: 'Reminders',
          trailing: Switch(value: true, onChanged: (_) {}),
        ),
      ],
    ),
  );
}

Widget _statuses() {
  return NumerSection(
    title: 'Status',
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: NumerSpace.lg),
      child: Wrap(
        spacing: NumerSpace.lg,
        runSpacing: NumerSpace.sm,
        children: [
          for (final tone in NumerStatusTone.values)
            NumerStatusLabel(tone.name, tone: tone),
        ],
      ),
    ),
  );
}

final Map<String, void Function(BuildContext)> _overlays = {
  'sheet': (context) => showNumerSheet<void>(
    context,
    title: 'Add course',
    builder: (_) =>
        const TextField(decoration: InputDecoration(labelText: 'Course name')),
    primaryAction: FilledButton(
      onPressed: () {},
      child: const Text('Add course'),
    ),
  ),
  'confirm': (context) => showNumerConfirm(
    context,
    title: 'Delete this course?',
    body: 'Its sessions stay in your history.',
    confirmLabel: 'Delete course',
    destructive: true,
  ),
  'message': (context) => showNumerMessage(
    context,
    'Session saved.',
    actionLabel: 'Undo',
    onAction: () {},
  ),
};

Future<void> _pump(
  WidgetTester tester, {
  required Brightness brightness,
  required double scale,
  required double height,
  required Widget home,
}) async {
  tester.view.physicalSize = Size(_width, height) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: NumerTheme.build(seed: _accent, brightness: brightness),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: home,
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pumpAndSettle();
}

Future<void> _capture(String name) {
  return expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$name.png'),
  );
}

void main() {
  setUpAll(_loadFonts);

  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 1.3]) {
      final name = 'gallery_${brightness.name}_$scale';

      testWidgets(name, (tester) async {
        await _pump(
          tester,
          brightness: brightness,
          scale: scale,
          height: _galleryHeight,
          home: _gallery(),
        );

        await _capture(name);
      });
    }

    for (final overlay in _overlays.entries) {
      final name = '${overlay.key}_${brightness.name}';

      testWidgets(name, (tester) async {
        await _pump(
          tester,
          brightness: brightness,
          scale: 1,
          height: _screenHeight,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => overlay.value(context),
                child: const Text('open'),
              ),
            ),
          ),
        );
        // tests paint shadows as solid outlines unless this is off
        debugDisableShadows = false;
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        await _capture(name);
        debugDisableShadows = true;
      });
    }
  }
}
