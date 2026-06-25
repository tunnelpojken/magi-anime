import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/prefs_service.dart';

const _bg =        Color(0xFF080c18);
const _bg2 =       Color(0xFF0d1220);
const _border =    Color(0xFF151d30);
const _cyan =      Color(0xFF00d4d4);
const _orange =    Color(0xFFf97316);
const _textPrimary =   Color(0xFFf1f5f9);
const _textSecondary = Color(0xFF94a3b8);

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
    final cardW = compact ? 100.0 : 130.0;
    final cardH = compact ? 140.0 : 186.0;

    final score = prefs.showScoreBadge && widget.media.averageScore != null
        ? '★ ${(widget.media.averageScore! / 10).toStringAsFixed(1)}'
        : null;
    final eps = prefs.showEpisodeCount
        ? (widget.media.episodes != null
            ? '${widget.media.episodes} EP'
            : widget.media.status == 'RELEASING' ? 'AIRING' : null)
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
              // Card image with angular clip
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                transform: Matrix4.identity()..scale(_hovered ? 1.03 : 1.0),
                transformAlignment: Alignment.center,
                child: ClipPath(
                  clipper: _CardClipper(),
                  child: Container(
                    width: cardW, height: cardH,
                    color: _bg2,
                    child: Stack(children: [
                      if (widget.media.coverImage != null)
                        Image.network(
                          widget.media.coverImage!,
                          width: cardW, height: cardH,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox(),
                        ),
                      // Gradient bottom
                      Positioned(
                        bottom: 0, left: 0, right: 0, height: 50,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, _bg.withOpacity(0.85)],
                            ),
                          ),
                        ),
                      ),
                      // Score badge
                      if (score != null)
                        Positioned(
                          top: 0, right: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            color: _bg.withOpacity(0.88),
                            child: Text(score, style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 9, color: _cyan,
                            )),
                          ),
                        ),
                      // Hover cyan border overlay
                      if (_hovered)
                        Positioned.fill(child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: _cyan.withOpacity(0.4), width: 1.5),
                          ),
                        )),
                      // Bottom-left corner accent
                      Positioned(
                        bottom: 0, left: 0,
                        child: Container(width: 16, height: 16,
                          decoration: BoxDecoration(border: Border(
                            bottom: BorderSide(color: _cyan.withOpacity(0.6), width: 2),
                            left: BorderSide(color: _cyan.withOpacity(0.6), width: 2),
                          ))),
                      ),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              // Title
              Text(
                widget.media.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: compact ? 10 : 11,
                  fontWeight: FontWeight.w600,
                  color: _textPrimary,
                  height: 1.3,
                ),
              ),
              if (eps != null) ...[
                const SizedBox(height: 2),
                Text(eps, style: const TextStyle(
                  fontFamily: 'monospace', fontSize: 9, color: _textSecondary,
                )),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// Diagonal top-right clip
class _CardClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size s) {
    const cut = 12.0;
    final p = Path();
    p.moveTo(0, 0);
    p.lineTo(s.width - cut, 0);
    p.lineTo(s.width, cut);
    p.lineTo(s.width, s.height);
    p.lineTo(0, s.height);
    p.close();
    return p;
  }
  @override bool shouldReclip(_) => false;
}
