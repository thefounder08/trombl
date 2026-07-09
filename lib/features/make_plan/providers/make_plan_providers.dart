import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/models.dart';
import '../../plan/providers/plan_providers.dart';

/// Backs the Invite Friends step's search box. Debouncing lives in the
/// widget (via a short delay before updating this provider's argument), not
/// here — this just wraps FeaturePlanRepository.searchProfiles.
final profileSearchProvider =
    FutureProvider.autoDispose.family<List<Profile>, String>((ref, query) {
  return ref.watch(featurePlanRepoProvider).searchProfiles(query);
});
