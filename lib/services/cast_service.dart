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
  Socket? _socket;
  bool _scanning = false;
  bool _isConnected = false;
  int _requestId = 1;
  StreamSubscription? _socketSub;

  List<ChromecastDevice> get devices => _devices;
  ChromecastDevice? get connectedDevice => _connectedDevice;
  bool get isConnected => _isConnected;
  bool get scanning => _scanning;

  // Chromecast uses mDNS on port 5353 multicast group 224.0.0.251
  Future<void> startScan() async {
    _scanning = true;
    _devices = [];
    notifyListeners();

    try {
      final multicastGroup = InternetAddress('224.0.0.251');
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 5353);
      socket.joinMulticast(multicastGroup);
      socket.broadcastEnabled = true;

      // Send mDNS query for _googlecast._tcp.local
      final query = _buildMdnsQuery('_googlecast._tcp.local');
      socket.send(query, multicastGroup, 5353);

      final timer = Timer(const Duration(seconds: 5), () {
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
    } catch (e) {
      _scanning = false;
      notifyListeners();
    }
  }

  Uint8List _buildMdnsQuery(String name) {
    final parts = name.split('.');
    final buf = BytesBuilder();
    // Header
    buf.add([0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]);
    // Question
    for (final part in parts) {
      final bytes = utf8.encode(part);
      buf.addByte(bytes.length);
      buf.add(bytes);
    }
    buf.addByte(0x00);
    buf.add([0x00, 0x0c, 0x00, 0x01]); // PTR, IN
    return buf.toBytes();
  }

  ChromecastDevice? _parseMdnsResponse(Uint8List data, String host) {
    try {
      // Look for friendly name in TXT records
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
      _socket = await SecureSocket.connect(
        device.host, device.port,
        onBadCertificate: (_) => true, // Chromecast uses self-signed cert
        timeout: const Duration(seconds: 5),
      );
      _connectedDevice = device;
      _isConnected = true;

      // Send CONNECT message
      _sendMessage('urn:x-cast:com.google.cast.tp.connection', {
        'type': 'CONNECT', 'userAgent': 'MAGI/1.0',
      });

      // Listen for responses
      _socketSub = _socket!.listen(
        _onData,
        onError: (_) => _handleDisconnect(),
        onDone: _handleDisconnect,
      );

      notifyListeners();
      return true;
    } catch (e) {
      _isConnected = false;
      notifyListeners();
      return false;
    }
  }

  void _onData(List<int> data) {
    // Handle incoming Cast messages (keepalive PING/PONG)
    try {
      if (data.length > 4) {
        final msgLen = ByteData.sublistView(Uint8List.fromList(data), 0, 4).getUint32(0);
        if (data.length >= 4 + msgLen) {
          final msgData = data.sublist(4, 4 + msgLen);
          final msgStr = utf8.decode(msgData, allowMalformed: true);
          if (msgStr.contains('"PING"')) {
            _sendMessage('urn:x-cast:com.google.cast.tp.heartbeat', {'type': 'PONG'});
          }
        }
      }
    } catch (_) {}
  }

  void _handleDisconnect() {
    _isConnected = false;
    _connectedDevice = null;
    _socket = null;
    notifyListeners();
  }

  void _sendMessage(String namespace, Map<String, dynamic> payload) {
    if (_socket == null) return;
    try {
      final payloadStr = jsonEncode(payload);
      final payloadBytes = utf8.encode(payloadStr);

      // Cast protocol message format
      final msg = _buildCastMessage(namespace, payloadBytes);
      final lenBytes = ByteData(4)..setUint32(0, msg.length);
      _socket!.add(lenBytes.buffer.asUint8List());
      _socket!.add(msg);
    } catch (_) {}
  }

  Uint8List _buildCastMessage(String namespace, List<int> payload) {
    // Simplified protobuf encoding for Cast protocol
    final buf = BytesBuilder();
    // Field 1: protocol_version = 0
    buf.add([0x08, 0x00]);
    // Field 2: source_id = "sender-0"
    final src = utf8.encode('sender-0');
    buf.add([0x12, src.length]);
    buf.add(src);
    // Field 3: destination_id = "receiver-0"
    final dst = utf8.encode('receiver-0');
    buf.add([0x1a, dst.length]);
    buf.add(dst);
    // Field 4: namespace
    final ns = utf8.encode(namespace);
    buf.add([0x22, ns.length]);
    buf.add(ns);
    // Field 5: payload_type = STRING (0)
    buf.add([0x28, 0x00]);
    // Field 6: payload_utf8
    buf.add([0x32]);
    _writeVarint(buf, payload.length);
    buf.add(payload);
    return buf.toBytes();
  }

  void _writeVarint(BytesBuilder buf, int value) {
    while (value > 0x7f) {
      buf.addByte((value & 0x7f) | 0x80);
      value >>= 7;
    }
    buf.addByte(value);
  }

  Future<void> cast(String url, String title) async {
    if (!_isConnected) return;
    final id = _requestId++;
    // Launch default media receiver
    _sendMessage('urn:x-cast:com.google.cast.receiver', {
      'type': 'LAUNCH',
      'appId': 'CC1AD845',
      'requestId': id,
    });
    await Future.delayed(const Duration(milliseconds: 1000));
    // Load media
    _sendMessage('urn:x-cast:com.google.cast.media', {
      'type': 'LOAD',
      'requestId': _requestId++,
      'media': {
        'contentId': url,
        'contentType': 'video/mp4',
        'streamType': 'BUFFERED',
        'metadata': {'metadataType': 0, 'title': title},
      },
      'autoplay': true,
      'currentTime': 0,
    });
    notifyListeners();
  }

  Future<void> disconnect() async {
    _sendMessage('urn:x-cast:com.google.cast.tp.connection', {'type': 'CLOSE'});
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
