import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/trombl_theme.dart';
import '../../../shared/result.dart';
import '../providers/plan_providers.dart';

class JoinPlanScreen extends ConsumerStatefulWidget {
  const JoinPlanScreen({super.key, this.initialToken});
  final String? initialToken;

  @override
  ConsumerState<JoinPlanScreen> createState() => _JoinPlanScreenState();
}

class _JoinPlanScreenState extends ConsumerState<JoinPlanScreen> {
  late final TextEditingController _ctrl;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialToken ?? '');
    if (widget.initialToken != null && widget.initialToken!.isNotEmpty) {
      Future.microtask(_join);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final token = _ctrl.text.trim();
    if (token.isEmpty) return;

    setState(() { _loading = true; _error = null; });

    final result = await ref.read(planRepositoryProvider).getByToken(token);

    if (!mounted) return;
    setState(() => _loading = false);

    switch (result) {
      case Success(:final data):
        // Auto-join with "maybe" then navigate to detail
        await ref.read(planRepositoryProvider).joinOrUpdate(data.id, 'maybe');
        if (!mounted) return;
        ref.invalidate(myPlansProvider);
        context.go('/plan/${data.id}');
      case Failure(:final error):
        setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              24, 14, 24, MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () =>
                    context.canPop() ? context.pop() : context.go('/menu'),
                child: const Text('← back',
                    style: TextStyle(
                        color: TromblColors.textMuted, fontSize: 13)),
              ),
              const Spacer(),
              const Text(
                'join a plan',
                style: TextStyle(
                  fontFamily: TromblText.serif,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: TromblColors.text,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'paste the code someone sent you.',
                style:
                    TextStyle(color: TromblColors.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _ctrl,
                autofocus: true,
                textCapitalization: TextCapitalization.none,
                style: const TextStyle(
                  color: TromblColors.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                ),
                decoration: InputDecoration(
                  hintText: 'enter code',
                  hintStyle: const TextStyle(
                      color: TromblColors.textMuted,
                      fontSize: 20,
                      letterSpacing: 2),
                  filled: true,
                  fillColor: TromblColors.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 18),
                ),
                onSubmitted: (_) => _join(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!,
                    style: const TextStyle(
                        color: Colors.redAccent, fontSize: 13)),
              ],
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _loading ? null : _join,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color:
                        _loading ? TromblColors.card : TromblColors.jomo,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    _loading ? 'finding it...' : 'join →',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _loading
                          ? TromblColors.textSub
                          : const Color(0xFF0B0B0D),
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
