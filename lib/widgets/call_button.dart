import 'package:flutter/material.dart';

class CallButton extends StatelessWidget {
  final IconData icon;
  final Color backgroundColor;
  final VoidCallback onTap;
  final double size;

  const CallButton({
    super.key,
    required this.icon,
    required this.backgroundColor,
    required this.onTap,
    this.size = 58,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(size / 2),
      onTap: onTap,
      child: Container(
        height: size,
        width: size,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: size == 70 ? 34 : 28,
        ),
      ),
    );
  }
}