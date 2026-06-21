import 'package:flutter/material.dart';
import '../models/models.dart';

const _bg2 = Color(0xFF0f1117);
const _bg3 = Color(0xFF151720);
const _border = Color(0xFF1e2130);
const _cyan = Color(0xFF00d4d4);
const _textDim = Color(0xFF5a6080);

class AnimeCardWidget extends StatelessWidget {
  final AnimeResult anime;
  final VoidCallback onTap;

  const AnimeCardWidget({super.key, required this.anime, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _bg2,
          border: Border.all(color: _border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(anime.name, style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFFc8ccd8),
            ), maxLines: 3, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            Text(anime.id, style: const TextStyle(
              fontFamily: 'monospace', fontSize: 10, color: _textDim,
            ), overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
