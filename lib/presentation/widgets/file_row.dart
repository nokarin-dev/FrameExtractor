import 'package:flutter/material.dart';
import 'package:frameextractor/presentation/theme/app_theme.dart';

class FileRow extends StatefulWidget {
  final AppColors c;
  final IconData icon;
  final String label, placeholder;
  final String? value;
  final Color accent;
  final bool disabled, isGlass, isDark;
  final VoidCallback? onTap;
  const FileRow({
    super.key,
    required this.c,
    required this.icon,
    required this.label,
    required this.value,
    required this.placeholder,
    required this.accent,
    required this.isGlass,
    required this.isDark,
    this.disabled = false,
    this.onTap,
  });

  @override
  State<FileRow> createState() => _FileRowState();
}

class _FileRowState extends State<FileRow> {
  bool _hov = false;

  @override
  Widget build(BuildContext context) {
    final hasValue = widget.value != null && widget.value!.isNotEmpty;
    final name = hasValue
        ? widget.value!.split('/').last.split('\\').last
        : widget.placeholder;
    final eff = widget.disabled ? widget.c.textMuted : widget.accent;

    return Tooltip(
      message: hasValue ? widget.value! : '',
      waitDuration: const Duration(milliseconds: 600),
      child: MouseRegion(
        cursor: widget.disabled
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hov = true),
        onExit: (_) => setState(() => _hov = false),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              color: (!widget.disabled && _hov)
                  ? (widget.isGlass
                        ? Colors.white.withValues(
                            alpha: widget.isDark ? 0.06 : 0.18,
                          )
                        : widget.c.borderHi.withValues(alpha: 0.5))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: eff.withValues(
                        alpha: widget.disabled ? 0.05 : 0.14,
                      ),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(widget.icon, color: eff, size: 17),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.label,
                          style: TextStyle(
                            color: widget.isGlass
                                ? (widget.isDark
                                      ? Colors.white.withValues(alpha: 0.38)
                                      : widget.c.textSec)
                                : widget.c.textSec,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: hasValue
                                ? (widget.isGlass
                                      ? (widget.isDark
                                            ? Colors.white.withValues(
                                                alpha: 0.88,
                                              )
                                            : widget.c.textPri)
                                      : widget.c.textPri)
                                : (widget.isGlass
                                      ? (widget.isDark
                                            ? Colors.white.withValues(
                                                alpha: 0.28,
                                              )
                                            : widget.c.textMuted)
                                      : widget.c.textMuted),
                            fontSize: 13,
                            fontWeight: hasValue
                                ? FontWeight.w500
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    hasValue
                        ? Icons.check_circle_rounded
                        : Icons.add_circle_outline_rounded,
                    color: hasValue
                        ? eff
                        : (widget.isGlass
                              ? (widget.isDark
                                    ? Colors.white.withValues(alpha: 0.20)
                                    : widget.c.textMuted)
                              : widget.c.textMuted),
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
