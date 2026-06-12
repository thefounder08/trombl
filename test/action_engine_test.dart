import 'package:flutter_test/flutter_test.dart';
import 'package:trombl/features/menu/domain/action_engine.dart';
import 'package:trombl/features/menu/domain/menu_models.dart';

// Helper — build a MenuOption and call resolve.
ActionResult resolve(String label, String tag, {String? city}) =>
    ActionEngine.resolve(
      option: MenuOption(id: 'test', label: label, tag: tag),
      vibe: 'fomo',
      city: city,
    );

void main() {
  // ─── rest ───────────────────────────────────────────────────────────────────
  group('rest', () {
    test('default rest options → InternalRouteAction /dnd', () {
      final r = resolve('long shower or bath — full ritual', 'rest');
      expect(r, isA<InternalRouteAction>());
      expect((r as InternalRouteAction).route, '/dnd');
    });

    test('sleep / nap → /dnd', () {
      final r = resolve('sleep in or nap aggressively', 'rest');
      expect(r, isA<InternalRouteAction>());
    });

    test('"binge netflix or youtube" → Netflix ExternalUrlAction', () {
      final r = resolve('binge netflix or youtube', 'rest') as ExternalUrlAction;
      expect(r.url, contains('netflix.com'));
      expect(r.fallbackUrl, contains('youtube.com'));
    });

    test('"rewatch ur comfort show" → Netflix comfort-show search', () {
      final r = resolve('rewatch ur comfort show', 'rest') as ExternalUrlAction;
      expect(r.url, contains('netflix.com/search'));
      expect(r.url, contains('comfort'));
      expect(r.url, isNot(contains(' ')));
    });

    test('"full album, front to back" → Spotify', () {
      final r = resolve('full album, front to back', 'rest') as ExternalUrlAction;
      expect(r.url, startsWith('spotify://'));
      expect(r.fallbackUrl, contains('open.spotify.com'));
    });
  });

  // ─── coming soon ─────────────────────────────────────────────────────────────
  group('coming soon', () {
    test('returns ComingSoonAction', () {
      final r = resolve('game night at someones place', 'coming soon');
      expect(r, isA<ComingSoonAction>());
    });
  });

  // ─── squad ───────────────────────────────────────────────────────────────────
  group('squad', () {
    test('returns WhatsApp ExternalUrlAction', () {
      final r = resolve('text the group chat rn', 'squad');
      expect(r, isA<ExternalUrlAction>());
      expect((r as ExternalUrlAction).url, contains('wa.me'));
    });

    test('url is URI-valid', () {
      final r = resolve('text the group chat rn', 'squad') as ExternalUrlAction;
      expect(() => Uri.parse(r.url), returnsNormally);
      expect(r.url, isNot(contains(' ')));
    });
  });

  // ─── order in ────────────────────────────────────────────────────────────────
  group('order in', () {
    test('primary is always zomato deep link', () {
      final r = resolve('ur usual from that one place', 'order in') as ExternalUrlAction;
      expect(r.url, startsWith('zomato://'));
    });

    test('fallback with known city is city-scoped zomato web', () {
      final r = resolve('ur usual from that one place', 'order in', city: 'Mumbai')
          as ExternalUrlAction;
      expect(r.fallbackUrl, contains('zomato.com/mumbai'));
    });

    test('fallback without city is Google Maps delivery search', () {
      final r = resolve('ur usual from that one place', 'order in') as ExternalUrlAction;
      expect(r.fallbackUrl, contains('google.com/maps/search'));
      expect(r.fallbackUrl, contains('delivery'));
    });

    test('cuisine inference — pizza', () {
      final r = resolve('pizza night obviously', 'order in') as ExternalUrlAction;
      expect(r.url, contains('pizza'));
    });

    test('cuisine inference — biryani', () {
      final r = resolve('biryani for the soul', 'order in') as ExternalUrlAction;
      expect(r.url, contains('biryani'));
    });

    test('cuisine inference — coffee', () {
      final r = resolve('make a fancy coffee and sit with it', 'order in')
          as ExternalUrlAction;
      expect(r.url, contains('coffee'));
    });

    test('cuisine inference — snacks', () {
      final r = resolve('full snack spread, no actual meals', 'order in')
          as ExternalUrlAction;
      expect(r.url, contains('snack'));
    });

    test('cuisine inference — dessert from bake', () {
      final r = resolve('bake something (therapeutic fr)', 'order in') as ExternalUrlAction;
      expect(r.url, contains('dessert'));
    });

    test('all urls are URI-valid and contain no unencoded spaces', () {
      for (final label in [
        'ur usual from that one place',
        'full snack spread, no actual meals',
        'bake something (therapeutic fr)',
        'make a fancy coffee and sit with it',
      ]) {
        final r = resolve(label, 'order in') as ExternalUrlAction;
        expect(() => Uri.parse(r.url), returnsNormally,
            reason: 'primary URL invalid for "$label"');
        expect(r.url, isNot(contains(' ')),
            reason: 'unencoded space in primary for "$label"');
        if (r.fallbackUrl != null) {
          expect(() => Uri.parse(r.fallbackUrl!), returnsNormally,
              reason: 'fallback URL invalid for "$label"');
          expect(r.fallbackUrl, isNot(contains(' ')),
              reason: 'unencoded space in fallback for "$label"');
        }
      }
    });
  });

  // ─── discover ────────────────────────────────────────────────────────────────
  group('discover', () {
    test('"gym session before it fills up" → Google Maps gym', () {
      final r = resolve('gym session before it fills up', 'discover') as ExternalUrlAction;
      expect(r.url, contains('google.com/maps'));
      expect(r.url, contains('gym'));
    });

    test('"find a spot 5 min away" → Google Maps', () {
      final r = resolve('find a spot 5 min away', 'discover') as ExternalUrlAction;
      expect(r.url, contains('google.com/maps'));
    });

    test('"class near u" → Google Maps gym/class', () {
      final r = resolve('class near u', 'discover') as ExternalUrlAction;
      expect(r.url, contains('google.com/maps'));
    });

    test('event label → BookMyShow primary with Maps fallback', () {
      final r = resolve('live music or gig', 'discover') as ExternalUrlAction;
      expect(r.url, contains('bookmyshow.com'));
      expect(r.fallbackUrl, contains('google.com/maps'));
    });

    test('event label with city → city-scoped BookMyShow URL', () {
      final r = resolve('rooftop or house party', 'discover', city: 'Mumbai')
          as ExternalUrlAction;
      expect(r.url, contains('events-mumbai'));
    });

    test('event label without city → generic BookMyShow URL', () {
      final r = resolve('club / dance floor', 'discover') as ExternalUrlAction;
      expect(r.url, contains('bookmyshow.com/explore/events?q='));
      expect(r.url, isNot(contains('events-')));
    });

    test('all discover urls are URI-valid', () {
      for (final label in [
        'gym session before it fills up',
        'find a spot 5 min away',
        'live music or gig',
        'club / dance floor',
        'bar hop with the crew',
      ]) {
        final r = resolve(label, 'discover') as ExternalUrlAction;
        expect(() => Uri.parse(r.url), returnsNormally,
            reason: 'primary URL invalid for "$label"');
        expect(r.url, isNot(contains(' ')));
      }
    });
  });

  // ─── content ─────────────────────────────────────────────────────────────────
  group('content', () {
    test('spotify label → Spotify deep link with web fallback', () {
      final r = resolve('drop a new spotify playlist', 'content') as ExternalUrlAction;
      expect(r.url, startsWith('spotify://'));
      expect(r.fallbackUrl, contains('open.spotify.com'));
    });

    test('playlist label → Spotify', () {
      final r = resolve('drop a new spotify playlist', 'content') as ExternalUrlAction;
      expect(r.url, startsWith('spotify://'));
    });

    test('brain dump label → ChatSeedAction', () {
      final r = resolve('journal or full brain dump', 'content');
      expect(r, isA<ChatSeedAction>());
      expect((r as ChatSeedAction).seedText, isNotEmpty);
    });

    test('write label → ChatSeedAction', () {
      final r = resolve('write down 3 things', 'content');
      expect(r, isA<ChatSeedAction>());
    });

    test('reel label → Instagram reels deep link', () {
      final r = resolve('shoot a reel or vlog', 'content') as ExternalUrlAction;
      expect(r.url, contains('instagram'));
      expect(r.url, contains('reels'));
      expect(r.fallbackUrl, contains('instagram.com/reels'));
    });

    test('post/story label → instagram camera', () {
      final r = resolve('instagram post or story', 'content') as ExternalUrlAction;
      expect(r.url, contains('instagram://camera'));
    });

    test('default label → instagram home', () {
      final r = resolve('share ur vibe', 'content') as ExternalUrlAction;
      expect(r.url, startsWith('instagram://'));
      expect(r.fallbackUrl, contains('instagram.com'));
    });
  });

  // ─── solo ─────────────────────────────────────────────────────────────────────
  group('solo — every time-aware label resolves to non-FailedAction', () {
    // Complete table of solo-tagged options from all time-aware categories.
    const soloLabels = [
      // early morning
      'sunlight first, phone second',
      '5 minutes outside',
      'make something warm',
      'proper meal, no excuses',
      'quick walk outside',
      'whatever gets u breathing',
      'one small thing done',
      // workday
      'timer on, everything off',
      'one task, start to finish',
      'inbox zero, just one folder',
      'away from the desk — non-negotiable',
      'walk around the block',
      'find a bench',
      'clear the blocker',
      // prime time
      'just leave the house',
      'evening run or walk',
      'whatever tonight version of u wants',
      // wind-down
      'reflect on today honestly',
      'one thing for tomorrow',
      "lay out tomorrow's stuff",
      'make something warm to wind down',
      // weekend
      'just walk and see what u find',
      'park or green space',
      'trail or walk',
      'morning run or bike',
      'that thing u keep putting off',
    ];

    for (final label in soloLabels) {
      test('"$label"', () {
        final r = resolve(label, 'solo');
        expect(r, isNot(isA<FailedAction>()),
            reason: '"$label" returned FailedAction');
      });
    }
  });

  group('solo — keyword precedence', () {
    test('"watch the next episode" → Netflix (series keyword beats watch)', () {
      final r = resolve('watch the next episode', 'solo') as ExternalUrlAction;
      expect(r.url, contains('netflix.com'));
    });

    test('"rewatch ur comfort show" → Netflix search with encoded query', () {
      final r = resolve('rewatch ur comfort show', 'solo') as ExternalUrlAction;
      expect(r.url, contains('netflix.com/search'));
      expect(r.url, contains('comfort'));
      expect(r.url, isNot(contains(' ')));
    });

    test('Netflix URL never uses nflx:// scheme', () {
      for (final label in [
        'rewatch ur comfort show',
        'binge netflix or youtube',
        'watch the next episode',
        'watch ur favourite series',
      ]) {
        if (label.contains('binge')) continue; // binge → ChatSeed
        final r = resolve(label, 'solo');
        if (r is ExternalUrlAction) {
          expect(r.url, isNot(startsWith('nflx://')));
        }
      }
    });

    test('"binge" → ChatSeedAction', () {
      final r = resolve('binge something tonight', 'solo');
      expect(r, isA<ChatSeedAction>());
    });

    test('"make something warm to wind down" → ChatSeed (wind-down wins over make)', () {
      final r = resolve('make something warm to wind down', 'solo');
      expect(r, isA<ChatSeedAction>());
    });

    test('unknown/garbage label → FailedAction with non-empty message', () {
      final r = resolve('zzz totally unknown zzz', 'solo');
      expect(r, isA<FailedAction>());
      expect((r as FailedAction).message, isNotEmpty);
    });

    test('FailedAction never throws', () {
      expect(
        () => resolve('totally unparseable label xyz123', 'solo'),
        returnsNormally,
      );
    });
  });

  group('solo — all produced URLs are URI-valid with no unencoded spaces', () {
    const urlLabels = [
      'quick walk outside',       // Maps
      'gym session today',        // Maps gym
      'drop a playlist',          // Spotify (via solo)
      'rewatch ur comfort show',  // Netflix
      'watch a movie',            // YouTube
      'read actual pages',        // Goodreads
      'make something warm',      // YouTube recipe
    ];

    for (final label in urlLabels) {
      test('"$label"', () {
        final r = resolve(label, 'solo');
        if (r is ExternalUrlAction) {
          expect(() => Uri.parse(r.url), returnsNormally);
          expect(r.url, isNot(contains(' ')));
          if (r.fallbackUrl != null) {
            expect(() => Uri.parse(r.fallbackUrl!), returnsNormally);
            expect(r.fallbackUrl, isNot(contains(' ')));
          }
        }
      });
    }
  });

  // ─── analytics name ───────────────────────────────────────────────────────────
  group('ActionResult.name', () {
    test('ExternalUrlAction → "launched"', () {
      expect(
        resolve('quick walk outside', 'solo').name,
        'launched',
      );
    });
    test('InternalRouteAction → "internal"', () {
      expect(resolve('anything', 'rest').name, 'internal');
    });
    test('ComingSoonAction → "coming_soon"', () {
      expect(resolve('anything', 'coming soon').name, 'coming_soon');
    });
    test('FailedAction → "failed"', () {
      expect(resolve('zzz unknown zzz', 'solo').name, 'failed');
    });
    test('ChatSeedAction → "chat_seed"', () {
      expect(resolve('journal or full brain dump', 'content').name, 'chat_seed');
    });
  });
}
