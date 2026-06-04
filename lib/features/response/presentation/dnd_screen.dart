import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/trombl_theme.dart';

/// Full-screen "trom handled it" shown when the user picks a rest-tagged option.
class DndScreen extends StatelessWidget {
  const DndScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TromblColors.bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '🛌',
                  style: TextStyle(fontSize: 56),
                ),
                const SizedBox(height: 28),
                const Text(
                  'trom handled it.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: TromblText.serif,
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: TromblColors.jomo,
                    height: 1.2,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'ur off the grid.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: TromblText.sans,
                    fontSize: 16,
                    color: TromblColors.textSub,
                  ),
                ),
                const SizedBox(height: 56),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.go('/home');
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: TromblColors.jomo.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: const Text(
                      'back when ur ready',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: TromblText.sans,
                        color: TromblColors.jomo,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
