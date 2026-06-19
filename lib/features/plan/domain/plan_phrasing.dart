// Shared label → human invitation copy.
// Also contains formatStartTime() used by both plan screens.

/// Formats a plan's starts_at timestamp as a short relative label.
/// e.g. "tonight · 9 pm", "tomorrow · 8 pm", "sat · 8 pm".
/// Returns null if [dt] is null.
String? formatStartTime(DateTime? dt) {
  if (dt == null) return null;
  final now = DateTime.now();
  final today    = DateTime(now.year, now.month, now.day);
  final tomorrow = today.add(const Duration(days: 1));
  final planDay  = DateTime(dt.year, dt.month, dt.day);

  final h    = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
  final amPm = dt.hour >= 12 ? 'pm' : 'am';
  final timeStr = dt.minute == 0
      ? '$h $amPm'
      : '$h:${dt.minute.toString().padLeft(2, '0')} $amPm';

  if (planDay == today)    return 'tonight · $timeStr';
  if (planDay == tomorrow) return 'tomorrow · $timeStr';
  const days = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
  return '${days[dt.weekday - 1]} · $timeStr';
}


// Used by create_plan_screen (title pre-fill) and plan_landing_screen
// (headline for strangers). Both import from here so the mapping never
// diverges. When menu_data.dart gets a new option, add its mapping here.

String planPhrasing(String rawLabel) {
  const map = <String, String>{
    // go out tonight
    'rooftop or house party':                    "rooftop or house party tonight",
    'live music or gig':                         "there's live music tonight",
    'bar hop with the crew':                     "bar hopping tonight",
    'club / dance floor':                        "dance floor tonight",
    // make plans
    'text the group chat rn':                    "we're going out tonight",
    'reach out to that one person':              "let's actually hang",
    "game night at someone's place":             "game night is happening",
    'find something random and drag everyone':   "something random tonight",
    // treat urself
    'do something the future-you will remember': "doing something worth remembering",
    'fancy dinner, main character era':          "fancy dinner tonight",
    'book a concert or show':                    "we got tickets",
    'get ur hair or nails done':                 "self-care day",
    // make / post
    'instagram post or story':                   "making content today",
    'shoot a reel or vlog':                      "vlog day",
    'drop a new spotify playlist':               "making a new playlist",
    'post ur honest opinion on something':       "dropping an opinion",
    // move ur body
    'gym session — actually go':                 "gym session — actually going",
    'group fitness class (pilates, boxing)':     "fitness class together",
    'look up outdoor things happening today':    "something outdoors today",
    'hike or trail':                             "hiking today",
    // jomo: rot
    'binge netflix or youtube':                  "netflix night",
    'rewatch ur comfort show':                   "comfort show night",
    'sleep in or nap aggressively':              "aggressive nap session",
    'do absolutely nothing':                     "doing absolutely nothing",
    // food
    'ur usual from that one place':              "ordering in tonight",
    'full snack spread, no actual meals':        "full snack spread",
    'bake something (therapeutic fr)':           "baking something",
    'make a fancy coffee and sit with it':       "fancy coffee and chill",
    // soft recharge
    'do a full face mask and decompress':        "face mask night",
    'journal or full brain dump':                "brain dump session",
    'long shower or bath — full ritual':         "full bath ritual",
    'clean and organise ur space':               "cleaning the space",
    // get in ur head
    'write down everything on ur mind':          "brain dump session",
    'vision board ur next 6 months':             "vision boarding",
    'reflect on the last month honestly':        "monthly reflection",
    'write a letter to ur future self':          "writing to future me",
    // music
    'full album, front to back':                 "full album session",
    'build a new playlist from scratch':         "building a new playlist",
    'find a completely new artist':              "discovering new music",
    'podcast deep dive on something random':     "podcast deep dive",
  };
  return map[rawLabel.toLowerCase().trim()] ?? rawLabel;
}
