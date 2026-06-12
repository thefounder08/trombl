import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/trombl_theme.dart';
import 'chat_args.dart';

/// Minimal chat screen — shows [ChatArgs.seedText] as Trombl's opening message.
/// The user can type a reply; full AI response flow is a future milestone.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.args});
  final ChatArgs args;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<_Message> _messages = [];
  bool _hasTyped = false;

  @override
  void initState() {
    super.initState();
    _messages.add(_Message(text: widget.args.seedText, isTrom: true));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _send() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      _messages.add(_Message(text: text, isTrom: false));
      _hasTyped = true;
    });
    _ctrl.clear();
    // Scroll to bottom after frame renders.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TromblColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      context.go('/home');
                    },
                    child: const Text(
                      '← back',
                      style: TextStyle(
                        color: TromblColors.textSub,
                        fontSize: 13,
                        fontFamily: TromblText.sans,
                      ),
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'trom',
                    style: TextStyle(
                      color: TromblColors.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      fontFamily: TromblText.sans,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 40), // balance back button
                ],
              ),
            ),
            const Divider(color: TromblColors.border, height: 1),

            // ── Message list ─────────────────────────────────────────────────
            Expanded(
              child: ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                itemCount: _messages.length +
                    (_hasTyped ? 1 : 0), // +1 for "more soon" notice
                itemBuilder: (_, i) {
                  if (i == _messages.length) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: Center(
                        child: Text(
                          'full chat coming soon.',
                          style: TextStyle(
                            color: TromblColors.textMuted,
                            fontSize: 12,
                            fontFamily: TromblText.sans,
                          ),
                        ),
                      ),
                    );
                  }
                  return _Bubble(message: _messages[i]);
                },
              ),
            ),

            // ── Input ────────────────────────────────────────────────────────
            Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: TromblColors.border)),
              ),
              padding: EdgeInsets.fromLTRB(
                16,
                10,
                16,
                MediaQuery.of(context).viewInsets.bottom + 14,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      style: const TextStyle(
                        color: TromblColors.text,
                        fontSize: 14,
                        fontFamily: TromblText.sans,
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'tell trom…',
                        hintStyle: const TextStyle(
                          color: TromblColors.textMuted,
                          fontSize: 14,
                          fontFamily: TromblText.sans,
                        ),
                        filled: true,
                        fillColor: TromblColors.card,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _send,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: TromblColors.fomo,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.arrow_upward_rounded,
                        color: Color(0xFF0B0B0D),
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Data ─────────────────────────────────────────────────────────────────────

class _Message {
  const _Message({required this.text, required this.isTrom});
  final String text;
  final bool isTrom;
}

// ─── Bubble ───────────────────────────────────────────────────────────────────

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});
  final _Message message;

  @override
  Widget build(BuildContext context) {
    final isTrom = message.isTrom;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isTrom ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isTrom ? TromblColors.card : TromblColors.fomo,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isTrom ? 4 : 18),
                  bottomRight: Radius.circular(isTrom ? 18 : 4),
                ),
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: isTrom
                      ? TromblColors.text
                      : const Color(0xFF0B0B0D),
                  fontSize: 14,
                  fontFamily: TromblText.sans,
                  height: 1.45,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
