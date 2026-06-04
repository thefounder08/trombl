import '../context/context_models.dart';
import 'action_models.dart';

/// Local action catalog. Never generated dynamically — stable, curated.
/// Scoring engine filters + ranks these based on context.
abstract final class ActionLibrary {
  // ─── Social ──────────────────────────────────────────────────────────────────

  static const _social = <TromblAction>[
    TromblAction(
      id: 'text_group_chat', title: 'text the group chat',
      description: 'start a plan or just check in',
      category: ActionCategory.social, tags: ['squad'],
      timeRequiredMin: 5, energyRequired: 1, socialRequired: 2,
    ),
    TromblAction(
      id: 'call_someone', title: 'call someone you owe a call',
      description: 'ur phone works both ways',
      category: ActionCategory.social, tags: ['squad'],
      timeRequiredMin: 20, energyRequired: 1, socialRequired: 2,
    ),
    TromblAction(
      id: 'make_plans_tonight', title: 'make actual plans tonight',
      description: 'stop saying soon. make it real.',
      category: ActionCategory.social, tags: ['squad', 'discover'],
      timeRequiredMin: 10, energyRequired: 2, socialRequired: 3,
    ),
    TromblAction(
      id: 'reach_one_person', title: 'reach out to that one person',
      description: 'u know who',
      category: ActionCategory.social, tags: ['squad'],
      timeRequiredMin: 5, energyRequired: 1, socialRequired: 2,
    ),
    TromblAction(
      id: 'game_night', title: 'set up a game night',
      description: 'whoever says yes in 10 min is in',
      category: ActionCategory.social, tags: ['squad'],
      timeRequiredMin: 120, energyRequired: 2, socialRequired: 3,
    ),
  ];

  // ─── Adventure ───────────────────────────────────────────────────────────────

  static const _adventure = <TromblAction>[
    TromblAction(
      id: 'leave_no_plan', title: 'leave the house with no plan',
      description: 'just go. figure it out.',
      category: ActionCategory.adventure, tags: ['discover', 'solo'],
      timeRequiredMin: 60, energyRequired: 2, socialRequired: 1,
    ),
    TromblAction(
      id: 'find_event', title: 'find one event near u',
      description: 'open maps, filter by today',
      category: ActionCategory.adventure, tags: ['discover'],
      timeRequiredMin: 10, energyRequired: 2, socialRequired: 2,
    ),
    TromblAction(
      id: 'new_neighbourhood', title: 'explore a different neighbourhood',
      description: 'somewhere u never go',
      category: ActionCategory.adventure, tags: ['discover', 'solo'],
      timeRequiredMin: 90, energyRequired: 2, socialRequired: 1,
    ),
    TromblAction(
      id: 'bar_hop', title: 'bar hop with no destination',
      description: 'first person to suggest a place leads',
      category: ActionCategory.adventure, tags: ['squad', 'discover'],
      timeRequiredMin: 180, energyRequired: 3, socialRequired: 3,
    ),
  ];

  // ─── Build ───────────────────────────────────────────────────────────────────

  static const _build = <TromblAction>[
    TromblAction(
      id: 'focus_sprint_25', title: '25-min focus sprint',
      description: 'phone down, one task, timer on',
      category: ActionCategory.build, tags: ['solo'],
      timeRequiredMin: 25, energyRequired: 2, socialRequired: 1,
    ),
    TromblAction(
      id: 'ship_one_thing', title: 'ship one small thing today',
      description: 'done is better than perfect',
      category: ActionCategory.build, tags: ['solo', 'content'],
      timeRequiredMin: 60, energyRequired: 3, socialRequired: 1,
    ),
    TromblAction(
      id: 'brain_dump', title: 'full brain dump — write everything',
      description: 'clear the backlog, pick one thing',
      category: ActionCategory.build, tags: ['solo', 'content'],
      timeRequiredMin: 20, energyRequired: 1, socialRequired: 1,
    ),
    TromblAction(
      id: 'portfolio_update', title: 'update ur portfolio / profile',
      description: 'future u will thank u',
      category: ActionCategory.build, tags: ['solo', 'content'],
      timeRequiredMin: 45, energyRequired: 2, socialRequired: 1,
    ),
  ];

  // ─── Selfcare ─────────────────────────────────────────────────────────────────

  static const _selfcare = <TromblAction>[
    TromblAction(
      id: 'long_shower', title: 'full shower + grooming ritual',
      description: 'not a 5-minute one. the real one.',
      category: ActionCategory.selfcare, tags: ['rest'],
      timeRequiredMin: 30, energyRequired: 1, socialRequired: 1,
    ),
    TromblAction(
      id: 'proper_sleep', title: 'actually go to sleep',
      description: 'phone down. dark room. no excuses.',
      category: ActionCategory.selfcare, tags: ['rest'],
      timeRequiredMin: 480, energyRequired: 1, socialRequired: 1,
    ),
    TromblAction(
      id: 'workout', title: 'gym or any real movement',
      description: 'u know u feel better after',
      category: ActionCategory.selfcare, tags: ['solo', 'discover'],
      timeRequiredMin: 60, energyRequired: 3, socialRequired: 1,
    ),
    TromblAction(
      id: 'breathe_5', title: '5 minutes of box breathing',
      description: '4 in, 4 hold, 4 out. ur nervous system will thank u',
      category: ActionCategory.selfcare, tags: ['rest'],
      timeRequiredMin: 5, energyRequired: 1, socialRequired: 1,
    ),
    TromblAction(
      id: 'walk_20', title: '20-min walk, no phone',
      description: 'actual reset. not content consumption.',
      category: ActionCategory.selfcare, tags: ['solo'],
      timeRequiredMin: 20, energyRequired: 1, socialRequired: 1,
    ),
  ];

  // ─── Entertainment ───────────────────────────────────────────────────────────

  static const _entertainment = <TromblAction>[
    TromblAction(
      id: 'pick_show_commit', title: 'pick one show and actually commit',
      description: 'no scrolling for 30 min. just pick.',
      category: ActionCategory.entertainment, tags: ['rest'],
      timeRequiredMin: 45, energyRequired: 1, socialRequired: 1,
    ),
    TromblAction(
      id: 'order_in_cozy', title: 'order ur comfort food + rot',
      description: 'the full jomo ritual',
      category: ActionCategory.entertainment, tags: ['order in', 'rest'],
      timeRequiredMin: 30, energyRequired: 1, socialRequired: 1,
    ),
    TromblAction(
      id: 'new_album_front_back', title: 'one full album front to back',
      description: 'not a playlist. an album. with intention.',
      category: ActionCategory.entertainment, tags: ['rest', 'solo'],
      timeRequiredMin: 45, energyRequired: 1, socialRequired: 1,
    ),
    TromblAction(
      id: 'read_anything', title: 'read something for 20 min',
      description: 'article, book, newsletter — anything',
      category: ActionCategory.entertainment, tags: ['rest', 'solo'],
      timeRequiredMin: 20, energyRequired: 1, socialRequired: 1,
    ),
  ];

  // ─── Learning ─────────────────────────────────────────────────────────────────

  static const _learning = <TromblAction>[
    TromblAction(
      id: 'rabbit_hole', title: 'fall down one rabbit hole',
      description: 'one thing ur curious about. go.',
      category: ActionCategory.learning, tags: ['solo'],
      timeRequiredMin: 30, energyRequired: 2, socialRequired: 1,
    ),
    TromblAction(
      id: 'skill_30', title: '30 min on a skill u want',
      description: 'any skill. consistent beats perfect.',
      category: ActionCategory.learning, tags: ['solo'],
      timeRequiredMin: 30, energyRequired: 2, socialRequired: 1,
    ),
    TromblAction(
      id: 'podcast_walk', title: 'podcast + walk combo',
      description: 'move ur body AND ur mind',
      category: ActionCategory.learning, tags: ['solo'],
      timeRequiredMin: 30, energyRequired: 1, socialRequired: 1,
    ),
  ];

  // ─── Money ───────────────────────────────────────────────────────────────────

  static const _money = <TromblAction>[
    TromblAction(
      id: 'check_finances', title: 'actually look at ur bank account',
      description: 'ignorance is not bliss here',
      category: ActionCategory.money, tags: ['solo'],
      timeRequiredMin: 15, energyRequired: 1, socialRequired: 1,
    ),
    TromblAction(
      id: 'apply_one_thing', title: 'submit one application',
      description: 'job, grant, opportunity — one shot',
      category: ActionCategory.money, tags: ['solo', 'content'],
      timeRequiredMin: 45, energyRequired: 2, socialRequired: 1,
    ),
  ];

  // ─── Public API ──────────────────────────────────────────────────────────────

  static const all = <TromblAction>[
    ..._social,
    ..._adventure,
    ..._build,
    ..._selfcare,
    ..._entertainment,
    ..._learning,
    ..._money,
  ];

  static TromblAction? byId(String id) {
    try {
      return all.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Filter actions appropriate for a given time period.
  static List<TromblAction> forContext(TimePeriod period, String vibe) {
    return all.where((a) => _isAppropriate(a, period, vibe)).toList();
  }

  static bool _isAppropriate(
      TromblAction a, TimePeriod period, String vibe) {
    // Deep night: only rest/selfcare allowed
    if (period == TimePeriod.deepNight) {
      return a.category == ActionCategory.selfcare &&
          a.tags.contains('rest');
    }

    // Work hours: no high-energy social, no adventure
    if (period == TimePeriod.workMorning ||
        period == TimePeriod.workAfternoon) {
      if (a.category == ActionCategory.adventure && a.timeRequiredMin > 30) {
        return false;
      }
      if (a.socialRequired == 3) return false; // crowd-level social
    }

    // Wind-down: no high-energy
    if (period == TimePeriod.windDown) {
      if (a.energyRequired == 3) return false;
    }

    // jomo: deprioritise high-social adventure
    if (vibe == 'jomo' && a.socialRequired == 3) return false;

    return true;
  }
}
