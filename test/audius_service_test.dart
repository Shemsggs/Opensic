import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:opensic/audius_service.dart';

void main() {
  test('loads trending tracks and sends the optional API key header', () async {
    late http.Request capturedRequest;
    final service = AudiusService(
      apiKey: 'test-api-key',
      client: MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({
            'data': [
              {
                'id': 'track-123',
                'title': 'Independent Track',
                'user': {'name': 'Independent Artist'},
                'is_streamable': true,
                'stream': {'url': 'https://stream.example/track'},
                'artwork': {
                  '150x150': 'https://images.example/cover.jpg',
                },
              },
              {
                'id': 'unavailable',
                'title': 'Unavailable Track',
                'user': {'name': 'Independent Artist'},
                'is_streamable': false,
                'stream': {'url': 'https://stream.example/unavailable'},
              },
              {
                'id': 'insecure',
                'title': 'Insecure Stream',
                'user': {'name': 'Independent Artist'},
                'is_streamable': true,
                'stream': {'url': 'http://stream.example/track'},
              },
            ],
          }),
          200,
        );
      }),
    );

    final tracks = await service.fetchTracks();

    expect(capturedRequest.url.path, '/v1/tracks/trending');
    expect(capturedRequest.url.queryParameters['limit'], '50');
    expect(capturedRequest.headers['x-api-key'], 'test-api-key');
    expect(tracks, hasLength(1));
    expect(tracks.single.id, 'track-123');
    expect(tracks.single.title, 'Independent Track');
    expect(tracks.single.artist, 'Independent Artist');
    expect(tracks.single.streamUri, 'https://stream.example/track');
    expect(tracks.single.artworkUri, 'https://images.example/cover.jpg');
    service.close();
  });

  test('searches Audius and works without an API key', () async {
    late http.Request capturedRequest;
    final service = AudiusService(
      client: MockClient((request) async {
        capturedRequest = request;
        return http.Response('{"data":[]}', 200);
      }),
    );

    await service.fetchTracks(searchTerm: 'quiet night');

    expect(capturedRequest.url.path, '/v1/tracks/search');
    expect(capturedRequest.url.queryParameters['query'], 'quiet night');
    expect(capturedRequest.headers.containsKey('x-api-key'), isFalse);
    service.close();
  });

  test('reports API errors rather than returning an empty catalog', () async {
    final service = AudiusService(
      client: MockClient((_) async => http.Response('Unavailable', 503)),
    );

    await expectLater(
      service.fetchTracks(),
      throwsA(isA<http.ClientException>()),
    );
    service.close();
  });
}
