import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:frameextractor/core/app_prefs.dart';
import 'package:frameextractor/presentation/theme/app_theme.dart';
import 'package:frameextractor/presentation/widgets/app_card.dart';
import 'package:frameextractor/presentation/widgets/app_divider.dart';
import 'package:frameextractor/presentation/widgets/clear_row.dart';
import 'package:frameextractor/presentation/widgets/file_row.dart';

class OutputSection extends StatelessWidget {
  final String? outputDirectory;
  final bool disabled;
  final ValueChanged<String> onDirectorySelected;
  final VoidCallback onClear;

  const OutputSection({
    super.key,
    required this.outputDirectory,
    required this.disabled,
    required this.onDirectorySelected,
    required this.onClear,
  });

  Future<void> _pick(BuildContext context) async {
    final r = await FilePicker.getDirectoryPath();
    if (r != null) {
      await AppPrefs.setLastOutputDir(r);
      onDirectorySelected(r);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final c = theme.colors;
    final isGlass = theme.isGlass;

    return AppCard(
      theme: theme,
      label: 'OUTPUT',
      child: Column(
        children: [
          FileRow(
            c: c,
            icon: Icons.folder_rounded,
            label: 'Output Folder',
            value: outputDirectory,
            placeholder: 'Select output directory…',
            accent: c.purple,
            disabled: disabled,
            onTap: disabled ? null : () => _pick(context),
            isGlass: isGlass,
            isDark: theme.isDark,
          ),
          if (outputDirectory != null) ...[
            AppDivider(c: c, isGlass: isGlass, isDark: theme.isDark),
            ClearRow(
              c: c,
              disabled: disabled,
              isGlass: isGlass,
              onTap: onClear,
            ),
          ],
        ],
      ),
    );
  }
}
