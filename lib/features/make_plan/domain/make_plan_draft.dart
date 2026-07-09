import '../../../shared/models/models.dart';
import '../../menu/domain/menu_models.dart';

/// In-progress state for the Make Plan wizard. Held locally by
/// MakePlanScreen's state (mirrors how CreatePlanScreen already manages its
/// own form fields) — this never needs to be read from elsewhere in the
/// widget tree, so it isn't a Riverpod provider.
class MakePlanDraft {
  const MakePlanDraft({
    required this.vibe,
    this.category,
    this.option,
    this.startsAt,
    this.location,
    this.invited = const [],
  });

  final String vibe;
  final MenuCategory? category;
  final MenuOption? option;
  final DateTime? startsAt;
  final String? location;
  final List<Profile> invited;

  bool get hasActivity => option != null;

  MakePlanDraft copyWith({
    MenuCategory? category,
    MenuOption? option,
    DateTime? startsAt,
    bool clearStartsAt = false,
    String? location,
    bool clearLocation = false,
    List<Profile>? invited,
  }) {
    return MakePlanDraft(
      vibe: vibe,
      category: category ?? this.category,
      option: option ?? this.option,
      startsAt: clearStartsAt ? null : (startsAt ?? this.startsAt),
      location: clearLocation ? null : (location ?? this.location),
      invited: invited ?? this.invited,
    );
  }
}
