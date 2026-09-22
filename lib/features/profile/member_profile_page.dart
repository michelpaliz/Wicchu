import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';
import '../../localization/app_language.dart';
import '../community/comments_sheet.dart';
import '../community/post_card.dart';
import '../community/post_detail_page.dart';

class MemberProfilePage extends StatefulWidget {
  const MemberProfilePage({
    super.key,
    required this.userId,
    required this.repository,
  });

  final String userId;
  final CommunityRepository repository;

  @override
  State<MemberProfilePage> createState() => _MemberProfilePageState();
}

class _MemberProfilePageState extends State<MemberProfilePage> {
  String _kind = 'all';
  String _sort = 'newest';
  late Future<PublicMemberProfile> _profile = widget.repository.getMemberProfile(widget.userId);
  late Future<List<CommunityPost>> _posts = _loadPosts();

  Future<List<CommunityPost>> _loadPosts() => widget.repository.listMemberPosts(
    widget.userId,
    kind: _kind,
    sort: _sort,
  );

  void _reload() => setState(() {
    _profile = widget.repository.getMemberProfile(widget.userId);
    _posts = _loadPosts();
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('Member profile'))),
    body: RefreshIndicator(
      onRefresh: () async {
        _reload();
        await Future.wait([_profile, _posts]);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          FutureBuilder<PublicMemberProfile>(
            future: _profile,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const LinearProgressIndicator();
              final profile = snapshot.data!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 34,
                        backgroundImage: profile.avatarUrl == null ? null : NetworkImage(profile.avatarUrl!),
                        child: profile.avatarUrl == null ? const Icon(Icons.person_outline, size: 34) : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(profile.name, style: Theme.of(context).textTheme.titleLarge),
                            if (profile.userName.isNotEmpty) Text('@${profile.userName}'),
                            Text(context.tr('{posts} posts · {communities} communities', {
                              'posts': '${profile.postCount}',
                              'communities': '${profile.communityCount}',
                            })),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (!profile.socialLinks.isEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        if (profile.socialLinks.whatsapp.isNotEmpty)
                          ActionChip(label: const Text('WhatsApp'), avatar: const Icon(Icons.chat_outlined, size: 18), onPressed: () => _openSocial('whatsapp', profile.socialLinks.whatsapp)),
                        if (profile.socialLinks.facebook.isNotEmpty)
                          ActionChip(label: const Text('Facebook'), avatar: const Icon(Icons.facebook, size: 18), onPressed: () => _openSocial('facebook', profile.socialLinks.facebook)),
                        if (profile.socialLinks.instagram.isNotEmpty)
                          ActionChip(label: const Text('Instagram'), avatar: const Icon(Icons.camera_alt_outlined, size: 18), onPressed: () => _openSocial('instagram', profile.socialLinks.instagram)),
                        if (profile.socialLinks.email.isNotEmpty)
                          ActionChip(label: const Text('Email'), avatar: const Icon(Icons.email_outlined, size: 18), onPressed: () => _openSocial('email', profile.socialLinks.email)),
                      ],
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            children: [
              for (final kind in const ['all', 'media', 'polls'])
                ChoiceChip(
                  label: Text(context.tr(switch (kind) {
                    'media' => 'Media',
                    'polls' => 'Polls',
                    _ => 'All posts',
                  })),
                  selected: _kind == kind,
                  onSelected: (_) => setState(() {
                    _kind = kind;
                    _posts = _loadPosts();
                  }),
                ),
              DropdownButton<String>(
                value: _sort,
                items: [
                  DropdownMenuItem(value: 'newest', child: Text(context.tr('Newest'))),
                  DropdownMenuItem(value: 'oldest', child: Text(context.tr('Oldest'))),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _sort = value;
                    _posts = _loadPosts();
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<CommunityPost>>(
            future: _posts,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) return Text(context.trError(snapshot.error!));
              final posts = snapshot.data ?? const [];
              if (posts.isEmpty) return Padding(
                padding: const EdgeInsets.all(24),
                child: Center(child: Text(context.tr('No posts found'))),
              );
              return Column(children: [
                for (final post in posts) ...[
                  PostCard(
                    category: 'Post',
                    icon: '💬',
                    community: 'Wicchu',
                    author: post.authorName,
                    time: formatPostTime(context, post.createdAt),
                    text: post.text,
                    likes: post.reactionCount,
                    comments: post.commentCount,
                    media: post.media,
                    poll: post.poll,
                    reacted: post.reactedByMe,
                    saved: post.savedByMe,
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => PostDetailPage(postId: post.id, repository: widget.repository, initialPost: post),
                    )).then((_) => _reload()),
                    onReaction: (reacted) => widget.repository.setPostReaction(post.id, reacted: reacted),
                    onPollVote: (optionId) => widget.repository.voteOnPost(post.id, optionId),
                    onComments: () => showPostComments(context, widget.repository, post),
                    onSaved: (saved) => widget.repository.setPostSaved(post.id, saved: saved),
                  ),
                  const SizedBox(height: 12),
                ],
              ]);
            },
          ),
        ],
      ),
    ),
  );

  Future<void> _openSocial(String network, String value) async {
    final uri = switch (network) {
      'whatsapp' => Uri.parse('https://wa.me/${value.replaceFirst('+', '')}'),
      'facebook' => value.startsWith('https://') ? Uri.parse(value) : Uri.parse('https://facebook.com/$value'),
      'instagram' => value.startsWith('https://') ? Uri.parse(value) : Uri.parse('https://instagram.com/$value'),
      _ => Uri(scheme: 'mailto', path: value),
    };
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Unable to open link'))));
    }
  }
}
