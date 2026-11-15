import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class AudiusTrack {
  const AudiusTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.streamUri,
    this.artworkUri,
  });

  final String id;
  final String title;
  final String artist;
  final String streamUri;
  final String? artworkUri;
}

class AudiusService {
  AudiusService({
    this.apiKey = '',
    http.Client? client,
  }) : _client = client ?? http.Client();

  static const _baseUri = 'https://api.audius.co/v1';

  final String apiKey;
  final http.Client _client;

  Future<List<AudiusTrack>> fetchTracks({String searchTerm = ''}) async {
    final trimmedSearch = searchTerm.trim();
    final uri = Uri.parse(
      '$_baseUri/tracks/${trimmedSearch.isEmpty ? 'trending' : 'search'}',
    ).replace(queryParameters: {
      if (trimmedSearch.isNotEmpty) 'query': trimmedSearch,
      'limit': '50',
    });
    final response = await _get(uri);
    final body = jsonDecode(await response.stream.bytesToString());
    if (body is! Map<String, dynamic> || body['data'] is! List<dynamic>) {
      throw const FormatException('Audius returned an unexpected response.');
    }

    return (body['data'] as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(_parseTrack)
        .whereType<AudiusTrack>()
        .toList();
  }

  Future<http.StreamedResponse> _get(Uri uri) async {
    final request = http.Request('GET', uri)
      ..followRedirects = false
      ..headers.addAll({
        if (apiKey.trim().isNotEmpty) 'x-api-key': apiKey.trim(),
      });
    try {
      final response = await _client.send(request).timeout(
            const Duration(seconds: 15),
          );
      if ((response.statusCode >= 200 && response.statusCode < 300) ||
          (response.statusCode >= 300 && response.statusCode < 400)) {
        return response;
      }
      await response.stream.drain<void>();
      throw http.ClientException(
        'Audius API returned HTTP ${response.statusCode}.',
        uri,
      );
    } on TimeoutException {
      throw http.ClientException('Audius API request timed out.', uri);
    }
  }

  AudiusTrack? _parseTrack(Map<String, dynamic> json) {
    final id = json['id']?.toString();
    final title = json['title'];
    final user = json['user'];
    final artist = user is Map<String, dynamic> ? user['name'] : null;
    final stream = json['stream'];
    final streamUrl = stream is Map<String, dynamic> ? stream['url'] : null;
    if (id == null ||
        title is! String ||
        title.trim().isEmpty ||
        artist is! String ||
        artist.trim().isEmpty ||
        streamUrl is! String ||
        json['is_streamable'] == false) {
      return null;
    }

    final streamUri = Uri.tryParse(streamUrl);
    if (streamUri == null ||
        streamUri.scheme != 'https' ||
        streamUri.host.isEmpty) {
      return null;
    }
    final artwork = json['artwork'];
    final artworkUrl =
        artwork is Map<String, dynamic> ? artwork['150x150'] : null;
    final artworkUri = artworkUrl is String ? Uri.tryParse(artworkUrl) : null;

    return AudiusTrack(
      id: id,
      title: title.trim(),
      artist: artist.trim(),
      streamUri: streamUri.toString(),
      artworkUri: artworkUri?.scheme == 'https' ? artworkUrl as String : null,
    );
  }

  void close() => _client.close();
}
