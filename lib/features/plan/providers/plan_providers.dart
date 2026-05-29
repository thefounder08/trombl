import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/plan_repository.dart';

/// Feature-level plan repository provider.
final featurePlanRepoProvider = Provider<FeaturePlanRepository>((ref) {
  return FeaturePlanRepository(ref.watch(supabaseProvider));
});
