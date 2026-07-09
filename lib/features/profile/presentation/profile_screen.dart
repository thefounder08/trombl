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
import '../../../core/auth/auth_controller.dart';
import '../../auth/presentation/signup_bottom_sheet.dart';
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

final tromsReadDataProvider = FutureProvider.autoDispose<TromsReadData>((ref) async {
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

/// Guests (anonymous sessions) have no email/password backing their
/// account — signing out discards that identity permanently along with
/// every session/pick/plan written under it. Real "sign out" is harmless
/// for registered users, so this only intervenes for guests, steering them
/// to the upgrade flow (`/login`) instead of silently deleting their trial.
/// Returns true if the caller should proceed with sign-out.
Future<bool> _confirmSignOut(BuildContext context, WidgetRef ref) async {
  if (!ref.read(guestIdentityServiceProvider).isGuest) return true;

  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: TromblColors.card,
      title: const Text("you're not signed up yet",
          style: TextStyle(color: TromblColors.text, fontSize: 16)),
      content: const Text(
        "signing out as a guest deletes everything trom knows about u — "
        "ur picks, plans, and history. sign up first if u want to keep it.",
        style: TextStyle(color: TromblColors.textSub, fontSize: 13, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('cancel', style: TextStyle(color: TromblColors.textMuted)),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(ctx).pop(false);
            showSignupBottomSheet(context, surface: 'signout_dialog');
          },
          child: Text('sign up instead', style: TextStyle(color: TromblColors.fomo)),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('delete & sign out', style: TextStyle(color: Color(0xFFE05252))),
        ),
      ],
    ),
  );
  return result ?? false;
}

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
    if (!await _confirmSignOut(context, ref)) return;
    await ref.read(authControllerProvider.notifier).signOut();
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
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Center(
              child: Text(
                'what should trom know about u?',
                style: TextStyle(
                  color: TromblColors.textMuted,
                  fontSize: 13,
                  fontFamily: TromblText.sans,
                ),
              ),
            ),
            const SizedBox(height: 24),
            _SettingsField(
              fieldLabel: 'WHAT TROM CALLS U',
              value: widget.profile?.displayName,
              placeholder: 'tap to add',
              hint: "what should trom call u?",
              editing: _editing == 'name',
              controller: _nameCtrl,
              onTap: () =>
                  setState(() => _editing = _editing == 'name' ? null : 'name'),
              onSave: () => _save('name'),
            ),
            const SizedBox(height: 16),
            _SettingsField(
              fieldLabel: 'WHERE U ARE',
              value: widget.profile?.city,
              placeholder: 'tap to add',
              hint: 'ur city',
              editing: _editing == 'city',
              controller: _cityCtrl,
              onTap: () =>
                  setState(() => _editing = _editing == 'city' ? null : 'city'),
              onSave: () => _save('city'),
            ),
            const SizedBox(height: 24),
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

/// Tappable field row — collapses to a value display, expands inline into a
/// text field on tap. No separate screen/dialog.
class _SettingsField extends StatelessWidget {
  const _SettingsField({
    required this.fieldLabel,
    required this.value,
    required this.placeholder,
    required this.hint,
    required this.editing,
    required this.controller,
    required this.onTap,
    required this.onSave,
  });
  final String fieldLabel;
  final String? value;
  final String placeholder;
  final String hint;
  final bool editing;
  final TextEditingController controller;
  final VoidCallback onTap;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final trimmed = value?.trim();
    final hasValue = trimmed != null && trimmed.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          fieldLabel,
          style: const TextStyle(
            color: TromblColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        if (editing)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  autofocus: true,
                  onSubmitted: (_) => onSave(),
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
          )
        else
          GestureDetector(
            onTap: onTap,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: TromblColors.card,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    hasValue ? trimmed : placeholder,
                    style: TextStyle(
                      color: hasValue
                          ? TromblColors.text
                          : TromblColors.textMuted,
                      fontSize: 14,
                      fontWeight: hasValue ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  const Text('→', style: TextStyle(color: TromblColors.textMuted)),
                ],
              ),
            ),
          ),
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

// ─── Guest banner — shown only for anonymous (not-yet-signed-up) sessions ──

class _GuestBanner extends StatelessWidget {
  const _GuestBanner({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: TromblColors.fomo.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: TromblColors.fomo.withValues(alpha: 0.28)),
        ),
        child: Row(
          children: [
            const Text('⚠️', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                "ur browsing as a guest — sign up so u don't lose this.",
                style: TextStyle(
                  color: TromblColors.text,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text('save →',
                style: TextStyle(
                    color: TromblColors.fomo,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
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
    final readData = ref.watch(tromsReadDataProvider);
    final myPlans = ref.watch(myPlansProvider);
    final uid = ref.watch(supabaseProvider).auth.currentUser?.id;
    final isGuest = ref.watch(guestIdentityServiceProvider).isGuest;

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

                    if (isGuest) ...[
                      const SizedBox(height: 14),
                      _GuestBanner(onTap: () {
                        showSignupBottomSheet(context, surface: 'profile_banner');
                      }),
                    ],

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
                      error: (_, _) => const Text(
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
                            myPlans.value ?? const <Plan>[]);

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

                    const SizedBox(height: 22),
                    GestureDetector(
                      onTap: () => context.push('/history'),
                      child: const Text(
                        'ur wrapped days →',
                        style: TextStyle(
                          color: TromblColors.textMuted,
                          fontSize: 12,
                          fontFamily: TromblText.sans,
                        ),
                      ),
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
                if (!await _confirmSignOut(context, ref)) return;
                await ref.read(authControllerProvider.notifier).signOut();
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
