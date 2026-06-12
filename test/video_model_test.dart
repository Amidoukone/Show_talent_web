import 'package:flutter_test/flutter_test.dart';
import 'package:show_talent/models/video.dart';

void main() {
  group('Video model', () {
    test('fromMap resolves mobile playback contract to MP4 effective URL', () {
      final video = Video.fromMap(
        <String, dynamic>{
          'id': 'video-1',
          'videoUrl': 'https://cdn.example/master.m3u8',
          'thumbnailUrl': 'https://cdn.example/thumb.jpg',
          'description': 'Training session',
          'captionText': 'Best actions',
          'uid': 'player-1',
          'shareCount': '5',
          'reportCount': 2,
          'status': 'ready',
          'moderationStatus': 'approved',
          'optimized': true,
          'playback': {
            'version': 2,
            'sources': [
              {
                'url': 'https://cdn.example/video-720.mp4',
                'quality': '720p',
                'type': 'mp4',
              },
              {
                'url': 'https://cdn.example/video-480.mp4',
                'quality': '480p',
              },
            ],
            'fallback': {
              'url': 'https://cdn.example/video-fallback.mp4',
              'type': 'mp4',
            },
          },
        },
      );

      expect(video.videoUrl, 'https://cdn.example/video-fallback.mp4');
      expect(video.effectiveUrl, 'https://cdn.example/video-fallback.mp4');
      expect(video.thumbnailUrl, 'https://cdn.example/thumb.jpg');
      expect(video.description, 'Training session');
      expect(video.displayTitle, 'Best actions');
      expect(video.shareCount, 5);
      expect(video.reportCount, 2);
      expect(video.moderationStatus, 'approved');
      expect(video.optimized, isTrue);
      expect(video.sources, hasLength(3));
      expect(video.sources.first.height, 720);
      expect(video.hasMultipleMp4Sources, isTrue);
      expect(video.toMap()['playback'], isA<Map<String, dynamic>>());
    });

    test('displayTitle falls back to description then id', () {
      expect(
        Video.fromMap({
          'id': 'video-2',
          'description': 'Fallback title',
          'uid': 'user-1',
        }).displayTitle,
        'Fallback title',
      );
      expect(
        Video.fromMap({
          'id': 'video-3',
          'uid': 'user-1',
        }).displayTitle,
        'video-3',
      );
    });
  });
}
