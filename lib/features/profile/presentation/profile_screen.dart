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

void _showSettingsSheet(BuildContext context, WidgetRef ref, Profile? profile) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _SettingsSheet(profile: profile),
  );
}

const _monthNames = [
  'january', 'february', 'march', 'april', 'may', 'june',
  'july', 'august', 'september', 'october', 'november', 'december',
];

String? _sinceLabel(DateTime? createdAt) {
  if (createdAt == null) return null;
  return 'using trombl since ${_monthNames[createdAt.month - 1]} ${createdAt.year}';
}

class _SettingsSheet extends ConsumerStatefulWidget {
  const _SettingsSheet({required this.profile});
  final Profile? profile;

  @override
  ConsumerState<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends ConsumerState<_SettingsSheet> {
  String? _editing; // 'name' | 'city' | null
  late final _nameCtrl =
      TextEditingController(text: widget.profile?.displayName ?? '');
  late final _cityCtrl =
      TextEditingController(text: widget.profile?.city ?? '');

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  Future<void> _save(String field) async {
    if (field == 'name') {
      await ref
          .read(sessionRepositoryProvider)
          .updateProfile(displayName: _nameCtrl.text.trim());
    } else {
      await ref
          .read(sessionRepositoryProvider)
          .updateProfile(city: _cityCtrl.text.trim());
    }
    ref.invalidate(_currentProfileProvider);
    if (mounted) setState(() => _editing = null);
  }

  Future<void> _signOut() async {
    await ref.read(supabaseProvider).auth.signOut();
    ref.read(activeSessionProvider.notifier).clear();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
            _SettingsRow(
              label: 'change name',
              hint: 'what should trom call u?',
              editing: _editing == 'name',
              controller: _nameCtrl,
              onTap: () =>
                  setState(() => _editing = _editing == 'name' ? null : 'name'),
              onSave: () => _save('name'),
            ),
            const SizedBox(height: 16),
            _SettingsRow(
              label: 'change city',
              hint: 'ur city',
              editing: _editing == 'city',
              controller: _cityCtrl,
              onTap: () =>
                  setState(() => _editing = _editing == 'city' ? null : 'city'),
              onSave: () => _save('city'),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _signOut,
              child: const Text(
                'sign out',
                style: TextStyle(
                  color: Color(0xFFE05252),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.label,
    required this.hint,
    required this.editing,
    required this.controller,
    required this.onTap,
    required this.onSave,
  });
  final String label;
  final String hint;
  final bool editing;
  final TextEditingController controller;
  final VoidCallback onTap;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: TromblColors.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
              Text(editing ? '↑' : '→',
                  style: const TextStyle(color: TromblColors.textMuted)),
            ],
          ),
        ),
        if (editing) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  autofocus: true,
                  style: const TextStyle(color: TromblColors.text, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: const TextStyle(color: TromblColors.textMuted),
                    filled: true,
                    fillColor: TromblColors.card,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onSave,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: TromblColors.jomo,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.check,
                      color: Color(0xFF0B0B0D), size: 18),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _IdentityRow extends StatelessWidget {
  const _IdentityRow({required this.profile, required this.onSettings});
  final Profile? profile;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final rawName = profile?.displayName?.trim();
    final name = (rawName != null && rawName.isNotEmpty) ? rawName : 'hey u';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final since = _sinceLabel(profile?.createdAt);

    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [TromblColors.fomo, Color(0xFFD99A00)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            initial,
            style: const TextStyle(
              color: Color(0xFF090909),
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  color: TromblColors.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  fontFamily: TromblText.sans,
                ),
              ),
              if (since != null) ...[
                const SizedBox(height: 2),
                Text(
                  since,
                  style: const TextStyle(
                    color: TromblColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
        GestureDetector(
          onTap: onSettings,
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Text('⚙️', style: TextStyle(fontSize: 18)),
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
                    GestureDetector(
                      onTap: () => context.go('/home'),
                      child: const Text('← home',
                          style: TextStyle(color: TromblColors.textSub)),
                    ),

                    const SizedBox(height: 18),

                    // ── Identity row ──────────────────────────────────────
                    ref.watch(_currentProfileProvider).maybeWhen(
                          data: (profile) => _IdentityRow(
                            profile: profile,
                            onSettings: () =>
                                _showSettingsSheet(context, ref, profile),
                          ),
                          orElse: () => const SizedBox.shrink(),
                        ),

                    const SizedBox(height: 22),

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
