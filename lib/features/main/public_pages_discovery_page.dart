import 'dart:async';
import 'package:flutter/material.dart';
import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';
import '../../localization/app_language.dart';
import '../../theme/wicchu_icons.dart';
import '../../widgets/wicchu_list_tile.dart';
import '../../widgets/wicchu_search_field.dart';
import '../community/community_avatar.dart';
import '../community/community_profile_page.dart';

class PublicPagesDiscoveryPage extends StatefulWidget {
  const PublicPagesDiscoveryPage({super.key, required this.repository});
  final CommunityRepository repository;

  @override
  State<PublicPagesDiscoveryPage> createState() =>
      _PublicPagesDiscoveryPageState();
}

class _PublicPagesDiscoveryPageState extends State<PublicPagesDiscoveryPage> {
  final _search = TextEditingController();
  Timer? _debounce;
  late Future<List<Community>> _pages = _load();

  Future<List<Community>> _load() async =>
      (await widget.repository.listCommunities(
        query: _search.text.trim(),
      )).where((page) => page.isPublicProfile && page.published).toList();

  Future<void> _refresh() async {
    final request = _load();
    setState(() {
      _pages = request;
    });
    try {
      await request;
    } catch (_) {
      /* Render retry below. */
    }
  }

  void _searchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _refresh);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('Explore pages'))),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: WicchuSearchField(
            controller: _search,
            hintText: context.tr('Search pages'),
            onChanged: _searchChanged,
            onClear: () {
              _search.clear();
              _searchChanged('');
            },
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Community>>(
            future: _pages,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              final pages = snapshot.data ?? const <Community>[];
              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    if (snapshot.hasError)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Text(context.trError(snapshot.error!)),
                            TextButton(
                              onPressed: _refresh,
                              child: Text(context.tr('Retry')),
                            ),
                          ],
                        ),
                      )
                    else if (pages.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          context.tr('No pages found'),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    for (final page in pages)
                      WicchuListTile(
                        variant: WicchuListVariant.business,
                        leading: CommunityAvatar(community: page, radius: 23),
                        title: Text(page.name),
                        subtitle: Text(
                          '${context.tr(page.spaceTypeLabel)} · ${page.town.name}',
                        ),
                        trailing: const Icon(WicchuIcons.caretRight, size: 18),
                        onTap: () async {
                          await Navigator.push<void>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CommunityProfilePage(
                                community: page,
                                repository: widget.repository,
                              ),
                            ),
                          );
                          if (mounted) await _refresh();
                        },
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}
