import '../../../shared/models/models.dart';
import '../../decide/domain/ai_pick_model.dart';

/// A single line in the Wrap Up review — either a menu Pick or an accepted
/// AiPick. Wrap Up shows everything you decided today in one list instead
/// of splitting menu picks (session-scoped) and AI picks (resolved via the
/// separate resume popup) across two places.
sealed class CheckinItem {
  const CheckinItem();
  String get id;
  String get label;
  bool get done;
}

class CheckinPickItem extends CheckinItem {
  const CheckinPickItem(this.pick);
  final Pick pick;

  @override
  String get id => pick.id;
  @override
  String get label => pick.label;
  @override
  bool get done => pick.done;
}

class CheckinAiPickItem extends CheckinItem {
  const CheckinAiPickItem(this.aiPick);
  final AiPick aiPick;

  @override
  String get id => aiPick.id;
  @override
  String get label => aiPick.pickText;
  @override
  bool get done => aiPick.done ?? false;
}
