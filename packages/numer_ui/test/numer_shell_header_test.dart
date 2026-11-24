import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_ui/numer_ui.dart';

const _avatar = ColoredBox(key: Key('avatar'), color: Colors.transparent);

void main() {
  testWidgets('keeps a 48 target for the avatar at the right', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: NumerTheme.build(
          seed: const Color.fromARGB(255, 68, 138, 255),
          brightness: Brightness.light,
        ),
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              NumerShellHeader(
                title: const Text('Study'),
                actions: [
                  IconButton(
                    tooltip: 'Add',
                    onPressed: () {},
                    icon: const Icon(Icons.add),
                  ),
                ],
                avatar: _avatar,
                avatarTooltip: 'Settings',
                onAvatarPressed: () => taps++,
              ),
            ],
          ),
        ),
      ),
    );
    final button = find.ancestor(
      of: find.byKey(const Key('avatar')),
      matching: find.byType(IconButton),
    );
    final size = tester.getSize(button);

    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
    expect(
      tester.getSize(find.byKey(const Key('avatar'))),
      const Size.square(32),
    );
    expect(tester.widget<IconButton>(button).tooltip, 'Settings');
    expect(
      tester.getRect(button).left,
      greaterThanOrEqualTo(tester.getRect(find.byTooltip('Add')).right),
    );

    await tester.tap(button);
    expect(taps, 1);
  });

  testWidgets('three actions are refused', (tester) async {
    final header = NumerShellHeader(
      title: const Text('Study'),
      actions: const [SizedBox(), SizedBox(), SizedBox()],
      avatar: _avatar,
      avatarTooltip: 'Settings',
      onAvatarPressed: () {},
    );

    await tester.pumpWidget(
      Builder(
        builder: (context) {
          expect(() => header.build(context), throwsAssertionError);
          return const SizedBox();
        },
      ),
    );
  });
}
