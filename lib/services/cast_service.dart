import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class ChromecastDevice {
  final String name;
  final String host;
  final int port;
  ChromecastDevice({required this.name, required this.host, required this.port});
}

class CastService extends ChangeNotifier {
  List<ChromecastDevice> _devices = [];
  ChromecastDevice? _connectedDevice;
  SecureSocket? _socket;
  bool _scanning = false;
  bool _isConnected = false;
  bool _isCasting = false;
  int _requestId = 1;
  StreamSubscription? _socketSub;
  String? _sessionId;
  String? _transportId;
  int? _mediaSessionId;
  final List<int> _buffer = [];
  Timer? _heartbeatTimer;
  Duration castPosition = Duration.zero;
  Duration castDuration = Duration.zero;

  List<ChromecastDevice> get devices => _devices;
  ChromecastDevice? get connectedDevice => _connectedDevice;
  bool get isConnected => _isConnected;
  bool get isCasting => _isCasting;
  bool get scanning => _scanning;

  Future<void> startScan() async {
    _scanning = true;
    _devices = [];
    notifyListeners();
    try {
      final multicastGroup = InternetAddress('224.0.0.251');
      final socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4, 5353, reuseAddress: true, reusePort: true);
      socket.joinMulticast(multicastGroup);
      socket.broadcastEnabled = true;
      final query = _buildMdnsQuery('_googlecast._tcp.local');
      socket.send(query, multicastGroup, 5353);
      Timer(const Duration(seconds: 5), () {
        socket.close();
        _scanning = false;
        notifyListeners();
      });
      socket.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = socket.receive();
          if (datagram != null) {
            final device = _parseMdnsResponse(datagram.data, datagram.address.address);
            if (device != null && !_devices.any((d) => d.host == device.host)) {
              _devices.add(device);
              notifyListeners();
            }
          }
        }
      });
    } catch (_) {
      _scanning = false;
      notifyListeners();
    }
  }

  Uint8List _buildMdnsQuery(String name) {
    final parts = name.split('.');
    final buf = BytesBuilder();
    buf.add([0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]);
    for (final part in parts) {
      final bytes = utf8.encode(part);
      buf.addByte(bytes.length);
      buf.add(bytes);
    }
    buf.addByte(0x00);
    buf.add([0x00, 0x0c, 0x00, 0x01]);
    return buf.toBytes();
  }

  ChromecastDevice? _parseMdnsResponse(Uint8List data, String host) {
    try {
      final str = String.fromCharCodes(data);
      final fnMatch = RegExp(r'fn=([^\x00]+)').firstMatch(str);
      final name = fnMatch?.group(1) ?? 'Chromecast ($host)';
      return ChromecastDevice(name: name, host: host, port: 8009);
    } catch (_) {
      return null;
    }
  }

  Future<bool> connect(ChromecastDevice device) async {
    try {
      await disconnect();
      _socket = await SecureSocket.connect(
        device.host, device.port,
        onBadCertificate: (_) => true,
        timeout: const Duration(seconds: 8),
      );
      _connectedDevice = device;
      _isConnected = true;
      _buffer.clear();
      _sessionId = null;
      _transportId = null;
      _socketSub = _socket!.listen(
        _onData,
        onError: (_) => _handleDisconnect(),
        onDone: _handleDisconnect,
      );
      _sendMessage(
        namespace: 'urn:x-cast:com.google.cast.tp.connection',
        sourceId: 'sender-0',
        destinationId: 'receiver-0',
        payload: {'type': 'CONNECT', 'userAgent': 'MAGI/1.0'},
      );
      _startHeartbeat();
      notifyListeners();
      return true;
    } catch (_) {
      _isConnected = false;
      notifyListeners();
      return false;
    }
  }

  int _heartbeatCount = 0;

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_isConnected) {
        _heartbeatCount++;
        // PING every 10 seconds (every 5th 2s tick)
        if (_heartbeatCount % 5 == 0) {
          _sendMessage(
            namespace: 'urn:x-cast:com.google.cast.tp.heartbeat',
            sourceId: 'sender-0',
            destinationId: 'receiver-0',
            payload: {'type': 'PING'},
          );
        }
        // Poll media status every 2 seconds for position updates
        if (_transportId != null) {
          _sendMessage(
            namespace: 'urn:x-cast:com.google.cast.media',
            sourceId: 'sender-0',
            destinationId: _transportId!,
            payload: {'type': 'GET_STATUS', 'requestId': _requestId++},
          );
        }
      }
    });
  }

  void _onData(List<int> data) {
    _buffer.addAll(data);
    _processBuffer();
  }

  void _processBuffer() {
    while (_buffer.length >= 4) {
      final msgLen = ByteData.sublistView(
        Uint8List.fromList(_buffer.sublist(0, 4))).getUint32(0);
      if (_buffer.length < 4 + msgLen) break;
      final msgData = _buffer.sublist(4, 4 + msgLen);
      _buffer.removeRange(0, 4 + msgLen);
      try {
        _handleMessage(Uint8List.fromList(msgData));
      } catch (_) {}
    }
  }

  void _handleMessage(Uint8List data) {
    String? payload;
    int pos = 0;
    while (pos < data.length) {
      final tag = data[pos] & 0xFF;
      final fieldNum = tag >> 3;
      final wireType = tag & 0x07;
      pos++;
      if (wireType == 0) {
        while (pos < data.length) {
          final b = data[pos++];
          if ((b & 0x80) == 0) break;
        }
      } else if (wireType == 2) {
        int len = 0, shift = 0;
        while (pos < data.length) {
          final b = data[pos++];
          len |= (b & 0x7F) << shift;
          if ((b & 0x80) == 0) break;
          shift += 7;
        }
        final bytes = data.sublist(pos, pos + len);
        pos += len;
        if (fieldNum == 6) {
          payload = utf8.decode(bytes, allowMalformed: true);
        }
      } else {
        break;
      }
    }
    if (payload == null) return;
    try {
      final json = jsonDecode(payload) as Map<String, dynamic>;
      final type = json['type'] as String?;
      if (type == 'PING') {
        _sendMessage(
          namespace: 'urn:x-cast:com.google.cast.tp.heartbeat',
          sourceId: 'sender-0',
          destinationId: 'receiver-0',
          payload: {'type': 'PONG'},
        );
      } else if (type == 'RECEIVER_STATUS') {
        final status = json['status'] as Map<String, dynamic>?;
        final apps = status?['applications'] as List?;
        if (apps != null && apps.isNotEmpty) {
          final app = apps.first as Map<String, dynamic>;
          _sessionId = app['sessionId'] as String?;
          _transportId = app['transportId'] as String?;
          if (_transportId != null && _sessionId != null) {
            _sendMessage(
              namespace: 'urn:x-cast:com.google.cast.tp.connection',
              sourceId: 'sender-0',
              destinationId: _transportId!,
              payload: {'type': 'CONNECT', 'userAgent': 'MAGI/1.0'},
            );
            notifyListeners();
          }
        }
      } else if (type == 'MEDIA_STATUS') {
        _isCasting = true;
        final statuses = json['status'] as List?;
        if (statuses != null && statuses.isNotEmpty) {
          final status = statuses.first as Map<String, dynamic>;
          _mediaSessionId = status['mediaSessionId'] as int?;
          final currentTime = status['currentTime'];
          if (currentTime != null) {
            castPosition = Duration(milliseconds: ((currentTime as num) * 1000).round());
          }
          final media = status['media'] as Map<String, dynamic>?;
          final duration = media?['duration'];
          if (duration != null) {
            castDuration = Duration(milliseconds: ((duration as num) * 1000).round());
          }
        }
        notifyListeners();
      } else if (type == 'LOAD_FAILED') {
        _isCasting = false;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> cast(String url, String title) async {
    if (!_isConnected) return;

    // If already casting, stop current media first before loading new one
    if (_isCasting && _transportId != null && _mediaSessionId != null) {
      _sendMessage(
        namespace: 'urn:x-cast:com.google.cast.media',
        sourceId: 'sender-0',
        destinationId: _transportId!,
        payload: {
          'type': 'STOP',
          'requestId': _requestId++,
          'mediaSessionId': _mediaSessionId,
        },
      );
      await Future.delayed(const Duration(milliseconds: 500));
    }

    _isCasting = false;
    _mediaSessionId = null;
    castPosition = Duration.zero;
    castDuration = Duration.zero;

    // If we don't have a transport ID yet, launch the app first
    if (_transportId == null) {
      _sessionId = null;
      final id = _requestId++;
      _sendMessage(
        namespace: 'urn:x-cast:com.google.cast.receiver',
        sourceId: 'sender-0',
        destinationId: 'receiver-0',
        payload: {'type': 'LAUNCH', 'appId': 'CC1AD845', 'requestId': id},
      );
      for (int i = 0; i < 20; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (_transportId != null) break;
      }
      if (_transportId == null) return;
    }

    // Load new media
    _sendMessage(
      namespace: 'urn:x-cast:com.google.cast.media',
      sourceId: 'sender-0',
      destinationId: _transportId!,
      payload: {
        'type': 'LOAD',
        'requestId': _requestId++,
        'sessionId': _sessionId,
        'media': {
          'contentId': url,
          'contentType': 'video/mp4',
          'streamType': 'BUFFERED',
          'metadata': {'metadataType': 0, 'title': title},
        },
        'autoplay': true,
        'currentTime': 0,
      },
    );
    notifyListeners();
  }

  Future<void> seek(Duration position) async {
    if (!_isConnected || _transportId == null || _mediaSessionId == null) return;
    _sendMessage(
      namespace: 'urn:x-cast:com.google.cast.media',
      sourceId: 'sender-0',
      destinationId: _transportId!,
      payload: {
        'type': 'SEEK',
        'requestId': _requestId++,
        'mediaSessionId': _mediaSessionId,
        'currentTime': position.inSeconds,
        'resumeState': 'PLAYBACK_START',
      },
    );
  }

  void _sendMessage({
    required String namespace,
    required String sourceId,
    required String destinationId,
    required Map<String, dynamic> payload,
  }) {
    if (_socket == null) return;
    try {
      final payloadBytes = utf8.encode(jsonEncode(payload));
      final msg = _buildCastMessage(namespace, sourceId, destinationId, payloadBytes);
      final lenBytes = ByteData(4)..setUint32(0, msg.length);
      _socket!.add(lenBytes.buffer.asUint8List());
      _socket!.add(msg);
    } catch (_) {}
  }

  Uint8List _buildCastMessage(
    String namespace, String sourceId, String destinationId, List<int> payload) {
    final buf = BytesBuilder();
    void writeField(int fieldNum, int wireType, List<int> data) {
      buf.addByte((fieldNum << 3) | wireType);
      if (wireType == 2) { _writeVarint(buf, data.length); buf.add(data); }
      else if (wireType == 0) { buf.add(data); }
    }
    writeField(1, 0, [0x00]);
    writeField(2, 2, utf8.encode(sourceId));
    writeField(3, 2, utf8.encode(destinationId));
    writeField(4, 2, utf8.encode(namespace));
    writeField(5, 0, [0x00]);
    writeField(6, 2, payload);
    return buf.toBytes();
  }

  void _writeVarint(BytesBuilder buf, int value) {
    while (value > 0x7f) {
      buf.addByte((value & 0x7f) | 0x80);
      value >>= 7;
    }
    buf.addByte(value);
  }

  void _handleDisconnect() {
    _heartbeatTimer?.cancel();
    _heartbeatCount = 0;
    _isConnected = false;
    _isCasting = false;
    _connectedDevice = null;
    _sessionId = null;
    _transportId = null;
    _mediaSessionId = null;
    _socket = null;
    castPosition = Duration.zero;
    castDuration = Duration.zero;
    notifyListeners();
  }

  Future<void> disconnect() async {
    if (_socket != null) {
      try {
        // Stop media playback on the receiver
        if (_transportId != null && _mediaSessionId != null) {
          _sendMessage(
            namespace: 'urn:x-cast:com.google.cast.media',
            sourceId: 'sender-0',
            destinationId: _transportId!,
            payload: {
              'type': 'STOP',
              'requestId': _requestId++,
              'mediaSessionId': _mediaSessionId,
            },
          );
        }
        // Stop the receiver app
        _sendMessage(
          namespace: 'urn:x-cast:com.google.cast.receiver',
          sourceId: 'sender-0',
          destinationId: 'receiver-0',
          payload: {'type': 'STOP', 'requestId': _requestId++},
        );
        await Future.delayed(const Duration(milliseconds: 300));
        // Close the connection
        _sendMessage(
          namespace: 'urn:x-cast:com.google.cast.tp.connection',
          sourceId: 'sender-0',
          destinationId: 'receiver-0',
          payload: {'type': 'CLOSE'},
        );
      } catch (_) {}
    }
    _heartbeatTimer?.cancel();
    await _socketSub?.cancel();
    await _socket?.close();
    _handleDisconnect();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
