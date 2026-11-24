// ignore_for_file: experimental_member_use, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/remote.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:stream_channel/stream_channel.dart';

import '../database.dart';

enum NetworkRole {
  server, // Main PC (holds sqlite file + serves client connections)
  client, // Secondary PC (connects to main PC over LAN)
}

class NetworkConfig {
  const NetworkConfig({
    this.role = NetworkRole.server,
    this.serverIp = '127.0.0.1',
    this.port = 4455,
  });

  final NetworkRole role;
  final String serverIp;
  final int port;

  bool get isServer => role == NetworkRole.server;
  bool get isClient => role == NetworkRole.client;

  Map<String, dynamic> toJson() => {
        'role': role.name,
        'serverIp': serverIp,
        'port': port,
      };

  factory NetworkConfig.fromJson(Map<String, dynamic> json) {
    return NetworkConfig(
      role: json['role'] == 'client' ? NetworkRole.client : NetworkRole.server,
      serverIp: json['serverIp'] as String? ?? '127.0.0.1',
      port: json['port'] as int? ?? 4455,
    );
  }

  NetworkConfig copyWith({
    NetworkRole? role,
    String? serverIp,
    int? port,
  }) {
    return NetworkConfig(
      role: role ?? this.role,
      serverIp: serverIp ?? this.serverIp,
      port: port ?? this.port,
    );
  }
}

class NetworkDbService {
  NetworkDbService._();
  static final NetworkDbService instance = NetworkDbService._();

  static const String _configFileName = 'network_config.json';
  static const int defaultPort = 4455;

  NetworkConfig _config = const NetworkConfig();
  NetworkConfig get config => _config;

  HttpServer? _server;
  DriftServer? _driftServer;
  int _connectedClients = 0;
  int get connectedClients => _connectedClients;
  bool get isServerRunning => _server != null;

  /// Loads configuration from local disk.
  Future<NetworkConfig> loadConfig() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File(p.join(dir.path, _configFileName));
      if (await file.exists()) {
        final content = await file.readAsString();
        final map = jsonDecode(content) as Map<String, dynamic>;
        _config = NetworkConfig.fromJson(map);
      } else {
        _config = const NetworkConfig();
      }
    } catch (e) {
      debugPrint('Failed to load network config: $e');
      _config = const NetworkConfig();
    }
    return _config;
  }

  /// Saves configuration to local disk.
  Future<void> saveConfig(NetworkConfig config) async {
    _config = config;
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File(p.join(dir.path, _configFileName));
      await file.writeAsString(jsonEncode(config.toJson()), flush: true);
    } catch (e) {
      debugPrint('Failed to save network config: $e');
    }
  }

  /// Retrieves list of non-loopback local IPv4 addresses.
  Future<List<String>> getLocalIpAddresses() async {
    final ips = <String>[];
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && !ips.contains(addr.address)) {
            ips.add(addr.address);
          }
        }
      }
    } catch (e) {
      debugPrint('Error getting local IP addresses: $e');
    }
    if (ips.isEmpty) {
      ips.add('127.0.0.1');
    }
    return ips;
  }

  /// Starts the embedded Drift + WebSocket server on the main PC.
  Future<void> startServer(AppDatabase db, {int port = defaultPort}) async {
    if (_server != null) return;

    try {
      _driftServer = DriftServer(db.executor);
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      debugPrint('LAN Database Server started on port $port');

      _server!.listen((HttpRequest request) async {
        final path = request.uri.path;

        // Health check / ping endpoint
        if (path == '/ping' || path == '/status') {
          request.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.json
            ..write(jsonEncode({
              'status': 'ok',
              'server': 'Hekal Garage ERP',
              'version': '1.0.0',
              'timestamp': DateTime.now().toIso8601String(),
            }));
          await request.response.close();
          return;
        }

        // WebSocket endpoint for Drift remote client connections
        if (WebSocketTransformer.isUpgradeRequest(request)) {
          try {
            final ws = await WebSocketTransformer.upgrade(request);
            _connectedClients++;
            debugPrint('New client connected. Total clients: $_connectedClients');

            final channel = StreamChannel<Object?>(
              ws,
              ws,
            );

            _driftServer?.serve(channel);

            ws.done.then((_) {
              if (_connectedClients > 0) _connectedClients--;
              debugPrint('Client disconnected. Remaining: $_connectedClients');
            });
          } catch (e) {
            debugPrint('Failed to upgrade WebSocket: $e');
          }
        } else {
          request.response
            ..statusCode = HttpStatus.notFound
            ..write('Hekal Garage ERP Local Server');
          await request.response.close();
        }
      });
    } catch (e) {
      debugPrint('Error starting LAN Database Server: $e');
      _server = null;
      _driftServer = null;
    }
  }

  /// Stops the embedded server.
  Future<void> stopServer() async {
    try {
      await _server?.close(force: true);
    } catch (_) {}
    _server = null;
    _driftServer = null;
    _connectedClients = 0;
  }

  /// Tests connection to a remote server.
  Future<bool> testConnection(String host, int port) async {
    final cleanHost = host.trim();
    if (cleanHost.isEmpty) return false;

    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
      final uri = Uri.parse('http://$cleanHost:$port/ping');
      final req = await client.getUrl(uri);
      final resp = await req.close();
      return resp.statusCode == HttpStatus.ok;
    } catch (e) {
      debugPrint('Test connection failed to $cleanHost:$port -> $e');
      return false;
    } finally {
      client?.close();
    }
  }
}

