import 'package:flutter/material.dart';
import 'package:frameextractor/presentation/theme/app_theme.dart';

class ClearRow extends StatelessWidget {
  final AppColors c;
  final bool disabled, isGlass;
  final VoidCallback onTap;
  const ClearRow({
    super.key,
    required this.c,
    required this.disabled,
    required this.isGlass,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
    child: InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.delete_outline_rounded,
              size: 14,
              color: disabled ? c.textMuted : c.red.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 6),
            Text(
              'Clear',
              style: TextStyle(
                color: disabled ? c.textMuted : c.red.withValues(alpha: 0.7),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
