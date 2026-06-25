import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/prefs_service.dart';

const _bg2 = Color(0xFF111827);
const _border = Color(0xFF1e2130);
const _cyan = Color(0xFF00d4d4);
const _textPrimary = Color(0xFFcbd5e1);
const _textMuted = Color(0xFFcbd5e1);

class BrowseCardWidget extends StatefulWidget {
  final AnilistMedia media;
  final VoidCallback onTap;
  const BrowseCardWidget({super.key, required this.media, required this.onTap});

  @override
  State<BrowseCardWidget> createState() => _BrowseCardWidgetState();
}

class _BrowseCardWidgetState extends State<BrowseCardWidget> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<PrefsService>();
    final compact = prefs.compactCards;
    final cardW = compact ? 96.0 : 128.0;
    final cardH = compact ? 134.0 : 180.0;

    final score = prefs.showScoreBadge && widget.media.averageScore != null
        ? '★ ${(widget.media.averageScore! / 10).toStringAsFixed(1)}'
        : null;
    final eps = prefs.showEpisodeCount
        ? (widget.media.episodes != null
            ? '${widget.media.episodes} EP'
            : widget.media.status == 'RELEASING'
                ? 'AIRING'
                : null)
        : null;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: SizedBox(
          width: cardW,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                transform: Matrix4.identity()..scale(_hovered ? 1.04 : 1.0),
                transformAlignment: Alignment.center,
                child: Container(
                  width: cardW,
                  height: cardH,
                  decoration: BoxDecoration(
                    color: _bg2,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _hovered ? _cyan : _border),
                  ),
                  child: Stack(
                    children: [
                      if (widget.media.coverImage != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(
                            widget.media.coverImage!,
                            width: cardW, height: cardH,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const SizedBox(),
                          ),
                        ),
                      if (score != null)
                        Positioned(
                          top: 7, right: 7,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xE50a0b0f),
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(color: _cyan.withOpacity(0.4)),
                            ),
                            child: Text(score, style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 10, color: _cyan,
                            )),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.media.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: compact ? 11 : 12,
                  fontWeight: FontWeight.w500,
                  color: _textPrimary,
                  height: 1.35,
                ),
              ),
              if (eps != null) ...[
                const SizedBox(height: 3),
                Text(eps, style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: _textMuted)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
