import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/update_service.dart';

const _cyan = Color(0xFF00d4d4);
const _bg2 = Color(0xFF0f1117);
const _bg3 = Color(0xFF151720);
const _border = Color(0xFF1e2130);
const _textDim = Color(0xFF5a6080);

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _apiController;
  bool _saved = false;
  bool _testing = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    final api = context.read<ApiService>();
    _apiController = TextEditingController(text: api.apiBase);
  }

  @override
  void dispose() {
    _apiController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final api = context.read<ApiService>();
    await api.setApiBase(_apiController.text.trim());
    setState(() => _saved = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _saved = false);
    });
  }

  Future<void> _test() async {
    setState(() { _testing = true; _testResult = null; });
    try {
      final api = context.read<ApiService>();
      final providers = await api.getProviders();
      setState(() {
        _testResult = '✓ CONNECTED — providers: ${providers.join(', ')}';
        _testing = false;
      });
    } catch (e) {
      setState(() { _testResult = '✗ FAILED: $e'; _testing = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a0b0f),
      appBar: AppBar(
        title: const Text('SETTINGS', style: TextStyle(
          fontFamily: 'monospace', fontSize: 14, color: _cyan, letterSpacing: 4,
        )),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _textDim),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('API SERVER', style: TextStyle(
              fontFamily: 'monospace', fontSize: 11, color: _textDim, letterSpacing: 3,
            )),
            const SizedBox(height: 12),
            const Text(
              'Set the address of your anipy homelab server.',
              style: TextStyle(fontSize: 13, color: _textDim),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _apiController,
              style: const TextStyle(fontFamily: 'monospace', color: Color(0xFFc8ccd8)),
              decoration: InputDecoration(
                hintText: 'http://192.168.0.37:3002',
                hintStyle: const TextStyle(fontFamily: 'monospace', color: _textDim, fontSize: 13),
                filled: true,
                fillColor: _bg3,
                border: OutlineInputBorder(borderSide: const BorderSide(color: _border), borderRadius: BorderRadius.zero),
                enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: _border), borderRadius: BorderRadius.zero),
                focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: _cyan), borderRadius: BorderRadius.zero),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                GestureDetector(
                  onTap: _save,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(border: Border.all(color: _cyan.withOpacity(0.5))),
                    child: Text(
                      _saved ? '✓ SAVED' : 'SAVE',
                      style: TextStyle(
                        fontFamily: 'monospace', fontSize: 12,
                        color: _saved ? Colors.green : _cyan, letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _test,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(border: Border.all(color: _border)),
                    child: _testing
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: _cyan, strokeWidth: 2))
                        : const Text('TEST CONNECTION', style: TextStyle(
                            fontFamily: 'monospace', fontSize: 12, color: _textDim, letterSpacing: 1,
                          )),
                  ),
                ),
              ],
            ),
            if (_testResult != null) ...[
              const SizedBox(height: 12),
              Text(_testResult!, style: TextStyle(
                fontFamily: 'monospace', fontSize: 11,
                color: _testResult!.startsWith('✓') ? _cyan : const Color(0xFFd44000),
              )),
            ],
            const SizedBox(height: 40),
            const Divider(color: _border),
            const SizedBox(height: 20),
            const Text('ABOUT', style: TextStyle(
              fontFamily: 'monospace', fontSize: 11, color: _textDim, letterSpacing: 3,
            )),
            const SizedBox(height: 12),
            FutureBuilder<String>(
              future: getMagiVersion(),
              builder: (context, snap) {
                final version = snap.data ?? '...';
                return Text('MAGI // ANIME TERMINAL\nv$version', style: const TextStyle(
                  fontFamily: 'monospace', fontSize: 12, color: _textDim, height: 1.8,
                ));
              },
            ),
          ],
        ),
      ),
    );
  }
}
