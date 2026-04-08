import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frameextractor/core/app_prefs.dart';
import 'package:frameextractor/data/models/extraction_record.dart';
import 'package:frameextractor/presentation/theme/app_theme.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<ExtractionRecord> _records = [];

  @override
  void initState() {
    super.initState();
    _records = AppPrefs.history;
  }

  Future<void> _clearAll() async {
    await AppPrefs.clearHistory();
    setState(() => _records = []);
  }

  void _openFolder(String path) {
    if (Platform.isWindows) {
      Process.run('explorer', [path]);
    } else if (!Platform.isAndroid && !Platform.isIOS) {
      Process.run('xdg-open', [path]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final c = theme.colors;
    final isGlass = theme.isGlass;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.surface,
        elevation: 0,
        title: Text(
          'Extraction History',
          style: TextStyle(
            color: c.textPri,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: c.textSec),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_records.isNotEmpty)
            TextButton.icon(
              onPressed: () => _showClearDialog(context),
              icon: Icon(Icons.delete_sweep_rounded, size: 16),
              label: const Text('Clear all'),
              style: TextButton.styleFrom(foregroundColor: c.red),
            ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: c.border),
        ),
      ),
      body: _records.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history_rounded, color: c.textMuted, size: 40),
                  const SizedBox(height: 12),
                  Text(
                    'No extractions yet.',
                    style: TextStyle(color: c.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Completed extractions will appear here.',
                    style: TextStyle(color: c.textMuted, fontSize: 11),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              itemCount: _records.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _RecordTile(
                record: _records[i],
                theme: theme,
                onOpenFolder: () => _openFolder(_records[i].outputDirectory),
              ),
            ),
    );
  }

  Future<void> _showClearDialog(BuildContext context) async {
    final theme = AppTheme.of(context);
    final c = theme.colors;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: theme.isDark ? 0.55 : 0.30),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 80),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 340),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.isGlass
                ? c.surface.withValues(alpha: theme.isDark ? 0.30 : 0.82)
                : c.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.isGlass
                  ? (theme.isDark
                        ? Colors.white.withValues(alpha: 0.20)
                        : c.borderHi)
                  : c.border,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: theme.isDark ? 0.45 : 0.12,
                ),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Clear history?',
                style: TextStyle(
                  color: c.textPri,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This will permanently remove all extraction records.',
                style: TextStyle(color: c.textSec, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        decoration: BoxDecoration(
                          color: c.surfaceHi,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: c.border),
                        ),
                        child: Center(
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: c.textSec,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        decoration: BoxDecoration(
                          color: c.red.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: c.red.withValues(alpha: 0.50),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'Clear',
                            style: TextStyle(
                              color: c.red,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed == true) _clearAll();
  }
}

class _RecordTile extends StatelessWidget {
  final ExtractionRecord record;
  final AppTheme theme;
  final VoidCallback onOpenFolder;
  const _RecordTile({
    required this.record,
    required this.theme,
    required this.onOpenFolder,
  });

  String _fmtDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  String _fmtElapsed(Duration d) {
    if (d.inMinutes > 0) return '${d.inMinutes}m ${d.inSeconds % 60}s';
    return '${d.inSeconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final c = theme.colors;
    final isGlass = theme.isGlass;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isGlass
            ? (theme.isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : c.surface.withValues(alpha: 0.65))
            : c.surfaceHi,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isGlass
              ? (theme.isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : c.borderHi.withValues(alpha: 0.60))
              : c.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Video name & date
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: c.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.movie_rounded, color: c.accent, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.videoName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.textPri,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _fmtDate(record.completedAt),
                      style: TextStyle(color: c.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Stats row
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _Stat(
                c: c,
                icon: Icons.image_outlined,
                label: '${record.frameCount} frames',
              ),
              _Stat(
                c: c,
                icon: Icons.timer_outlined,
                label: _fmtElapsed(record.elapsed),
              ),
              _Stat(
                c: c,
                icon: Icons.speed_rounded,
                label: '${record.fps} fps',
              ),
              _Stat(
                c: c,
                icon: Icons.image_rounded,
                label: record.format.toUpperCase(),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Output path & actions
          Row(
            children: [
              Expanded(
                child: Text(
                  record.outputDirectory,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.textMuted,
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _ActionBtn(
                c: c,
                icon: Icons.copy_rounded,
                tooltip: 'Copy path',
                onTap: () => Clipboard.setData(
                  ClipboardData(text: record.outputDirectory),
                ),
              ),
              const SizedBox(width: 6),
              _ActionBtn(
                c: c,
                icon: Icons.folder_open_rounded,
                tooltip: 'Open folder',
                onTap: onOpenFolder,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final AppColors c;
  final IconData icon;
  final String label;
  const _Stat({required this.c, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 11, color: c.textMuted),
      const SizedBox(width: 3),
      Text(label, style: TextStyle(color: c.textSec, fontSize: 11)),
    ],
  );
}

class _ActionBtn extends StatelessWidget {
  final AppColors c;
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _ActionBtn({
    required this.c,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: c.surfaceHi,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: c.border),
          ),
          child: Icon(icon, size: 14, color: c.textSec),
        ),
      ),
    ),
  );
}
