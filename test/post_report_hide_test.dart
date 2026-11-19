import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/features/community/post_card.dart';
import 'package:wicchu/theme/wicchu_icons.dart';
import 'package:wicchu/theme/wicchu_theme.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'post options use compact flat rows (${dark ? "dark" : "light"})',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? WicchuTheme.dark : WicchuTheme.light,
            home: Scaffold(
              body: PostCard(
                category: 'General',
                icon: '💬',
                community: 'Test',
                author: 'Me',
                time: 'Now',
                text: 'My post',
                saved: true,
                onSaved: (_) async {},
                onShare: () async {},
                onPinnedChanged: (_) async {},
                onEdit: () {},
                onDelete: () async {},
              ),
            ),
          ),
        );

        await tester.tap(find.byTooltip('More options'));
        await tester.pumpAndSettle();
        final sheet = find.byType(BottomSheet);
        expect(sheet, findsOneWidget);
        expect(find.text('Post options'), findsOneWidget);
        expect(find.text('General'), findsOneWidget);
        expect(find.text('Unsave post'), findsOneWidget);
        expect(find.text('Pin publication'), findsOneWidget);
        expect(find.text('Save post'), findsNothing);
        expect(find.text('Unpin publication'), findsNothing);
        expect(tester.getSize(sheet).height, lessThan(400));
        expect(
          find.descendant(of: sheet, matching: find.byType(Card)),
          findsNothing,
        );
        expect(
          find.descendant(
            of: sheet,
            matching: find.byIcon(WicchuIcons.caretRight),
          ),
          findsNothing,
        );
        expect(find.byType(Divider), findsOneWidget);
        expect(find.text('Remove it from your saved posts'), findsNothing);
        expect(find.text('Share it in other apps'), findsNothing);
        expect(find.text('Keep it at the top of its category'), findsNothing);
        expect(find.text('Update your post'), findsNothing);
        expect(find.text('It will be permanently deleted'), findsNothing);

        for (final action in ['save', 'share', 'pin', 'edit', 'delete']) {
          final row = find.byKey(ValueKey('post-menu-$action'));
          expect(row, findsOneWidget);
          expect(tester.getSize(row).height, 50);
          expect(
            tester
                .widget<Icon>(
                  find.descendant(of: row, matching: find.byType(Icon)).first,
                )
                .size,
            21,
          );
        }
        final deleteText = tester.widget<Text>(find.text('Delete publication'));
        expect(
          deleteText.style?.color,
          dark
              ? WicchuTheme.dark.colorScheme.error
              : WicchuTheme.light.colorScheme.error,
        );
        expect(tester.getSize(find.byTooltip('Close')), const Size(44, 44));

        await tester.tap(find.text('Delete publication'));
        await tester.pumpAndSettle();
        expect(find.text('Delete publication?'), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('post options use the compact Spanish title and labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        supportedLocales: const [Locale('en'), Locale('es')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(
          body: PostCard(
            category: 'News',
            icon: '📰',
            community: 'Prueba',
            author: 'Yo',
            time: 'Ahora',
            text: 'Publicación',
            onShare: () async {},
            onEdit: () {},
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Más opciones'));
    await tester.pumpAndSettle();
    expect(find.text('Opciones de publicación'), findsOneWidget);
    expect(find.text('Noticias'), findsOneWidget);
    expect(find.text('Compartir publicación'), findsOneWidget);
    expect(find.text('Editar publicación'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('owner menu offers share and edit without self reporting', (
    tester,
  ) async {
    var shares = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PostCard(
            category: 'General',
            icon: '💬',
            community: 'Test',
            author: 'Me',
            time: 'Now',
            text: 'My post',
            onEdit: () {},
            onShare: () async {
              shares++;
            },
            onReport: (reason, category, {hidePost}) async {},
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    expect(find.text('Post options'), findsOneWidget);
    expect(find.text('Edit post'), findsOneWidget);
    expect(find.text('Report post'), findsNothing);
    await tester.tap(find.text('Share post'));
    await tester.pumpAndSettle();
    expect(shares, 1);
    expect(find.text('Post options'), findsNothing);
  });

  testWidgets('reporter can hide a reported post from the snackbar', (
    tester,
  ) async {
    final hideValues = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PostCard(
            category: 'General',
            icon: 'chat',
            community: 'Test community',
            author: 'Another member',
            time: 'Now',
            text: 'Content the reporter does not want to see',
            onReport: (reason, category, {hidePost}) async {
              hideValues.add(hidePost == true);
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Report post'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Harassing content');
    await tester.ensureVisible(find.text('Submit report'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit report'));
    await tester.pumpAndSettle();

    expect(hideValues, [false]);
    expect(find.text('Hide post'), findsOneWidget);

    await tester.tap(find.text('Hide post'));
    await tester.pumpAndSettle();

    expect(hideValues, [false, true]);
    expect(
      find.text('Content the reporter does not want to see'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('member can hide a post without reporting and undo it', (
    tester,
  ) async {
    var hidden = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PostCard(
            category: 'General',
            icon: 'chat',
            community: 'Test community',
            author: 'Another member',
            time: 'Now',
            text: 'A post I want to hide',
            onHide: () async => hidden = true,
            onUnhide: () async => hidden = false,
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    expect(find.text('Hide post'), findsOneWidget);
    expect(find.text('Report post'), findsNothing);

    await tester.tap(find.text('Hide post'));
    await tester.pumpAndSettle();
    expect(hidden, isTrue);
    expect(find.text('A post I want to hide'), findsNothing);
    expect(find.text('Post hidden'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(hidden, isFalse);
    expect(find.text('A post I want to hide'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('moderator removes a community post only after giving a reason', (
    tester,
  ) async {
    String? removalReason;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PostCard(
            category: 'Offers',
            icon: '🏷️',
            community: 'Test community',
            author: 'Local business',
            time: 'Now',
            text: 'Shared business offer',
            onModerationRemove: (reason) async {
              removalReason = reason;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove from community'));
    await tester.pumpAndSettle();

    var removeButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Remove'),
    );
    expect(removeButton.onPressed, isNull);

    await tester.enterText(
      find.byType(TextField),
      'Offer violates local rules',
    );
    await tester.pump();
    removeButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Remove'),
    );
    expect(removeButton.onPressed, isNotNull);
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();

    expect(removalReason, 'Offer violates local rules');
    expect(find.text('Post removed from community'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
