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

  // Session state
  String? _sessionId;
  String? _transportId;

  // Buffer for incoming data
  final List<int> _buffer = [];

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
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 5353,
          reuseAddress: true, reusePort: true);
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

      // Send initial CONNECT
      _sendMessage(
        namespace: 'urn:x-cast:com.google.cast.tp.connection',
        sourceId: 'sender-0',
        destinationId: 'receiver-0',
        payload: {'type': 'CONNECT', 'userAgent': 'MAGI/1.0'},
      );

      // Start heartbeat
      _startHeartbeat();

      notifyListeners();
      return true;
    } catch (_) {
      _isConnected = false;
      notifyListeners();
      return false;
    }
  }

  Timer? _heartbeatTimer;
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_isConnected) {
        _sendMessage(
          namespace: 'urn:x-cast:com.google.cast.tp.heartbeat',
          sourceId: 'sender-0',
          destinationId: 'receiver-0',
          payload: {'type': 'PING'},
        );
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
        Uint8List.fromList(_buffer.sublist(0, 4))
      ).getUint32(0);

      if (_buffer.length < 4 + msgLen) break;

      final msgData = _buffer.sublist(4, 4 + msgLen);
      _buffer.removeRange(0, 4 + msgLen);

      try {
        _handleMessage(Uint8List.fromList(msgData));
      } catch (_) {}
    }
  }

  void _handleMessage(Uint8List data) {
    // Parse protobuf manually to extract payload_utf8 (field 6)
    String? payload;
    int pos = 0;
    while (pos < data.length) {
      final tag = data[pos] & 0xFF;
      final fieldNum = tag >> 3;
      final wireType = tag & 0x07;
      pos++;

      if (wireType == 0) {
        // Varint
        int val = 0, shift = 0;
        while (pos < data.length) {
          final b = data[pos++];
          val |= (b & 0x7F) << shift;
          if ((b & 0x80) == 0) break;
          shift += 7;
        }
        // ignore: unused_local_variable
        // varint value, not needed
      } else if (wireType == 2) {
        // Length-delimited
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
        // Extract session and transport IDs
        final status = json['status'] as Map<String, dynamic>?;
        final apps = status?['applications'] as List?;
        if (apps != null && apps.isNotEmpty) {
          final app = apps.first as Map<String, dynamic>;
          _sessionId = app['sessionId'] as String?;
          _transportId = app['transportId'] as String?;

          if (_transportId != null && _sessionId != null) {
            // Connect to the app transport
            _sendMessage(
              namespace: 'urn:x-cast:com.google.cast.tp.connection',
              sourceId: 'sender-0',
              destinationId: _transportId!,
              payload: {'type': 'CONNECT', 'userAgent': 'MAGI/1.0'},
            );
            // Signal that we're ready to send LOAD
            notifyListeners();
          }
        }
      } else if (type == 'MEDIA_STATUS') {
        _isCasting = true;
        notifyListeners();
      } else if (type == 'LOAD_FAILED') {
        _isCasting = false;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> cast(String url, String title) async {
    if (!_isConnected) return;

    _isCasting = false;
    _sessionId = null;
    _transportId = null;

    final id = _requestId++;

    // Launch default media receiver app
    _sendMessage(
      namespace: 'urn:x-cast:com.google.cast.receiver',
      sourceId: 'sender-0',
      destinationId: 'receiver-0',
      payload: {
        'type': 'LAUNCH',
        'appId': 'CC1AD845',
        'requestId': id,
      },
    );

    // Wait for RECEIVER_STATUS with transportId then send LOAD
    // We poll until transportId is set (max 10 seconds)
    for (int i = 0; i < 20; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (_transportId != null) break;
    }

    if (_transportId == null) return;

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
          'metadata': {
            'metadataType': 0,
            'title': title,
          },
        },
        'autoplay': true,
        'currentTime': 0,
      },
    );

    notifyListeners();
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
    String namespace, String sourceId, String destinationId, List<int> payload,
  ) {
    final buf = BytesBuilder();

    void writeField(int fieldNum, int wireType, List<int> data) {
      buf.addByte((fieldNum << 3) | wireType);
      if (wireType == 2) {
        _writeVarint(buf, data.length);
        buf.add(data);
      } else if (wireType == 0) {
        buf.add(data);
      }
    }

    // Field 1: protocol_version = 0 (varint)
    writeField(1, 0, [0x00]);
    // Field 2: source_id
    writeField(2, 2, utf8.encode(sourceId));
    // Field 3: destination_id
    writeField(3, 2, utf8.encode(destinationId));
    // Field 4: namespace
    writeField(4, 2, utf8.encode(namespace));
    // Field 5: payload_type = STRING (0)
    writeField(5, 0, [0x00]);
    // Field 6: payload_utf8
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
    _isConnected = false;
    _isCasting = false;
    _connectedDevice = null;
    _sessionId = null;
    _transportId = null;
    _socket = null;
    notifyListeners();
  }

  Future<void> disconnect() async {
    if (_socket != null) {
      try {
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
