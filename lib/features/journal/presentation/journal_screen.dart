import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/trombl_theme.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TromblColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              // Copy at top
              const Text(
                "don't edit as you go. just write.",
                style: TextStyle(
                  color: TromblColors.textMuted,
                  fontSize: 13,
                  fontFamily: TromblText.sans,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 20),

              // Full-screen text area
              Expanded(
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  maxLines: null,
                  expands: true,
                  keyboardType: TextInputType.multiline,
                  textAlignVertical: TextAlignVertical.top,
                  style: const TextStyle(
                    color: TromblColors.text,
                    fontSize: 17,
                    fontFamily: TromblText.sans,
                    height: 1.6,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'start anywhere…',
                    hintStyle: TextStyle(
                      color: TromblColors.textMuted,
                      fontSize: 17,
                      fontFamily: TromblText.sans,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),

              // Done button
              Padding(
                padding: const EdgeInsets.only(bottom: 24, top: 12),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    context.go('/home');
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: TromblColors.jomo,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'done',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF090909),
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        fontFamily: TromblText.sans,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
