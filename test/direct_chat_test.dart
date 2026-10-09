import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/features/chat/direct_chat_pages.dart';

class _ChatRepository extends DemoCommunityRepository {
  String? sentBody;
  String? reportedMessageId;
  String? reportedCategory;
  String? deletedMessageId;
  bool? deletedForEveryone;
  bool? acceptedRequest;
  String? lastConversationPageId;
  String? lastRequestPageId;
  List<DirectConversation> chats = const [];
  List<DirectConversation> requests = const [];

  @override
  Future<List<Community>> listManagedCommunities() async => [
    Community(
      id: 'page-1',
      name: 'Como en Casa',
      description: 'Local restaurant',
      town: const Town(id: 'town-1', name: 'Echeandía', countryCode: 'EC'),
      visibility: CommunityVisibility.public,
      createdBy: 'current-user',
      createdAt: DateTime.utc(2026, 10, 1),
      type: CommunityType.publicProfile,
      profileCategory: ProfileCategory.localBusiness,
      myRole: CommunityRole.owner,
    ),
  ];

  @override
  Future<List<DirectConversation>> listDirectConversations({
    String? pageId,
  }) async {
    lastConversationPageId = pageId;
    return chats;
  }

  @override
  Future<List<DirectConversation>> listMessageRequests({String? pageId}) async {
    lastRequestPageId = pageId;
    return requests;
  }

  @override
  Future<DirectMessagePage> listDirectMessages(
    String conversationId, {
    String? before,
  }) async => before == null
      ? DirectMessagePage(
          nextCursor: 'older-cursor',
          messages: [
            DirectMessage(
              id: 'message-incoming',
              conversationId: conversationId,
              senderId: 'user-2',
              recipientId: 'current-user',
              body: 'Hello from Ana',
              createdAt: DateTime.utc(2026, 10, 5, 10),
              sentByMe: false,
            ),
          ],
        )
      : DirectMessagePage(
          messages: [
            DirectMessage(
              id: 'message-older',
              conversationId: conversationId,
              senderId: 'user-2',
              recipientId: 'current-user',
              body: 'Older hello',
              createdAt: DateTime.utc(2026, 10, 4, 10),
              sentByMe: false,
            ),
          ],
        );

  @override
  Future<DirectMessage> sendDirectMessage(
    String conversationId,
    String body,
  ) async {
    sentBody = body;
    return DirectMessage(
      id: 'message-sent',
      conversationId: conversationId,
      senderId: 'current-user',
      recipientId: 'user-2',
      body: body,
      createdAt: DateTime.utc(2026, 10, 5, 10, 1),
      sentByMe: true,
    );
  }

  @override
  Future<void> reportDirectMessage(
    String messageId,
    String reason, {
    required String category,
  }) async {
    reportedMessageId = messageId;
    reportedCategory = category;
  }

  @override
  Future<void> deleteDirectMessage(
    String messageId, {
    required bool everyone,
  }) async {
    deletedMessageId = messageId;
    deletedForEveryone = everyone;
  }

  @override
  Future<void> respondToMessageRequest(
    String conversationId, {
    required bool accept,
  }) async {
    acceptedRequest = accept;
  }
}

void main() {
  testWidgets('page inbox clearly shows the active reply identity', (
    tester,
  ) async {
    const conversation = DirectConversation(
      id: 'page-conversation-1',
      otherUser: WicchuUser(id: 'customer-1', name: 'Customer'),
      unreadCount: 0,
      pageId: 'page-1',
      pageName: 'Como en Casa',
      viewingAsPage: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: DirectChatPage(
          repository: _ChatRepository(),
          conversation: conversation,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('You are replying as Como en Casa'), findsOneWidget);
  });

  testWidgets('inbox can switch from personal identity to an owned page', (
    tester,
  ) async {
    final repository = _ChatRepository();
    await tester.pumpWidget(
      MaterialApp(home: ConversationListPage(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Personal'), findsOneWidget);
    expect(find.text('Como en Casa'), findsOneWidget);
    await tester.tap(find.text('Como en Casa'));
    await tester.pumpAndSettle();

    expect(repository.lastConversationPageId, 'page-1');
    expect(repository.lastRequestPageId, 'page-1');
    await tester.tap(find.text('Personal'));
    await tester.pumpAndSettle();
    expect(repository.lastConversationPageId, isNull);
  });

  testWidgets('pending incoming and sent requests stay in separate lists', (
    tester,
  ) async {
    final repository = _ChatRepository()
      ..chats = const [
        DirectConversation(
          id: 'incoming',
          otherUser: WicchuUser(id: 'a', name: 'Incoming'),
          unreadCount: 1,
          requestStatus: MessageRequestStatus.pending,
        ),
        DirectConversation(
          id: 'outgoing',
          otherUser: WicchuUser(id: 'b', name: 'Outgoing'),
          unreadCount: 0,
          requestStatus: MessageRequestStatus.pending,
          requestedByMe: true,
        ),
      ];
    await tester.pumpWidget(
      MaterialApp(home: ConversationListPage(repository: repository)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Incoming'), findsNothing);
    expect(find.text('Outgoing'), findsOneWidget);
    expect(find.text('Request sent'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('message-requests-button')));
    await tester.pumpAndSettle();
    expect(find.text('Incoming'), findsOneWidget);
    expect(find.text('Outgoing'), findsNothing);
    await tester.tap(find.text('Chats'));
    await tester.pumpAndSettle();
    expect(find.text('Outgoing'), findsOneWidget);
  });

  testWidgets('chats open first and requests button shows incoming count', (
    tester,
  ) async {
    final repository = _ChatRepository()
      ..requests = const [
        DirectConversation(
          id: 'conversation-request',
          otherUser: WicchuUser(id: 'user-2', name: 'Ana'),
          unreadCount: 1,
          lastMessagePreview: 'Hello from Ana',
          requestStatus: MessageRequestStatus.pending,
          requestedByMe: false,
          canSendMessage: false,
        ),
      ];
    await tester.pumpWidget(
      MaterialApp(home: ConversationListPage(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ana'), findsNothing);
    expect(find.byType(SegmentedButton<bool>), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('message-requests-button')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('message-requests-button')));
    await tester.pumpAndSettle();
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Hello from Ana'), findsOneWidget);
    expect(
      find.text(
        'Message requests are messages from people who are not in your contacts.',
      ),
      findsOneWidget,
    );
    expect(find.text('Nothing else for now'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('dismiss-message-request-information')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('message-request-information')),
      findsNothing,
    );
  });

  testWidgets('direct chat sends and reports a received message', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _ChatRepository();
    const conversation = DirectConversation(
      id: 'conversation-1',
      otherUser: WicchuUser(id: 'user-2', name: 'Ana'),
      unreadCount: 1,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: DirectChatPage(
          repository: repository,
          conversation: conversation,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hello from Ana'), findsOneWidget);
    await tester.tap(find.text('Load older messages'));
    await tester.pumpAndSettle();
    expect(find.text('Older hello'), findsOneWidget);
    await tester.tap(find.byTooltip('Emoji'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('👋'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '👋',
    );
    await tester.enterText(find.byType(TextField), 'Hi Ana');
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    expect(repository.sentBody, 'Hi Ana');
    expect(find.text('Hi Ana'), findsOneWidget);

    await tester.longPress(find.text('Hello from Ana'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Report message'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Harassment'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Submit report'));
    await tester.tap(find.text('Submit report'));
    await tester.pumpAndSettle();

    expect(repository.reportedMessageId, 'message-incoming');
    expect(repository.reportedCategory, 'harassment');
    expect(find.text('Report submitted'), findsOneWidget);

    await tester.longPress(find.text('Hi Ana'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete for everyone'));
    await tester.pumpAndSettle();
    expect(repository.deletedMessageId, 'message-sent');
    expect(repository.deletedForEveryone, isTrue);
    expect(find.text('Message removed'), findsOneWidget);
  });

  testWidgets('message request must be accepted before replying', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _ChatRepository();
    const conversation = DirectConversation(
      id: 'conversation-request',
      otherUser: WicchuUser(id: 'user-2', name: 'Ana'),
      unreadCount: 1,
      requestStatus: MessageRequestStatus.pending,
      requestedByMe: false,
      canSendMessage: false,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: DirectChatPage(
          repository: repository,
          conversation: conversation,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Accept'), findsOneWidget);
    expect(find.text('Decline'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();

    expect(repository.acceptedRequest, isTrue);
    expect(find.byType(TextField), findsOneWidget);
  });
}
