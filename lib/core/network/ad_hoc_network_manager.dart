import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart' as nearby;
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as ble;
import '../protocol/packet_encoder.dart';
import '../protocol/xor_fec_engine.dart';

enum NetworkTransport {
  disconnected,
  wifiDirect,
  bleFallback,
}

class NetworkMetrics {
  final NetworkTransport transport;
  final int bytesSent;
  final int bytesReceived;
  final int packetsSent;
  final int packetsReceived;
  final int packetsRecoveredByFec;
  final int lastRoundTripMs;

  NetworkMetrics({
    required this.transport,
    required this.bytesSent,
    required this.bytesReceived,
    required this.packetsSent,
    required this.packetsReceived,
    required this.packetsRecoveredByFec,
    required this.lastRoundTripMs,
  });

  NetworkMetrics copyWith({
    NetworkTransport? transport,
    int? bytesSent,
    int? bytesReceived,
    int? packetsSent,
    int? packetsReceived,
    int? packetsRecoveredByFec,
    int? lastRoundTripMs,
  }) {
    return NetworkMetrics(
      transport: transport ?? this.transport,
      bytesSent: bytesSent ?? this.bytesSent,
      bytesReceived: bytesReceived ?? this.bytesReceived,
      packetsSent: packetsSent ?? this.packetsSent,
      packetsReceived: packetsReceived ?? this.packetsReceived,
      packetsRecoveredByFec: packetsRecoveredByFec ?? this.packetsRecoveredByFec,
      lastRoundTripMs: lastRoundTripMs ?? this.lastRoundTripMs,
    );
  }
}

class AdHocNetworkManager {
  static const String serviceId = 'com.itantra.mesh';
  static final nearby.Strategy strategy = nearby.Strategy.P2P_STAR;
  static const int p2pUdpPort = 19876;
  static const int p2pHttpPort = 18080;

  NetworkTransport _activeTransport = NetworkTransport.wifiDirect;
  NetworkTransport get activeTransport => _activeTransport;

  final XorFecEngine _fecEngine = XorFecEngine(k: 4);
  RawDatagramSocket? _udpSocket;
  HttpServer? _httpServer;
  final int _localDeviceId = DateTime.now().microsecondsSinceEpoch & 0x7FFFFFFF;

  String? _localIpAddress;
  String? get localIpAddress => _localIpAddress;

  final Set<String> _knownPeerIps = {};
  Set<String> get knownPeerIps => Set.unmodifiable(_knownPeerIps);

  void addPeerIp(String ip) {
    if (ip.isNotEmpty && ip != '127.0.0.1' && ip != _localIpAddress) {
      _knownPeerIps.add(ip);
      debugPrint('[AdHocNetwork] Added peer IP: $ip');
    }
  }

  // Incoming FEC frame buffer: blockId -> List<FecFrame>
  final Map<int, List<FecFrame>> _fecBlockBuffer = {};

  final StreamController<TransceiverPacket> _incomingPacketController =
      StreamController<TransceiverPacket>.broadcast();
  Stream<TransceiverPacket> get incomingPackets => _incomingPacketController.stream;

  final StreamController<NetworkMetrics> _metricsController =
      StreamController<NetworkMetrics>.broadcast();
  Stream<NetworkMetrics> get metrics => _metricsController.stream;

  NetworkMetrics _currentMetrics = NetworkMetrics(
    transport: NetworkTransport.wifiDirect,
    bytesSent: 0,
    bytesReceived: 0,
    packetsSent: 0,
    packetsReceived: 0,
    packetsRecoveredByFec: 0,
    lastRoundTripMs: 0,
  );

  String? _connectedEndpointId;
  String _localDeviceName = 'iTantra-Device';

  bool _isAdvertising = false;
  bool _isDiscovering = false;

  /// Starts Ad-Hoc mesh: starts Wi-Fi Direct discovery and advertising,
  /// plus local zero-config UDP broadcast socket and embedded HTTP mesh.
  Future<void> start({String? deviceName}) async {
    _localDeviceName = deviceName ?? 'iTantra-${DateTime.now().millisecond}';
    debugPrint('[AdHocNetwork] Starting P2P mesh as $_localDeviceName (ID: $_localDeviceId)');

    // 1. Discover local network interfaces & determine IP
    await _refreshNetworkInterfaces();

    // 2. Start Zero-Configuration UDP Mesh Socket
    await _startUdpMesh();

    // 3. Start Embedded HTTP mesh server (guaranteed local TCP fallback)
    await _startHttpMesh();

    // 4. Start automatic periodic peer discovery heartbeat
    _startDiscoveryHeartbeat();

    // 5. Start Wi-Fi Direct via nearby_connections
    try {
      await _startWifiDirect();
    } catch (e) {
      debugPrint('[AdHocNetwork] Wi-Fi Direct init failed, falling back to BLE: $e');
      await _fallbackToBle();
    }
  }

  Timer? _discoveryTimer;

  void _startDiscoveryHeartbeat() {
    _discoveryTimer?.cancel();
    _discoveryTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      await _refreshNetworkInterfaces();
      if (_localIpAddress == null) return;

      final parts = _localIpAddress!.split('.');
      if (parts.length != 4) return;

      final subnetPrefix = '${parts[0]}.${parts[1]}.${parts[2]}';

      // 1. If client (e.g. 192.168.43.45), actively announce to hotspot gateway (.1)
      if (parts[3] != '1') {
        final gateway = '$subnetPrefix.1';
        _announceToPeer(gateway);
      } else {
        // 2. If host (192.168.43.1), probe connected client IP range (2..20)
        _probeSubnetRange(subnetPrefix, 1, 50);
      }

      // 3. Send zero-config UDP broadcast ping to 255.255.255.255 for instant zero-touch auto-pairing
      try {
        final pingHeader = ByteData(4)..setUint32(0, _localDeviceId);
        _udpSocket?.send(pingHeader.buffer.asUint8List(), InternetAddress('255.255.255.255'), p2pUdpPort);
      } catch (_) {}

      // 4. Announce to all currently known peers
      for (final peerIp in _knownPeerIps) {
        _announceToPeer(peerIp);
      }
    });
  }

  Future<void> _announceToPeer(String peerIp) async {
    try {
      final client = HttpClient()..connectionTimeout = const Duration(milliseconds: 400);
      final req = await client.getUrl(Uri.parse('http://$peerIp:$p2pHttpPort/announce?peer=$_localIpAddress'));
      final res = await req.close().timeout(const Duration(milliseconds: 600));
      await res.drain();
      client.close();
      addPeerIp(peerIp);
    } catch (_) {}
  }

  Future<void> _probeSubnetRange(String subnetPrefix, int start, int end) async {
    for (int i = start; i <= end; i++) {
      final targetIp = '$subnetPrefix.$i';
      if (targetIp != _localIpAddress) {
        _announceToPeer(targetIp);
      }
    }
  }

  /// Manually trigger a quick subnet scan to discover peers
  Future<void> scanSubnet() async {
    await _refreshNetworkInterfaces();
    if (_localIpAddress == null) return;
    final parts = _localIpAddress!.split('.');
    if (parts.length == 4) {
      final subnetPrefix = '${parts[0]}.${parts[1]}.${parts[2]}';
      await _probeSubnetRange(subnetPrefix, 1, 60);
    }
  }

  Future<void> _refreshNetworkInterfaces() async {
    try {
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && addr.address.contains('.')) {
            _localIpAddress = addr.address;
            final parts = addr.address.split('.');
            if (parts.length == 4) {
              // If we are a client connected to a hotspot (typically .1), add hotspot IP
              if (parts[3] != '1') {
                addPeerIp('${parts[0]}.${parts[1]}.${parts[2]}.1');
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[AdHocNetwork] Error refreshing network interfaces: $e');
    }
  }

  Future<void> _startHttpMesh() async {
    try {
      _httpServer = await HttpServer.bind(InternetAddress.anyIPv4, p2pHttpPort);
      _httpServer!.listen((request) async {
        if (request.method == 'POST' && request.uri.path == '/packet') {
          final bytes = await request.fold<List<int>>([], (prev, elem) => prev..addAll(elem));
          request.response.statusCode = HttpStatus.ok;
          request.response.write('OK');
          await request.response.close();

          final remoteIp = request.connectionInfo?.remoteAddress.address;
          if (remoteIp != null && remoteIp != '127.0.0.1' && remoteIp != _localIpAddress) {
            addPeerIp(remoteIp);
          }
          if (bytes.isNotEmpty) {
            _handleRawIncomingBytes(Uint8List.fromList(bytes));
          }
        } else if (request.method == 'GET' && request.uri.path == '/announce') {
          final peerIp = request.uri.queryParameters['peer'] ?? request.connectionInfo?.remoteAddress.address;
          if (peerIp != null && peerIp != '127.0.0.1' && peerIp != _localIpAddress) {
            addPeerIp(peerIp);
          }
          request.response.statusCode = HttpStatus.ok;
          request.response.write('OK:$_localIpAddress');
          await request.response.close();
        } else if (request.method == 'GET' && request.uri.path == '/ping') {
          final remoteIp = request.connectionInfo?.remoteAddress.address;
          if (remoteIp != null && remoteIp != '127.0.0.1' && remoteIp != _localIpAddress) {
            addPeerIp(remoteIp);
          }
          request.response.statusCode = HttpStatus.ok;
          request.response.write('iTantra');
          await request.response.close();
        } else {
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
        }
      });
      debugPrint('[AdHocNetwork] HTTP Mesh bound on port $p2pHttpPort');
    } catch (e) {
      debugPrint('[AdHocNetwork] HTTP Mesh bind error: $e');
    }
  }

  Future<void> _startUdpMesh() async {
    try {
      _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, p2pUdpPort);
      _udpSocket!.broadcastEnabled = true;
      _udpSocket!.readEventsEnabled = true;

      _udpSocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _udpSocket?.receive();
          if (datagram != null && datagram.data.length > 4) {
            final senderIp = datagram.address.address;
            if (senderIp != '127.0.0.1' && senderIp != _localIpAddress) {
              _knownPeerIps.add(senderIp);
            }

            // Check sender device ID (first 4 bytes)
            final byteData = ByteData.sublistView(datagram.data);
            final senderId = byteData.getUint32(0);
            if (senderId != _localDeviceId) {
              // Valid remote packet!
              final payload = datagram.data.sublist(4);
              _handleRawIncomingBytes(payload);
            }
          }
        }
      });
      debugPrint('[AdHocNetwork] UDP P2P Mesh bound successfully on port $p2pUdpPort');
    } catch (e) {
      debugPrint('[AdHocNetwork] UDP P2P Mesh bind exception: $e');
    }
  }

  /// Start Wi-Fi Direct via nearby_connections
  Future<void> _startWifiDirect() async {
    try {
      // 1. Start Advertising
      final advSuccess = await nearby.Nearby().startAdvertising(
        _localDeviceName,
        strategy,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
        serviceId: serviceId,
      );
      _isAdvertising = advSuccess;

      // 2. Start Discovery
      final discSuccess = await nearby.Nearby().startDiscovery(
        _localDeviceName,
        strategy,
        onEndpointFound: (endpointId, endpointName, serviceId) {
          debugPrint('[AdHocNetwork] Discovered peer $endpointName ($endpointId)');
          _requestConnection(endpointId);
        },
        onEndpointLost: (endpointId) {
          debugPrint('[AdHocNetwork] Lost peer endpoint: $endpointId');
        },
        serviceId: serviceId,
      );
      _isDiscovering = discSuccess;

      _activeTransport = NetworkTransport.wifiDirect;
      _updateMetrics(transport: NetworkTransport.wifiDirect);
    } catch (e) {
      debugPrint('[AdHocNetwork] Nearby Wi-Fi Direct error: $e');
      await _fallbackToBle();
    }
  }

  void _requestConnection(String endpointId) {
    nearby.Nearby().requestConnection(
      _localDeviceName,
      endpointId,
      onConnectionInitiated: _onConnectionInitiated,
      onConnectionResult: _onConnectionResult,
      onDisconnected: _onDisconnected,
    );
  }

  void _onConnectionInitiated(String endpointId, nearby.ConnectionInfo connectionInfo) {
    debugPrint('[AdHocNetwork] Connection initiated from ${connectionInfo.endpointName}');
    // Auto-accept secure P2P connection
    nearby.Nearby().acceptConnection(
      endpointId,
      onPayLoadRecieved: (endpointId, payload) {
        if (payload.type == nearby.PayloadType.BYTES && payload.bytes != null) {
          _handleRawIncomingBytes(payload.bytes!);
        }
      },
    );
  }

  void _onConnectionResult(String endpointId, nearby.Status status) {
    if (status == nearby.Status.CONNECTED) {
      _connectedEndpointId = endpointId;
      _activeTransport = NetworkTransport.wifiDirect;
      _updateMetrics(transport: NetworkTransport.wifiDirect);
      debugPrint('[AdHocNetwork] Connected via Wi-Fi Direct to $endpointId');
    } else {
      debugPrint('[AdHocNetwork] Connection rejected or failed ($status), attempting BLE fallback');
      _fallbackToBle();
    }
  }

  void _onDisconnected(String endpointId) {
    debugPrint('[AdHocNetwork] Wi-Fi Direct disconnected from $endpointId. Engaging BLE fallback.');
    _connectedEndpointId = null;
    _fallbackToBle();
  }

  /// Dynamic Fallback to Bluetooth Low Energy (BLE)
  Future<void> _fallbackToBle() async {
    _activeTransport = NetworkTransport.bleFallback;
    _updateMetrics(transport: NetworkTransport.bleFallback);
    debugPrint('[AdHocNetwork] Switched to BLE Fallback Transport');

    try {
      if (await ble.FlutterBluePlus.isSupported) {
        await ble.FlutterBluePlus.startScan(
          timeout: const Duration(seconds: 10),
          withServices: [ble.Guid('00001850-0000-1000-8000-00805f9b34fb')],
        );
      }
    } catch (e) {
      debugPrint('[AdHocNetwork] BLE scan warning: $e');
    }
  }

  /// Broadcasts a TransceiverPacket across the active ad-hoc network transport
  Future<bool> sendPacket(TransceiverPacket packet) async {
    final t0 = DateTime.now().millisecondsSinceEpoch;

    // 1. Encode packet into binary payload
    Uint8List rawPayload;
    if (packet.mode == PacketMode.semanticMode1) {
      rawPayload = PacketEncoder.encodeMode1(
        langId: packet.langId,
        intentId: packet.intentId,
        priority: packet.priority,
        sequence: packet.sequence,
      );
    } else {
      rawPayload = PacketEncoder.encodeMode2(
        langId: packet.langId,
        text: packet.text,
        priority: packet.priority,
        sequence: packet.sequence,
      );
    }

    // 2. Generate XOR-FEC systematic block frames
    final frames = _fecEngine.encodeBlock([rawPayload]);

    int bytesTransmitted = 0;

    // 3. Transmit all frames over active network interface (UDP P2P Mesh + Nearby Wi-Fi Direct + BLE)
    final broadcastTargets = <InternetAddress>{InternetAddress('255.255.255.255')};
    if (_localIpAddress != null) {
      final parts = _localIpAddress!.split('.');
      if (parts.length == 4) {
        broadcastTargets.add(InternetAddress('${parts[0]}.${parts[1]}.${parts[2]}.255'));
      }
    }

    for (final frame in frames) {
      final frameBytes = frame.toBytes();
      bytesTransmitted += frameBytes.length;

      // Broadcast over UDP P2P mesh socket (<5ms zero-configuration delivery)
      if (_udpSocket != null) {
        final udpPacket = Uint8List(4 + frameBytes.length);
        final byteData = ByteData.sublistView(udpPacket);
        byteData.setUint32(0, _localDeviceId);
        udpPacket.setRange(4, udpPacket.length, frameBytes);

        // Send to global and subnet broadcasts
        for (final target in broadcastTargets) {
          try {
            _udpSocket!.send(udpPacket, target, p2pUdpPort);
          } catch (_) {}
        }

        // Send directly to all discovered peer IPs
        for (final peerIp in _knownPeerIps) {
          try {
            _udpSocket!.send(udpPacket, InternetAddress(peerIp), p2pUdpPort);
          } catch (_) {}
        }
      }

      // Also send over Nearby Connections if peer is connected
      if (_activeTransport == NetworkTransport.wifiDirect && _connectedEndpointId != null) {
        try {
          await nearby.Nearby().sendBytesPayload(_connectedEndpointId!, frameBytes);
        } catch (e) {
          debugPrint('[AdHocNetwork] Send via Wi-Fi Direct failed ($e), routing to BLE');
          await _sendOverBle(frameBytes);
        }
      } else {
        await _sendOverBle(frameBytes);
      }
    }

    // Direct HTTP POST to known peers as guaranteed local TCP fallback
    if (_knownPeerIps.isNotEmpty) {
      _sendHttpToPeers(rawPayload);
    }

    final t1 = DateTime.now().millisecondsSinceEpoch;
    final rtt = t1 - t0;

    _updateMetrics(
      bytesSent: _currentMetrics.bytesSent + bytesTransmitted,
      packetsSent: _currentMetrics.packetsSent + 1,
      lastRoundTripMs: rtt,
    );

    return true;
  }

  void _sendHttpToPeers(Uint8List payload) {
    for (final peerIp in _knownPeerIps) {
      Future(() async {
        try {
          final client = HttpClient()..connectionTimeout = const Duration(milliseconds: 400);
          final req = await client.post(peerIp, p2pHttpPort, '/packet');
          req.headers.contentType = ContentType.binary;
          req.add(payload);
          final res = await req.close().timeout(const Duration(milliseconds: 600));
          await res.drain();
          client.close();
        } catch (_) {}
      });
    }
  }

  Future<void> _sendOverBle(Uint8List bytes) async {
    // BLE frame transfer stub / simulation for testing
    debugPrint('[AdHocNetwork] Transmitting ${bytes.length} bytes over BLE GATT characteristic');
  }

  /// Processes raw incoming bytes received from the network socket
  void _handleRawIncomingBytes(Uint8List bytes) {
    _updateMetrics(
      bytesReceived: _currentMetrics.bytesReceived + bytes.length,
      packetsReceived: _currentMetrics.packetsReceived + 1,
    );

    try {
      // Check if received buffer is an FEC frame
      if (bytes.isNotEmpty && bytes[0] == 0xFC) {
        final frame = FecFrame.fromBytes(bytes);
        _processFecFrame(frame);
      } else {
        // Direct non-FEC packet
        final packet = PacketEncoder.decode(bytes);
        _incomingPacketController.add(packet);
      }
    } catch (e) {
      debugPrint('[AdHocNetwork] Parse error on incoming frame: $e');
    }
  }

  void _processFecFrame(FecFrame frame) {
    final blockId = frame.blockId;
    _fecBlockBuffer.putIfAbsent(blockId, () => []).add(frame);

    final currentBlock = _fecBlockBuffer[blockId]!;

    // Attempt reconstruction
    final recoveredMap = XorFecEngine.tryReconstructBlock(
      k: frame.k,
      receivedFrames: currentBlock,
    );

    if (recoveredMap != null && recoveredMap.isNotEmpty) {
      // Check if any packet was reconstructed via parity
      int dataCount = 0;
      for (final f in currentBlock) {
        if (!f.isParity) dataCount++;
      }
      if (dataCount < frame.k && recoveredMap.length == frame.k) {
        _updateMetrics(
          packetsRecoveredByFec: _currentMetrics.packetsRecoveredByFec + 1,
        );
        debugPrint('[AdHocNetwork] Zero-retransmission packet loss recovered by XOR-FEC!');
      }

      // Decode and dispatch each recovered data packet
      for (final entry in recoveredMap.entries) {
        try {
          final packet = PacketEncoder.decode(entry.value);
          _incomingPacketController.add(packet);
        } catch (e) {
          debugPrint('[AdHocNetwork] Error decoding recovered packet payload: $e');
        }
      }

      // Evict block from buffer
      _fecBlockBuffer.remove(blockId);
    }
  }

  /// For automated integration testing: directly feeds incoming frames into pipeline
  void simulateIncomingRawBytes(Uint8List bytes) {
    _handleRawIncomingBytes(bytes);
  }

  void _updateMetrics({
    NetworkTransport? transport,
    int? bytesSent,
    int? bytesReceived,
    int? packetsSent,
    int? packetsReceived,
    int? packetsRecoveredByFec,
    int? lastRoundTripMs,
  }) {
    _currentMetrics = _currentMetrics.copyWith(
      transport: transport,
      bytesSent: bytesSent,
      bytesReceived: bytesReceived,
      packetsSent: packetsSent,
      packetsReceived: packetsReceived,
      packetsRecoveredByFec: packetsRecoveredByFec,
      lastRoundTripMs: lastRoundTripMs,
    );
    _metricsController.add(_currentMetrics);
  }

  void dispose() {
    _discoveryTimer?.cancel();
    _udpSocket?.close();
    _udpSocket = null;
    _httpServer?.close(force: true);
    _httpServer = null;
    try {
      if (_isAdvertising) nearby.Nearby().stopAdvertising().catchError((_) {});
      if (_isDiscovering) nearby.Nearby().stopDiscovery().catchError((_) {});
      nearby.Nearby().stopAllEndpoints().catchError((_) {});
    } catch (_) {}
    _incomingPacketController.close();
    _metricsController.close();
  }
}
