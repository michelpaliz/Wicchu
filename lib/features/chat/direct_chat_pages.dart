import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';
import '../../localization/app_language.dart';
import '../../services/presence_service.dart';
import '../community/report_dialog.dart';
import '../community/user_avatar.dart';

class ConversationListPage extends StatefulWidget {
  const ConversationListPage({super.key, required this.repository});

  final CommunityRepository repository;

  @override
  State<ConversationListPage> createState() => _ConversationListPageState();
}

class _ConversationListPageState extends State<ConversationListPage> {
  late Future<List<DirectConversation>> _conversations = _load();
  StreamSubscription<Map<String, dynamic>>? _subscription;
  StreamSubscription<Map<String, dynamic>>? _updateSubscription;
  StreamSubscription<Map<String, dynamic>>? _requestSubscription;
  bool _showRequests = false;

  Future<List<DirectConversation>> _load() => _showRequests
      ? widget.repository.listMessageRequests()
      : widget.repository.listDirectConversations();

  void _selectList(bool requests) {
    if (_showRequests == requests) return;
    setState(() {
      _showRequests = requests;
      _conversations = _load();
    });
  }

  Future<void> _deleteConversation(DirectConversation conversation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.tr('Delete conversation?')),
        content: Text(
          dialogContext.tr(
            'This removes the conversation from your account only.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.tr('Delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.repository.deleteDirectConversation(conversation.id);
      if (mounted) setState(() => _conversations = _load());
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _subscription = PresenceService.instance.chatMessages.listen((_) {
      if (mounted) setState(() => _conversations = _load());
    });
    _updateSubscription = PresenceService.instance.chatMessageUpdates.listen((
      _,
    ) {
      if (mounted) setState(() => _conversations = _load());
    });
    _requestSubscription = PresenceService.instance.chatRequestUpdates.listen((
      _,
    ) {
      if (mounted) setState(() => _conversations = _load());
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _updateSubscription?.cancel();
    _requestSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(context.tr('Messages')),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: false,
                icon: const Icon(Icons.chat_bubble_outline),
                label: Text(context.tr('Chats')),
              ),
              ButtonSegment(
                value: true,
                icon: const Icon(Icons.mark_unread_chat_alt_outlined),
                label: Text(context.tr('Requests')),
              ),
            ],
            selected: {_showRequests},
            onSelectionChanged: (values) => _selectList(values.first),
          ),
        ),
      ),
    ),
    body: RefreshIndicator(
      onRefresh: () async {
        final next = _load();
        setState(() => _conversations = next);
        await next;
      },
      child: FutureBuilder<List<DirectConversation>>(
        future: _conversations,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: [
                Text(context.trError(snapshot.error!)),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => setState(() => _conversations = _load()),
                  child: Text(context.tr('Try again')),
                ),
              ],
            );
          }
          final conversations = snapshot.data ?? const [];
          if (conversations.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(32),
              children: [
                const Icon(Icons.chat_bubble_outline, size: 48),
                const SizedBox(height: 16),
                Text(
                  context.tr(
                    _showRequests ? 'No message requests' : 'No messages yet',
                  ),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr(
                    _showRequests
                        ? 'New conversations from other people will appear here.'
                        : 'Open a member profile and tap Message to start a conversation.',
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: conversations.length,
            separatorBuilder: (_, _) => const Divider(height: 1, indent: 76),
            itemBuilder: (context, index) {
              final conversation = conversations[index];
              return ListTile(
                leading: UserAvatar(
                  name: conversation.otherUser.name,
                  imageUrl: conversation.otherUser.avatarUrl,
                  radius: 24,
                ),
                title: Text(
                  conversation.otherUser.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: conversation.unreadCount > 0
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  conversation.requestStatus == MessageRequestStatus.pending &&
                          conversation.requestedByMe
                      ? context.tr('Message request pending')
                      : conversation.lastMessageRemoved
                      ? context.tr('Message removed')
                      : conversation.lastMessagePreview.isEmpty
                      ? context.tr('Start the conversation')
                      : '${conversation.lastMessageMine ? '${context.tr('You')}: ' : ''}${conversation.lastMessagePreview}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (conversation.unreadCount > 0)
                      Badge(label: Text('${conversation.unreadCount}'))
                    else if (conversation.lastMessageAt != null)
                      Text(
                        _shortTime(context, conversation.lastMessageAt!),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    PopupMenuButton<String>(
                      tooltip: context.tr('More'),
                      onSelected: (_) => _deleteConversation(conversation),
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(context.tr('Delete conversation')),
                        ),
                      ],
                    ),
                  ],
                ),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DirectChatPage(
                        repository: widget.repository,
                        conversation: conversation,
                      ),
                    ),
                  );
                  if (mounted) setState(() => _conversations = _load());
                },
              );
            },
          );
        },
      ),
    ),
  );
}

class DirectChatPage extends StatefulWidget {
  const DirectChatPage({
    super.key,
    required this.repository,
    required this.conversation,
  });

  final CommunityRepository repository;
  final DirectConversation conversation;

  @override
  State<DirectChatPage> createState() => _DirectChatPageState();
}

class _DirectChatPageState extends State<DirectChatPage> {
  final _composer = TextEditingController();
  final _scroll = ScrollController();
  final List<DirectMessage> _messages = [];
  StreamSubscription<Map<String, dynamic>>? _subscription;
  StreamSubscription<Map<String, dynamic>>? _updateSubscription;
  StreamSubscription<Map<String, dynamic>>? _typingSubscription;
  StreamSubscription<Map<String, dynamic>>? _readSubscription;
  StreamSubscription<Map<String, dynamic>>? _requestSubscription;
  Timer? _typingTimer;
  Timer? _remoteTypingTimer;
  String? _viewerId;
  String? _nextCursor;
  bool _loading = true;
  bool _loadingOlder = false;
  bool _sending = false;
  bool _typingSent = false;
  bool _otherUserTyping = false;
  late MessageRequestStatus _requestStatus;
  late bool _canSendMessage;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _requestStatus = widget.conversation.requestStatus;
    _canSendMessage = widget.conversation.canSendMessage;
    _load();
    _subscription = PresenceService.instance.chatMessages.listen(
      _receiveSocketMessage,
    );
    _updateSubscription = PresenceService.instance.chatMessageUpdates.listen(
      _receiveMessageUpdate,
    );
    _typingSubscription = PresenceService.instance.chatTyping.listen(
      _receiveTyping,
    );
    _readSubscription = PresenceService.instance.chatReadReceipts.listen(
      _receiveReadReceipt,
    );
    _requestSubscription = PresenceService.instance.chatRequestUpdates.listen(
      _receiveRequestUpdate,
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _updateSubscription?.cancel();
    _typingSubscription?.cancel();
    _readSubscription?.cancel();
    _requestSubscription?.cancel();
    _typingTimer?.cancel();
    _remoteTypingTimer?.cancel();
    if (_typingSent) {
      PresenceService.instance.sendTyping(widget.conversation.id, false);
    }
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        widget.repository.getProfile(),
        widget.repository.listDirectMessages(widget.conversation.id),
      ]);
      if (!mounted) return;
      setState(() {
        _viewerId = (results[0] as WicchuProfile).id;
        final page = results[1] as DirectMessagePage;
        _messages
          ..clear()
          ..addAll(page.messages);
        _nextCursor = page.nextCursor;
        _loading = false;
        _error = null;
      });
      _scrollToBottom();
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error;
        });
      }
    }
  }

  Future<void> _loadOlder() async {
    final cursor = _nextCursor;
    if (cursor == null || _loadingOlder) return;
    setState(() => _loadingOlder = true);
    try {
      final page = await widget.repository.listDirectMessages(
        widget.conversation.id,
        before: cursor,
      );
      if (!mounted) return;
      setState(() {
        final known = _messages.map((item) => item.id).toSet();
        _messages.insertAll(
          0,
          page.messages.where((item) => !known.contains(item.id)),
        );
        _nextCursor = page.nextCursor;
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    } finally {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  void _receiveSocketMessage(Map<String, dynamic> json) {
    if (json['conversationId']?.toString() != widget.conversation.id) return;
    final id = json['id']?.toString() ?? '';
    if (id.isEmpty || _messages.any((item) => item.id == id)) return;
    final createdAt = DateTime.tryParse(json['createdAt']?.toString() ?? '');
    if (!mounted || createdAt == null) return;
    setState(() {
      _messages.add(
        DirectMessage(
          id: id,
          conversationId: widget.conversation.id,
          senderId: json['senderId']?.toString() ?? '',
          recipientId: json['recipientId']?.toString() ?? '',
          body: json['body']?.toString() ?? '',
          createdAt: createdAt,
          readAt: DateTime.tryParse(json['readAt']?.toString() ?? ''),
          removedAt: DateTime.tryParse(json['removedAt']?.toString() ?? ''),
        ),
      );
    });
    if (json['recipientId']?.toString() == _viewerId) {
      unawaited(
        widget.repository
            .markDirectConversationRead(widget.conversation.id)
            .catchError((_) {}),
      );
    }
    _scrollToBottom();
  }

  void _receiveMessageUpdate(Map<String, dynamic> json) {
    if (json['conversationId']?.toString() != widget.conversation.id) return;
    final index = _messages.indexWhere(
      (item) => item.id == json['id']?.toString(),
    );
    if (index < 0 || !mounted) return;
    final scope = json['scope']?.toString();
    if (scope == 'me' && json['userId']?.toString() == _viewerId) {
      setState(() => _messages.removeAt(index));
      return;
    }
    if (scope == 'everyone') {
      final removedAt = DateTime.tryParse(json['removedAt']?.toString() ?? '');
      setState(() {
        _messages[index] = _messages[index].copyWith(
          body: context.tr('Message removed'),
          removedAt: removedAt ?? DateTime.now(),
        );
      });
    }
  }

  void _receiveTyping(Map<String, dynamic> json) {
    if (json['conversationId']?.toString() != widget.conversation.id ||
        json['userId']?.toString() == _viewerId ||
        !mounted) {
      return;
    }
    _remoteTypingTimer?.cancel();
    setState(() => _otherUserTyping = json['isTyping'] == true);
    if (_otherUserTyping) {
      _remoteTypingTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _otherUserTyping = false);
      });
    }
  }

  void _receiveReadReceipt(Map<String, dynamic> json) {
    if (json['conversationId']?.toString() != widget.conversation.id ||
        !mounted) {
      return;
    }
    final readAt = DateTime.tryParse(json['readAt']?.toString() ?? '');
    if (readAt == null) return;
    setState(() {
      for (var index = 0; index < _messages.length; index++) {
        final message = _messages[index];
        if (message.senderId == _viewerId && message.readAt == null) {
          _messages[index] = message.copyWith(readAt: readAt);
        }
      }
    });
  }

  void _receiveRequestUpdate(Map<String, dynamic> json) {
    if (json['conversationId']?.toString() != widget.conversation.id ||
        !mounted) {
      return;
    }
    final status = json['requestStatus']?.toString();
    if (status == 'accepted') {
      setState(() {
        _requestStatus = MessageRequestStatus.accepted;
        _canSendMessage = true;
      });
    } else if (status == 'declined') {
      setState(() {
        _requestStatus = MessageRequestStatus.declined;
        _canSendMessage = false;
      });
    }
  }

  void _composerChanged(String value) {
    if (_requestStatus != MessageRequestStatus.accepted) return;
    final typing = value.trim().isNotEmpty;
    if (typing && !_typingSent) {
      _typingSent = true;
      PresenceService.instance.sendTyping(widget.conversation.id, true);
    }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(milliseconds: 1200), () {
      if (_typingSent) {
        _typingSent = false;
        PresenceService.instance.sendTyping(widget.conversation.id, false);
      }
    });
    if (!typing && _typingSent) {
      _typingSent = false;
      PresenceService.instance.sendTyping(widget.conversation.id, false);
    }
  }

  Future<void> _send() async {
    final body = _composer.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final message = await widget.repository.sendDirectMessage(
        widget.conversation.id,
        body,
      );
      if (!mounted) return;
      setState(() {
        if (!_messages.any((item) => item.id == message.id)) {
          _messages.add(message);
        }
        _composer.clear();
        if (_requestStatus == MessageRequestStatus.pending) {
          _canSendMessage = false;
        }
      });
      _composerChanged('');
      _scrollToBottom();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _respondToRequest(bool accept) async {
    try {
      await widget.repository.respondToMessageRequest(
        widget.conversation.id,
        accept: accept,
      );
      if (!mounted) return;
      if (!accept) {
        Navigator.pop(context);
        return;
      }
      setState(() {
        _requestStatus = MessageRequestStatus.accepted;
        _canSendMessage = true;
      });
      await widget.repository.markDirectConversationRead(
        widget.conversation.id,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    }
  }

  Future<void> _reportRequest() async {
    final incoming = _messages.where(
      (message) => message.senderId != _viewerId && message.removedAt == null,
    );
    if (incoming.isNotEmpty) await _report(incoming.first);
  }

  Future<void> _messageActions(DirectMessage message) async {
    if (message.removedAt != null) return;
    final mine = message.senderId == _viewerId;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!mine)
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: Text(sheetContext.tr('Report message')),
                onTap: () => Navigator.pop(sheetContext, 'report'),
              ),
            if (mine)
              ListTile(
                leading: const Icon(Icons.delete_forever_outlined),
                title: Text(sheetContext.tr('Delete for everyone')),
                onTap: () => Navigator.pop(sheetContext, 'everyone'),
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(sheetContext.tr('Delete for me')),
              onTap: () => Navigator.pop(sheetContext, 'me'),
            ),
          ],
        ),
      ),
    );
    if (action == 'report') return _report(message);
    if (action != 'me' && action != 'everyone') return;
    try {
      await widget.repository.deleteDirectMessage(
        message.id,
        everyone: action == 'everyone',
      );
      if (!mounted) return;
      setState(() {
        final index = _messages.indexWhere((item) => item.id == message.id);
        if (index < 0) return;
        if (action == 'everyone') {
          _messages[index] = _messages[index].copyWith(
            body: context.tr('Message removed'),
            removedAt: DateTime.now(),
          );
        } else {
          _messages.removeAt(index);
        }
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _report(DirectMessage message) async {
    final report = await showContentReportDialog(
      context,
      title: 'Report message',
    );
    if (report == null || !mounted) return;
    try {
      await widget.repository.reportDirectMessage(
        message.id,
        report.$1,
        category: report.$2,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.tr('Report submitted'))));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    }
  }

  Future<void> _block() async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.tr('Block this user?')),
        content: Text(
          dialogContext.tr(
            'You will no longer be able to see or send messages in this conversation.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.tr('Block')),
          ),
        ],
      ),
    );
    if (approved != true) return;
    try {
      await widget.repository.blockUser(widget.conversation.otherUser.id);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    }
  }

  Future<void> _deleteCurrentConversation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.tr('Delete conversation?')),
        content: Text(
          dialogContext.tr(
            'This removes the conversation from your account only.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.tr('Delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.repository.deleteDirectConversation(widget.conversation.id);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      titleSpacing: 0,
      title: Row(
        children: [
          UserAvatar(
            name: widget.conversation.otherUser.name,
            imageUrl: widget.conversation.otherUser.avatarUrl,
            radius: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.conversation.otherUser.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: [
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'block') _block();
            if (value == 'delete') _deleteCurrentConversation();
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  const Icon(Icons.delete_outline),
                  const SizedBox(width: 10),
                  Text(context.tr('Delete conversation')),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'block',
              child: Row(
                children: [
                  const Icon(Icons.block_outlined),
                  const SizedBox(width: 10),
                  Text(context.tr('Block user')),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
    body: Column(
      children: [
        Expanded(child: _messageBody()),
        if (_requestStatus == MessageRequestStatus.pending &&
            !widget.conversation.requestedByMe)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.tr(
                      'Accept this request to continue the conversation.',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _respondToRequest(false),
                          child: Text(context.tr('Decline')),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => _respondToRequest(true),
                          child: Text(context.tr('Accept')),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton.icon(
                        onPressed: _reportRequest,
                        icon: const Icon(Icons.flag_outlined),
                        label: Text(context.tr('Report')),
                      ),
                      TextButton.icon(
                        onPressed: _block,
                        icon: const Icon(Icons.block_outlined),
                        label: Text(context.tr('Block')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        if (_requestStatus == MessageRequestStatus.pending &&
            widget.conversation.requestedByMe &&
            !_canSendMessage)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              context.tr(
                'Message request sent. You can send more after it is accepted.',
              ),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (_requestStatus == MessageRequestStatus.declined)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              context.tr('This conversation is unavailable.'),
              textAlign: TextAlign.center,
            ),
          ),
        if (_otherUserTyping)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                context.tr('Typing…'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        if (_requestStatus != MessageRequestStatus.declined &&
            (_requestStatus == MessageRequestStatus.accepted ||
                widget.conversation.requestedByMe))
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _composer,
                      enabled: !_sending && _canSendMessage,
                      minLines: 1,
                      maxLines: 5,
                      maxLength: 2000,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: context.tr(
                          _canSendMessage
                              ? 'Write a message'
                              : 'Waiting for acceptance',
                        ),
                        counterText: '',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
                      onChanged: _composerChanged,
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filled(
                    tooltip: context.tr('Send'),
                    onPressed: _sending || !_canSendMessage ? null : _send,
                    icon: _sending
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );

  Widget _messageBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.trError(_error!)),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _load,
                child: Text(context.tr('Try again')),
              ),
            ],
          ),
        ),
      );
    }
    if (_messages.isEmpty) {
      return Center(child: Text(context.tr('Say hello')));
    }
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      itemCount: _messages.length + (_nextCursor == null ? 0 : 1),
      itemBuilder: (context, index) {
        if (_nextCursor != null && index == 0) {
          return Center(
            child: TextButton.icon(
              onPressed: _loadingOlder ? null : _loadOlder,
              icon: _loadingOlder
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.history),
              label: Text(context.tr('Load older messages')),
            ),
          );
        }
        final message = _messages[index - (_nextCursor == null ? 0 : 1)];
        final mine = message.senderId == _viewerId;
        final colors = Theme.of(context).colorScheme;
        return Align(
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
          child: GestureDetector(
            onLongPress: message.removedAt == null
                ? () => _messageActions(message)
                : null,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 320),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: mine ? colors.primary : colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    message.removedAt == null
                        ? message.body
                        : context.tr('Message removed'),
                    style: TextStyle(
                      color: mine ? colors.onPrimary : colors.onSurface,
                      fontStyle: message.removedAt == null
                          ? null
                          : FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _shortTime(context, message.createdAt),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: mine
                              ? colors.onPrimary.withValues(alpha: .75)
                              : colors.onSurfaceVariant,
                        ),
                      ),
                      if (mine) ...[
                        const SizedBox(width: 4),
                        Icon(
                          message.readAt == null ? Icons.done : Icons.done_all,
                          size: 15,
                          color: message.readAt == null
                              ? colors.onPrimary.withValues(alpha: .75)
                              : colors.onPrimary,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

String _shortTime(BuildContext context, DateTime value) {
  final local = value.toLocal();
  final now = DateTime.now();
  if (local.year == now.year &&
      local.month == now.month &&
      local.day == now.day) {
    return MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(local));
  }
  return MaterialLocalizations.of(context).formatShortDate(local);
}
