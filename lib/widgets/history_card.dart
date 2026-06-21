import 'package:flutter/material.dart';
import '../models/models.dart';

const _bg2 = Color(0xFF0f1117);
const _bg3 = Color(0xFF151720);
const _border = Color(0xFF1e2130);
const _cyan = Color(0xFF00d4d4);
const _textDim = Color(0xFF5a6080);

class HistoryCardWidget extends StatelessWidget {
  final HistoryEntry entry;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const HistoryCardWidget({
    super.key,
    required this.entry,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 220,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: _bg2,
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(entry.name, style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFFc8ccd8),
                  ), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text('EP ${entry.episode.toInt()} // ${entry.lang.toUpperCase()}',
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: _cyan)),
                  Text(entry.provider.toUpperCase(),
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 9, color: _textDim)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Text('▶', style: TextStyle(color: _cyan, fontSize: 16)),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onRemove,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Text('✕', style: TextStyle(color: _textDim, fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
