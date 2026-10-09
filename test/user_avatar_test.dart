import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/features/community/user_avatar.dart';
import 'package:wicchu/widgets/wicchu_network_image.dart';

void main() {
  testWidgets('avatar cache isolates users and Facebook URL parameters', (
    tester,
  ) async {
    Future<void> show(String id, String url) => tester.pumpWidget(
      MaterialApp(
        home: UserAvatar(userId: id, name: 'Person', imageUrl: url),
      ),
    );
    await show('one', 'https://example.com/picture?id=one');
    final first = tester.widget<WicchuNetworkImage>(
      find.byType(WicchuNetworkImage),
    );
    await show('two', 'https://example.com/picture?id=one');
    final second = tester.widget<WicchuNetworkImage>(
      find.byType(WicchuNetworkImage),
    );
    expect(second.cacheKey, isNot(first.cacheKey));
    expect(second.key, isNot(first.key));
    await show('two', 'https://example.com/picture?id=two');
    final changed = tester.widget<WicchuNetworkImage>(
      find.byType(WicchuNetworkImage),
    );
    expect(changed.cacheKey, isNot(second.cacheKey));
    expect(changed.key, isNot(second.key));
    expect(changed.loadingBuilder, isNotNull);
  });
}
