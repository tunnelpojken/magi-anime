import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/history_service.dart';

const _bg2 = Color(0xFF111827);
const _border = Color(0xFF1e2130);
const _cyan = Color(0xFF00d4d4);
const _textPrimary = Color(0xFFe2e8f0);
const _textMuted = Color(0xFF475569);

class HistoryCardWidget extends StatefulWidget {
  final HistoryEntry entry;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  const HistoryCardWidget({super.key, required this.entry, required this.onTap, required this.onRemove});

  @override
  State<HistoryCardWidget> createState() => _HistoryCardWidgetState();
}

class _HistoryCardWidgetState extends State<HistoryCardWidget> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    const totalSecs = 24 * 60;
    final progress = widget.entry.progress != null
        ? (widget.entry.progress!.inSeconds / totalSecs).clamp(0.0, 1.0)
        : 0.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 240,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _bg2,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _hovered ? _cyan : _border),
          ),
          child: Row(
            children: [
              Container(
                width: 40, height: 56,
                decoration: BoxDecoration(
                  color: _border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(widget.entry.name, style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500, color: _textPrimary,
                      overflow: TextOverflow.ellipsis,
                    ), maxLines: 1),
                    Text(
                      'EP ${widget.entry.episode.toInt()} · ${widget.entry.lang.toUpperCase()}',
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: _textMuted),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 3,
                        backgroundColor: _border,
                        valueColor: const AlwaysStoppedAnimation<Color>(_cyan),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: widget.onRemove,
                child: Icon(Icons.close, size: 14, color: _textMuted.withOpacity(0.5)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
