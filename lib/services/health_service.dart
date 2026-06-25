import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';

enum ServerHealth { unknown, healthy, unhealthy }

class HealthService extends ChangeNotifier {
  ServerHealth _status = ServerHealth.unknown;
  ServerHealth get status => _status;

  Timer? _timer;
  final ApiService _api;

  HealthService(this._api) {
    // Delay first check so it doesn't compete with initial browse loading
    Future.delayed(const Duration(seconds: 10), _check);
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _check());
  }

  Future<void> _check() async {
    try {
      final uri = Uri.parse('${_api.apiBase}/providers');
      final res = await http.get(uri).timeout(const Duration(seconds: 5));
      final healthy = res.statusCode == 200;
      if (healthy != (_status == ServerHealth.healthy)) {
        _status = healthy ? ServerHealth.healthy : ServerHealth.unhealthy;
        notifyListeners();
      }
    } catch (_) {
      if (_status != ServerHealth.unhealthy) {
        _status = ServerHealth.unhealthy;
        notifyListeners();
      }
    }
  }

  Future<void> refresh() => _check();

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
