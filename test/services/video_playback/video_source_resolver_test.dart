import 'dart:io';

import 'package:beat_that/services/supabase_service.dart';
import 'package:beat_that/services/video_playback/video_source_resolver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSupabaseService extends Mock implements SupabaseService {}

void main() {
  late MockSupabaseService supabaseService;
  late VideoSourceResolver resolver;

  setUp(() {
    supabaseService = MockSupabaseService();
    resolver = VideoSourceResolver(supabaseService: supabaseService);
  });

  test('returns http and https URLs unchanged', () async {
    expect(
      await resolver.resolve('https://cdn.example.com/a.mp4'),
      'https://cdn.example.com/a.mp4',
    );
    expect(
      await resolver.resolve('http://cdn.example.com/b.mp4'),
      'http://cdn.example.com/b.mp4',
    );
    verifyNever(() => supabaseService.resolveVideoPlaybackUrl(any()));
  });

  test('returns an existing local file path as-is', () async {
    final directory = await Directory.systemTemp.createTemp('resolver_test');
    addTearDown(() => directory.delete(recursive: true));
    final file = await File('${directory.path}/clip.mp4').create();

    expect(await resolver.resolve(file.path), file.path);
    verifyNever(() => supabaseService.resolveVideoPlaybackUrl(any()));
  });

  test('resolves a storage path through Supabase', () async {
    when(
      () => supabaseService.resolveVideoPlaybackUrl('user/clip.mp4'),
    ).thenAnswer((_) async => 'https://storage.example.com/user/clip.mp4');

    expect(
      await resolver.resolve('user/clip.mp4'),
      'https://storage.example.com/user/clip.mp4',
    );
  });

  test('propagates Supabase errors', () async {
    when(
      () => supabaseService.resolveVideoPlaybackUrl(any()),
    ).thenThrow(Exception('storage unavailable'));

    expect(() => resolver.resolve('user/clip.mp4'), throwsException);
  });
}
