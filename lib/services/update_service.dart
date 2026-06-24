import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

const _githubRepo = 'tunnelpojken/magi-anime';
const _cyan = Color(0xFF00d4d4);
const _bg2 = Color(0xFF0f1117);
const _textDim = Color(0xFF5a6080);
const _border = Color(0xFF1e2130);

// Reads version from pubspec.yaml automatically
Future<String> getMagiVersion() async {
  final info = await PackageInfo.fromPlatform();
  return info.version;
}


Future<String?> _findTerminal() async {
  final terminals = ['kitty', 'foot', 'alacritty', 'wezterm', 'xterm', 'gnome-terminal'];
  for (final term in terminals) {
    final result = await Process.run('which', [term]);
    if (result.exitCode == 0) return term;
  }
  return null;
}

class UpdateService {
  static Future<void> checkForUpdates(BuildContext context) async {
    try {
      final currentVersion = await getMagiVersion();

      final res = await http.get(
        Uri.parse('https://api.github.com/repos/$_githubRepo/releases/latest'),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) return;

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final latestTag = (data['tag_name'] as String).replaceAll('v', '');
      final releaseUrl = data['html_url'] as String;
      final assets = data['assets'] as List? ?? [];
      // Strip markdown from release notes
      final rawNotes = data['body'] as String? ?? '';
      final releaseNotes = rawNotes
          .replaceAll(RegExp(r'#{1,6}\s*'), '')
          .replaceAll(RegExp(r'\*\*|__'), '')
          .replaceAll(RegExp(r'\*|_'), '')
          .replaceAll(RegExp(r'`'), '')
          .trim();

      if (!_isNewer(latestTag, currentVersion)) return;
      if (!context.mounted) return;
      if (!context.mounted) return;

      if (Platform.isLinux) {
        final linuxAsset = assets.firstWhere(
          (a) => (a['name'] as String).contains('linux'),
          orElse: () => null,
        );
        final downloadUrl = linuxAsset?['browser_download_url'] as String?;
        _showLinuxUpdateDialog(context, latestTag, downloadUrl, currentVersion, releaseNotes);
      } else {
        _showNotifyDialog(context, latestTag, releaseUrl, currentVersion, releaseNotes);
      }
    } catch (_) {}
  }

  static bool _isNewer(String latest, String current) {
    final l = latest.split('.').map(int.parse).toList();
    final c = current.split('.').map(int.parse).toList();
    for (int i = 0; i < 3; i++) {
      final lv = i < l.length ? l[i] : 0;
      final cv = i < c.length ? c[i] : 0;
      if (lv > cv) return true;
      if (lv < cv) return false;
    }
    return false;
  }

  static void _showNotifyDialog(BuildContext context, String version, String url, String currentVersion, String notes) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _bg2,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: Text('UPDATE AVAILABLE — v$version',
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13, color: _cyan, letterSpacing: 1)),
        content: Text(
          'Current: v$currentVersion → v$version\n\n$notes'.trim(),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: _textDim, height: 1.8),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('LATER', style: TextStyle(fontFamily: 'monospace', color: _textDim)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Open releases page
              Process.run('xdg-open', [url]).catchError((_) =>
                Process.run('open', [url]));
            },
            child: const Text('DOWNLOAD', style: TextStyle(fontFamily: 'monospace', color: _cyan)),
          ),
        ],
      ),
    );
  }

  static void _showLinuxUpdateDialog(BuildContext context, String version, String? downloadUrl, String currentVersion, String notes) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _LinuxUpdateDialog(version: version, downloadUrl: downloadUrl, currentVersion: currentVersion, notes: notes),
    );
  }
}

class _LinuxUpdateDialog extends StatefulWidget {
  final String version;
  final String? downloadUrl;
  final String currentVersion;
  final String notes;
  const _LinuxUpdateDialog({required this.version, required this.downloadUrl, required this.currentVersion, required this.notes});

  @override
  State<_LinuxUpdateDialog> createState() => _LinuxUpdateDialogState();
}

class _LinuxUpdateDialogState extends State<_LinuxUpdateDialog> {
  bool _updating = false;
  String _status = '';
  double _progress = 0;

  Future<void> _update() async {
    if (widget.downloadUrl == null) return;
    setState(() { _updating = true; _status = 'DOWNLOADING...'; _progress = 0; });

    try {
      // Download tarball
      final tmpDir = await getTemporaryDirectory();
      final tarPath = '${tmpDir.path}/magi_update.tar.gz';
      final extractPath = '${tmpDir.path}/magi_update';

      final client = http.Client();
      final req = http.Request('GET', Uri.parse(widget.downloadUrl!));
      final res = await client.send(req);
      final total = res.contentLength ?? 0;
      int received = 0;

      final file = File(tarPath);
      final sink = file.openWrite();
      await for (final chunk in res.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) setState(() => _progress = received / total);
      }
      await sink.close();

      setState(() { _status = 'EXTRACTING...'; _progress = 1; });

      // Extract
      await Directory(extractPath).create(recursive: true);
      await Process.run('tar', ['-xzf', tarPath, '-C', extractPath]);

      setState(() { _status = 'INSTALLING...'; });

      // Write a helper script
      final bundlePath = '$extractPath/bundle';
      final scriptPath = '${tmpDir.path}/magi_install.sh';
      await File(scriptPath).writeAsString(
        '#!/bin/bash\ncp -r "$bundlePath/." /opt/magi-anime/\n'
      );
      await Process.run('chmod', ['+x', scriptPath]);

      // Detect desktop and use appropriate privilege escalation
      final desktop = Platform.environment['XDG_CURRENT_DESKTOP']?.toLowerCase() ?? '';
      final isKDE = desktop.contains('kde');

      ProcessResult result;
      if (isKDE) {
        result = await Process.run('pkexec', [scriptPath]);
        if (result.exitCode != 0) {
          setState(() { _status = 'ERROR: Auth failed. Run manually:\nsudo bash $scriptPath'; });
          return;
        }
      } else {
        // Find available terminal and spawn sudo in it
        final terminal = await _findTerminal();
        if (terminal == null) {
          setState(() { _status = 'ERROR: No terminal found. Run manually:\nsudo bash $scriptPath'; });
          return;
        }
        await Process.start(terminal, ['--', 'sudo', 'bash', scriptPath]);
        // Give terminal time to complete before restarting
        await Future.delayed(const Duration(seconds: 5));
      }

      setState(() { _status = 'DONE! RESTARTING...'; });
      await Future.delayed(const Duration(seconds: 1));

      // Restart the app
      await Process.run('/opt/magi-anime/magi_anime', [], runInShell: true);
      exit(0);
    } catch (e) {
      setState(() { _status = 'ERROR: $e'; _updating = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _bg2,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      title: Text('UPDATE AVAILABLE — v${widget.version}',
        style: const TextStyle(fontFamily: 'monospace', fontSize: 13, color: _cyan, letterSpacing: 1)),
      content: SizedBox(
        width: 320,
        child: _updating
            ? Column(mainAxisSize: MainAxisSize.min, children: [
                if (_progress > 0 && _progress < 1)
                  LinearProgressIndicator(value: _progress,
                    backgroundColor: const Color(0xFF1e2130),
                    valueColor: const AlwaysStoppedAnimation<Color>(_cyan)),
                const SizedBox(height: 12),
                Text(_status, style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: _textDim)),
              ])
            : Text(
                'Current: v\${widget.currentVersion} → v\${widget.version}\n\n\${widget.notes}\n\nMAGI will update and restart automatically.',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: _textDim, height: 1.8),
              ),
      ),
      actions: _updating ? [] : [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('LATER', style: TextStyle(fontFamily: 'monospace', color: _textDim)),
        ),
        TextButton(
          onPressed: _update,
          child: const Text('UPDATE NOW', style: TextStyle(fontFamily: 'monospace', color: _cyan)),
        ),
      ],
    );
  }
}
