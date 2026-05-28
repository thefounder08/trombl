import 'package:freezed_annotation/freezed_annotation.dart';

part 'models.freezed.dart';
part 'models.g.dart';

/// Mirrors public.profiles
@freezed
class Profile with _$Profile {
  const factory Profile({
    required String id,
    @JsonKey(name: 'display_name') String? displayName,
    String? handle,
    String? city,
  }) = _Profile;

  factory Profile.fromJson(Map<String, dynamic> json) =>
      _$ProfileFromJson(json);
}

/// Mirrors public.sessions
@freezed
class Session with _$Session {
  const factory Session({
    required String id,
    @JsonKey(name: 'user_id') required String userId,
    required String vibe, // 'fomo' | 'jomo'
    String? city,
    @JsonKey(name: 'started_at') DateTime? startedAt,
    @JsonKey(name: 'wrapped_at') DateTime? wrappedAt,
  }) = _Session;

  factory Session.fromJson(Map<String, dynamic> json) =>
      _$SessionFromJson(json);
}

/// Mirrors public.picks
@freezed
class Pick with _$Pick {
  const factory Pick({
    required String id,
    @JsonKey(name: 'session_id') required String sessionId,
    @JsonKey(name: 'user_id') required String userId,
    @JsonKey(name: 'category_id') required String categoryId,
    @JsonKey(name: 'option_id') required String optionId,
    required String label,
    required String tag,
    @Default(false) bool done,
  }) = _Pick;

  factory Pick.fromJson(Map<String, dynamic> json) => _$PickFromJson(json);
}

/// Mirrors public.plans
@freezed
class Plan with _$Plan {
  const factory Plan({
    required String id,
    @JsonKey(name: 'owner_id') required String ownerId,
    required String vibe,
    required String title,
    String? detail,
    @JsonKey(name: 'share_token') required String shareToken,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  }) = _Plan;

  factory Plan.fromJson(Map<String, dynamic> json) => _$PlanFromJson(json);
}

/// Mirrors public.plan_members
@freezed
class PlanMember with _$PlanMember {
  const factory PlanMember({
    required String id,
    @JsonKey(name: 'plan_id') required String planId,
    @JsonKey(name: 'user_id') required String userId,
    required String status, // 'in' | 'out' | 'maybe'
    @JsonKey(name: 'created_at') DateTime? createdAt,
  }) = _PlanMember;

  factory PlanMember.fromJson(Map<String, dynamic> json) =>
      _$PlanMemberFromJson(json);
}

/// Mirrors public.memory_nodes — trom's observations about you.
@freezed
class MemoryNode with _$MemoryNode {
  const factory MemoryNode({
    required String id,
    @JsonKey(name: 'user_id') required String userId,
    required String type,
    required String content,
    @JsonKey(name: 'relevance_score') double? relevanceScore,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  }) = _MemoryNode;

  factory MemoryNode.fromJson(Map<String, dynamic> json) =>
      _$MemoryNodeFromJson(json);
}
