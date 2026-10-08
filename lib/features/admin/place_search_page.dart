import 'dart:async';
import 'package:flutter/material.dart';
import '../../localization/app_language.dart';
import '../../services/place_search_service.dart';

class PlaceSearchPage extends StatefulWidget {
  const PlaceSearchPage({super.key, required this.search});
  final Future<List<PlaceResult>> Function(String query, String language)
  search;
  @override
  State<PlaceSearchPage> createState() => _PlaceSearchPageState();
}

class _PlaceSearchPageState extends State<PlaceSearchPage> {
  final _controller = TextEditingController();
  Timer? _debounce;
  int _request = 0;
  bool _loading = false;
  bool _failed = false;
  List<PlaceResult> _results = [];

  void _changed(String value) {
    _debounce?.cancel();
    final request = ++_request;
    setState(() {
      _results = [];
      _failed = false;
      _loading = value.trim().length >= 2;
    });
    if (_loading) {
      _debounce = Timer(
        const Duration(milliseconds: 350),
        () => _search(value, request),
      );
    }
  }

  Future<void> _search(String value, int request) async {
    try {
      final results = await widget.search(
        value.trim(),
        Localizations.localeOf(context).languageCode,
      );
      if (mounted && request == _request) {
        setState(() {
          _results = results;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted && request == _request) {
        setState(() {
          _failed = true;
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('Search city or place'))),
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              key: const ValueKey('place-search'),
              controller: _controller,
              autofocus: true,
              onChanged: _changed,
              textInputAction: TextInputAction.search,
              onSubmitted: _changed,
              decoration: InputDecoration(
                hintText: context.tr('Search by city, town or area'),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: context.tr('Clear search'),
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _controller.clear();
                    _changed('');
                  },
                ),
              ),
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_failed)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    context.tr('Unable to search locations. Please try again.'),
                  ),
                  TextButton(
                    onPressed: () => _changed(_controller.text),
                    child: Text(context.tr('Retry')),
                  ),
                ],
              ),
            ),
          if (!_loading && !_failed && _results.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                context.tr(
                  _controller.text.trim().length < 2
                      ? 'Enter at least 2 characters to search.'
                      : 'No locations found. Try another city or area.',
                ),
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final result = _results[index];
                return ListTile(
                  leading: const Icon(Icons.location_on_outlined),
                  title: Text(result.name),
                  subtitle: Text(result.label),
                  onTap: () => Navigator.pop(context, result),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'Open-Meteo · GeoNames',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    ),
  );
}
