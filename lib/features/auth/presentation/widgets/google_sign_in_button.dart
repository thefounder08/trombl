import 'package:flutter/material.dart';

import '../../../../core/theme/trombl_theme.dart';

class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black54),
              )
            else
              const Text('G', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(width: 10),
            Text(
              loading ? 'signing in…' : 'continue with google',
              style: const TextStyle(
                color: Colors.black87,
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
