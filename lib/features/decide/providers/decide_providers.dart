import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../vibe/providers/session_providers.dart';
import '../data/decide_repository.dart';

final decideRepositoryProvider = Provider<DecideRepository>((ref) {
  return DecideRepository(
    ref.watch(supabaseProvider),
    ref.watch(sessionRepositoryProvider),
  );
});
