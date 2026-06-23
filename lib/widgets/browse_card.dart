import 'package:flutter/material.dart';
import '../models/models.dart';

const _bg2 = Color(0xFF111827);
const _border = Color(0xFF1e2130);
const _cyan = Color(0xFF00d4d4);
const _textPrimary = Color(0xFFcbd5e1);
const _textMuted = Color(0xFF475569);

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
    final score = widget.media.averageScore != null
        ? '★ ${(widget.media.averageScore! / 10).toStringAsFixed(1)}'
        : null;
    final eps = widget.media.episodes != null
        ? '${widget.media.episodes} EP'
        : (widget.media.status == 'RELEASING' ? 'AIRING' : '');

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: SizedBox(
          width: 128,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                transform: Matrix4.identity()..scale(_hovered ? 1.04 : 1.0),
                transformAlignment: Alignment.center,
                child: Container(
                  width: 128,
                  height: 180,
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
                            width: 128, height: 180,
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
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _textPrimary, height: 1.35),
              ),
              if (eps.isNotEmpty)
                const SizedBox(height: 3),
              if (eps.isNotEmpty)
                Text(eps, style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: _textMuted)),
            ],
          ),
        ),
      ),
    );
  }
}
