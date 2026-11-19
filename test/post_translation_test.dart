import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/features/community/post_card.dart';
import 'package:wicchu/features/community/post_markdown.dart';
import 'package:wicchu/localization/app_language.dart';

class _Repository extends DemoCommunityRepository {
  final requests = <Completer<PostTranslation>>[];
  final requestedLanguages = <String>[];
  @override
  Future<PostTranslation> translatePost(
    String postId, {
    required String targetLanguage,
  }) {
    requestedLanguages.add(targetLanguage);
    final request = Completer<PostTranslation>();
    requests.add(request);
    return request.future;
  }
}

Widget _screen(
  _Repository repository,
  String id, {
  String text = 'Original',
  String language = '',
}) => MaterialApp(
  home: AppLanguageScope(
    languageCode: 'es',
    onLanguageChanged: (_) {},
    child: Scaffold(
      body: SingleChildScrollView(
        child: PostCard(
          key: const ValueKey('reused-post'),
          repository: repository,
          post: CommunityPost(
            id: id,
            communityId: 'community',
            categoryId: 'news',
            authorId: 'author',
            text: text,
            language: language,
            status: PostStatus.published,
            createdAt: DateTime(2026),
          ),
          category: 'News',
          icon: '📰',
          community: 'Town',
          author: 'Ana',
          time: 'Now',
          text: text,
        ),
      ),
    ),
  ),
);

PostTranslation _result(String id, {String sourceLanguage = ''}) =>
    PostTranslation(
      postId: id,
      targetLanguage: 'es',
      sourceLanguage: sourceLanguage,
      translatedText: 'Traducción $id',
    );

void main() {
  testWidgets('empty post translation preserves original and permits retry', (
    tester,
  ) async {
    final repository = _Repository();
    await tester.pumpWidget(_screen(repository, 'one'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('translate-post-one')));
    expect(repository.requestedLanguages, ['es']);
    repository.requests.single.complete(
      const PostTranslation(
        postId: 'one',
        targetLanguage: 'es',
        translatedText: '   ',
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<PostMarkdown>(find.byType(PostMarkdown)).data,
      'Original',
    );
    expect(find.text('View original'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('translate-post-one')));
    repository.requests.last.complete(_result('one'));
    await tester.pumpAndSettle();
    expect(find.text('View original'), findsOneWidget);
  });

  testWidgets('translation toggles and reuses the fetched result', (
    tester,
  ) async {
    final repository = _Repository();
    await tester.pumpWidget(_screen(repository, 'one'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('translate-post-one')));
    await tester.pump();
    expect(find.text('Translating…'), findsOneWidget);
    repository.requests.single.complete(_result('one'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<PostMarkdown>(find.byType(PostMarkdown)).data,
      'Traducción one',
    );
    await tester.tap(find.text('View original'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<PostMarkdown>(find.byType(PostMarkdown)).data,
      'Original',
    );
    await tester.tap(find.byKey(const ValueKey('translate-post-one')));
    await tester.pumpAndSettle();
    expect(repository.requests, hasLength(1));
    expect(find.text('View original'), findsOneWidget);
  });

  testWidgets(
    'hides translation action when post already matches the app language',
    (tester) async {
      final repository = _Repository();
      await tester.pumpWidget(_screen(repository, 'same-language'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('translate-post-same-language')),
      );
      repository.requests.single.complete(
        _result('same-language', sourceLanguage: 'es'),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('translate-post-same-language')),
        findsNothing,
      );
      expect(find.text('View original'), findsNothing);
    },
  );

  testWidgets('does not show translation action when post language is known', (
    tester,
  ) async {
    final repository = _Repository();
    await tester.pumpWidget(_screen(repository, 'known', language: 'es-ES'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('translate-post-known')), findsNothing);
  });

  testWidgets(
    'infers Spanish posts for a Spanish user when metadata is absent',
    (tester) async {
      final repository = _Repository();
      await tester.pumpWidget(
        _screen(
          repository,
          'inferred-spanish',
          text: 'Bienvenidos al grupo de la comunidad',
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('translate-post-inferred-spanish')),
        findsNothing,
      );
    },
  );

  testWidgets('hides translation action for posts with an inline video', (
    tester,
  ) async {
    final repository = _Repository();
    await tester.pumpWidget(
      _screen(repository, 'video', text: 'https://youtu.be/dQw4w9WgXcQ'),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('translate-post-video')), findsNothing);
  });

  testWidgets(
    'late translation cannot replace another post or stop its request',
    (tester) async {
      final repository = _Repository();
      await tester.pumpWidget(_screen(repository, 'one'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('translate-post-one')));
      await tester.pump();
      await tester.pumpWidget(_screen(repository, 'two'));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('translate-post-two')));
      await tester.pump();
      expect(repository.requests, hasLength(2));
      repository.requests.first.complete(_result('one'));
      await tester.pump();
      expect(
        tester.widget<PostMarkdown>(find.byType(PostMarkdown)).data,
        'Original',
      );
      expect(find.text('Translating…'), findsOneWidget);
      repository.requests.last.complete(_result('two'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<PostMarkdown>(find.byType(PostMarkdown)).data,
        'Traducción two',
      );
    },
  );

  testWidgets(
    'editing a post invalidates its translation; errors allow retry',
    (tester) async {
      final repository = _Repository();
      await tester.pumpWidget(_screen(repository, 'one'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('translate-post-one')));
      repository.requests.single.complete(_result('one'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(_screen(repository, 'one', text: 'Edited'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<PostMarkdown>(find.byType(PostMarkdown)).data,
        'Edited',
      );
      await tester.tap(find.byKey(const ValueKey('translate-post-one')));
      repository.requests.last.completeError(
        Exception('Translation unavailable'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Translating…'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('translate-post-one')));
      expect(repository.requests, hasLength(3));
      repository.requests.last.complete(_result('one'));
      await tester.pumpAndSettle();
      expect(find.text('View original'), findsOneWidget);
    },
  );
}
