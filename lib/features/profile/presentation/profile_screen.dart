import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/providers.dart';
import '../../../core/theme/trombl_theme.dart';
import '../../../shared/models/models.dart';
import '../../decide/domain/ai_pick_model.dart';
import '../../decide/providers/decide_providers.dart';
import '../../vibe/providers/session_providers.dart';
import '../../plans/providers/plan_providers.dart';
import '../domain/troms_read.dart';

// Route stays /profile for now — rename later (see CLAUDE.md naming notes).
// Nav label: person icon only, no text (see home_screen.dart / menu_screen.dart).

final _currentProfileProvider = FutureProvider.autoDispose<Profile?>((ref) {
  return ref.watch(sessionRepositoryProvider).getProfile();
});

typedef TromsReadData = ({
  int sessionCount,
  int pickCount,
  List<Session> sessions,
  List<AiPick> picks,
  List<MemoryNode> memoryNodes,
});

final _tromsReadDataProvider = FutureProvider.autoDispose<TromsReadData>((ref) async {
  final sessionRepo = ref.watch(sessionRepositoryProvider);
  final decideRepo = ref.watch(decideRepositoryProvider);
  final sessions = await sessionRepo.recentSessions(days: 90);
  final picks = await decideRepo.recentAiPicks(limit: 50);
  final memoryNodes = await sessionRepo.recentMemoryNodes(limit: 30);
  return (
    sessionCount: sessions.length,
    pickCount: picks.length,
    sessions: sessions,
    picks: picks,
    memoryNodes: memoryNodes,
  );
});

void _showEditProfile(BuildContext context, WidgetRef ref, Profile? profile) {
  final nameCtrl = TextEditingController(text: profile?.displayName ?? '');
  final handleCtrl = TextEditingController(
      text: profile?.handle != null ? '@${profile!.handle}' : '');
  final cityCtrl = TextEditingController(text: profile?.city ?? '');

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => StatefulBuilder(
      builder: (ctx, setState) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: TromblColors.bg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('ur profile',
                  style: TextStyle(
                      fontFamily: TromblText.serif,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: TromblColors.text)),
              const SizedBox(height: 18),
              _ProfileField(ctrl: nameCtrl, hint: 'ur name', label: 'NAME'),
              const SizedBox(height: 10),
              _ProfileField(
                  ctrl: handleCtrl, hint: '@handle', label: 'HANDLE'),
              const SizedBox(height: 10),
              _ProfileField(ctrl: cityCtrl, hint: 'ur city', label: 'CITY'),
              const SizedBox(height: 18),
              GestureDetector(
                onTap: () async {
                  final name = nameCtrl.text.trim();
                  final rawHandle = handleCtrl.text.trim();
                  final handle = rawHandle.startsWith('@')
                      ? rawHandle.substring(1)
                      : rawHandle;
                  final city = cityCtrl.text.trim();
                  await ref.read(sessionRepositoryProvider).updateProfile(
                        displayName: name.isNotEmpty ? name : null,
                        handle: handle.isNotEmpty ? handle : null,
                        city: city.isNotEmpty ? city : null,
                      );
                  ref.invalidate(_currentProfileProvider);
                  if (context.mounted) Navigator.of(context).pop();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    color: TromblColors.jomo,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text('save →',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Color(0xFF0B0B0D),
                          fontWeight: FontWeight.w800,
                          fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ProfileField extends StatelessWidget {
  const _ProfileField(
      {required this.ctrl, required this.hint, required this.label});
  final TextEditingController ctrl;
  final String hint;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: TromblColors.textMuted,
                fontSize: 9,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          style: const TextStyle(color: TromblColors.text, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: TromblColors.textMuted),
            filled: true,
            fillColor: TromblColors.card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
}

// ─── Profile screen — "trom's read on u" ───────────────────────────────────
//
// The screen's one job: prove trom knows the user. A warm, specific,
// friend-voiced reflection — not a dashboard, not a stats page, not a
// memory list. Copy is templated from real data (see troms_read.dart),
// never a live AI call.

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readData = ref.watch(_tromsReadDataProvider);
    final myPlans = ref.watch(myPlansProvider);
    final uid = ref.watch(supabaseProvider).auth.currentUser?.id;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 22, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Nav row ────────────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () => context.go('/home'),
                          child: const Text('← home',
                              style: TextStyle(color: TromblColors.textSub)),
                        ),
                        ref.watch(_currentProfileProvider).maybeWhen(
                              data: (profile) => GestureDetector(
                                onTap: () =>
                                    _showEditProfile(context, ref, profile),
                                child: const Text('edit →',
                                    style: TextStyle(
                                        color: TromblColors.textMuted,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                              ),
                              orElse: () => const SizedBox.shrink(),
                            ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    const Text(
                      "trom's read on u",
                      style: TextStyle(
                        fontFamily: TromblText.serif,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: TromblColors.text,
                      ),
                    ),

                    const SizedBox(height: 18),

                    // ── Section 1: trom's read ──────────────────────────────
                    readData.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const Text(
                        "we just met. trom's still figuring u out.\n"
                        "pick something and come back —\n"
                        "that's when it gets interesting.",
                        style: _readStyle,
                      ),
                      data: (d) => Text(
                        buildTromsRead(
                          sessionCount: d.sessionCount,
                          pickCount: d.pickCount,
                          sessions: d.sessions,
                          picks: d.picks,
                          memoryNodes: d.memoryNodes,
                        ),
                        style: _readStyle,
                      ),
                    ),

                    // ── Remaining sections — hidden in the true empty state ──
                    readData.maybeWhen(
                      data: (d) {
                        if (d.sessionCount == 0) return const SizedBox.shrink();
                        final clocked = buildWhatTromClocked(
                          sessions: d.sessions,
                          picks: d.picks,
                          memoryNodes: d.memoryNodes,
                        );
                        final didPicks = dedupedAcceptedPicks(d.picks);
                        final plans = dedupedPlans(
                            myPlans.valueOrNull ?? const <Plan>[]);

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (clocked.isNotEmpty) ...[
                              const SizedBox(height: 26),
                              const Text('what trom clocked',
                                  style: _labelStyle),
                              const SizedBox(height: 10),
                              ...clocked.map((l) => Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Text(l,
                                        style: const TextStyle(
                                          color: TromblColors.textSub,
                                          fontSize: 13,
                                          fontFamily: TromblText.sans,
                                        )),
                                  )),
                            ],
                            if (didPicks.isNotEmpty) ...[
                              const SizedBox(height: 22),
                              const Text('what u actually did',
                                  style: _labelStyle),
                              const SizedBox(height: 10),
                              ...didPicks.map((p) => Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Text('"${p.pickText}"',
                                        style: const TextStyle(
                                          color: TromblColors.textMuted,
                                          fontSize: 12,
                                          fontFamily: TromblText.sans,
                                        )),
                                  )),
                            ],
                            if (plans.isNotEmpty) ...[
                              const SizedBox(height: 22),
                              const Text('my plans', style: _labelStyle),
                              const SizedBox(height: 10),
                              ...plans.map((p) => _PlanRow(
                                    plan: p,
                                    label: p.ownerId == uid ? 'ur plan' : 'joined',
                                  )),
                            ],
                          ],
                        );
                      },
                      orElse: () => const SizedBox.shrink(),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // ── Footer ────────────────────────────────────────────────────
            const _AppVersion(),
            GestureDetector(
              onTap: () async {
                await ref.read(supabaseProvider).auth.signOut();
                ref.read(activeSessionProvider.notifier).clear();
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                color: Colors.transparent,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '↺  start over',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFE05252),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                        decorationColor: Color(0xFFE05252),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

const _readStyle = TextStyle(
  fontFamily: TromblText.serif,
  fontSize: 17,
  fontWeight: FontWeight.w500,
  color: TromblColors.text,
  height: 1.45,
);

const _labelStyle = TextStyle(
  color: TromblColors.textMuted,
  fontSize: 10,
  letterSpacing: 2,
  fontWeight: FontWeight.w700,
);

// ─── Plan row ─────────────────────────────────────────────────────────────────

class _PlanRow extends StatelessWidget {
  const _PlanRow({required this.plan, required this.label});
  final Plan plan;
  final String label;

  @override
  Widget build(BuildContext context) {
    final accent = TromblColors.accentFor(plan.vibe);
    return GestureDetector(
      onTap: () => context.push('/plan/${plan.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: TromblColors.card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Text(plan.vibe == 'fomo' ? '⚡' : '🛌',
                style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.title,
                    style: const TextStyle(
                        color: TromblColors.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    label,
                    style: const TextStyle(
                        color: TromblColors.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            Text('→', style: TextStyle(color: accent, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

// ─── App version ──────────────────────────────────────────────────────────────

class _AppVersion extends StatefulWidget {
  const _AppVersion();

  @override
  State<_AppVersion> createState() => _AppVersionState();
}

class _AppVersionState extends State<_AppVersion> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = 'v${info.version}+${info.buildNumber}');
    });
  }

  @override
  Widget build(BuildContext context) => _version.isEmpty
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            _version,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: TromblColors.textMuted,
              fontSize: 11,
              fontFamily: TromblText.sans,
            ),
          ),
        );
}
