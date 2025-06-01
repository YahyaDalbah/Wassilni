import 'package:flutter/material.dart';

class VerificationAppBar extends StatelessWidget implements PreferredSizeWidget {
  const VerificationAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text(
        "Phone Verification",
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      backgroundColor: Colors.black,
      centerTitle: true,
      elevation: 2.6,
      shadowColor: Colors.white,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}