import 'package:flutter/material.dart';

import '../../../../core/theme/trombl_theme.dart';

class AppleSignInButton extends StatelessWidget {
  const AppleSignInButton({
    super.key,
    required this.onTap,
    required this.loading,
  });

  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: TromblColors.borderMid),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
              )
            else
              const Text('', style: TextStyle(fontSize: 18, color: Colors.white)),
            const SizedBox(width: 10),
            Text(
              loading ? 'signing in…' : 'continue with apple',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                fontFamily: TromblText.sans,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
