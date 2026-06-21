import 'package:flutter/material.dart';
import '../models/models.dart';

const _bg3 = Color(0xFF151720);
const _textDim = Color(0xFF5a6080);
const _cyan = Color(0xFF00d4d4);

class BrowseCardWidget extends StatelessWidget {
  final AnilistMedia media;
  final VoidCallback onTap;

  const BrowseCardWidget({super.key, required this.media, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final score = media.averageScore != null
        ? '★ ${(media.averageScore! / 10).toStringAsFixed(1)}'
        : null;
    final eps = media.episodes != null
        ? '${media.episodes} EP'
        : (media.status == 'RELEASING' ? 'AIRING' : '');

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 130,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: media.coverImage != null
                  ? Image.network(
                      media.coverImage!,
                      width: 130,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(),
                    )
                  : _placeholder(),
            ),
            const SizedBox(height: 6),
            Text(
              media.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Color(0xFFc8ccd8), height: 1.3),
            ),
            if (eps.isNotEmpty)
              Text(eps, style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: _textDim)),
            if (score != null)
              Text(score, style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: _cyan)),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
    width: 130,
    color: _bg3,
    child: const Center(child: Text('NO IMG', style: TextStyle(
      fontFamily: 'monospace', fontSize: 10, color: _textDim,
    ))),
  );
}
