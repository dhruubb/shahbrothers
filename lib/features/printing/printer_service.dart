import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/exceptions.dart';
import 'escpos.dart';

enum PrinterConnection {
  none('Not set up'),
  bluetooth('Bluetooth'),
  network('Wi-Fi / LAN');

  const PrinterConnection(this.label);
  final String label;
}

class PrinterConfig {
  const PrinterConfig({
    this.connection = PrinterConnection.none,
    this.paper = PaperWidth.mm58,
    this.bluetoothAddress,
    this.bluetoothName,
    this.host,
    this.port = 9100,
  });

  final PrinterConnection connection;
  final PaperWidth paper;
  final String? bluetoothAddress;
  final String? bluetoothName;
  final String? host;
  final int port;

  bool get isConfigured => switch (connection) {
        PrinterConnection.none => false,
        PrinterConnection.bluetooth => (bluetoothAddress ?? '').isNotEmpty,
        PrinterConnection.network => (host ?? '').isNotEmpty,
      };

  String get summary => switch (connection) {
        PrinterConnection.none => 'No printer set up',
        PrinterConnection.bluetooth => '${bluetoothName ?? bluetoothAddress ?? 'Bluetooth'} · ${paper.label}',
        PrinterConnection.network => '$host:$port · ${paper.label}',
      };

  PrinterConfig copyWith({
    PrinterConnection? connection,
    PaperWidth? paper,
    String? bluetoothAddress,
    String? bluetoothName,
    String? host,
    int? port,
  }) =>
      PrinterConfig(
        connection: connection ?? this.connection,
        paper: paper ?? this.paper,
        bluetoothAddress: bluetoothAddress ?? this.bluetoothAddress,
        bluetoothName: bluetoothName ?? this.bluetoothName,
        host: host ?? this.host,
        port: port ?? this.port,
      );
}

class BluetoothPrinterDevice {
  const BluetoothPrinterDevice(this.name, this.address);
  final String name;
  final String address;
}

/// Sends ESC/POS bytes to a Bluetooth or network thermal printer.
class PrinterService {
  static const _kConn = 'printer.connection';
  static const _kPaper = 'printer.paper';
  static const _kBtAddr = 'printer.bt.address';
  static const _kBtName = 'printer.bt.name';
  static const _kHost = 'printer.host';
  static const _kPort = 'printer.port';

  Future<PrinterConfig> load() async {
    final p = await SharedPreferences.getInstance();
    return PrinterConfig(
      connection: PrinterConnection.values.firstWhere((e) => e.name == p.getString(_kConn),
          orElse: () => PrinterConnection.none),
      paper: PaperWidth.values.firstWhere((e) => e.name == p.getString(_kPaper), orElse: () => PaperWidth.mm58),
      bluetoothAddress: p.getString(_kBtAddr),
      bluetoothName: p.getString(_kBtName),
      host: p.getString(_kHost),
      port: p.getInt(_kPort) ?? 9100,
    );
  }

  Future<void> save(PrinterConfig c) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kConn, c.connection.name);
    await p.setString(_kPaper, c.paper.name);
    if (c.bluetoothAddress != null) await p.setString(_kBtAddr, c.bluetoothAddress!);
    if (c.bluetoothName != null) await p.setString(_kBtName, c.bluetoothName!);
    if (c.host != null) await p.setString(_kHost, c.host!);
    await p.setInt(_kPort, c.port);
  }

  /// Paired Bluetooth printers (Android: classic paired devices; iOS: BLE).
  Future<List<BluetoothPrinterDevice>> pairedBluetoothPrinters() async {
    final enabled = await PrintBluetoothThermal.bluetoothEnabled;
    if (!enabled) throw const AppException('Turn on Bluetooth and pair the printer first.');
    final list = await PrintBluetoothThermal.pairedBluetooths;
    return list.map((d) => BluetoothPrinterDevice(d.name, d.macAdress)).toList();
  }

  Future<void> printBytes(PrinterConfig config, List<int> bytes) async {
    switch (config.connection) {
      case PrinterConnection.none:
        throw const AppException('Set up a printer first (Settings → Printer).');
      case PrinterConnection.bluetooth:
        await _printBluetooth(config, bytes);
      case PrinterConnection.network:
        await _printNetwork(config, bytes);
    }
  }

  Future<void> _printBluetooth(PrinterConfig config, List<int> bytes) async {
    final address = config.bluetoothAddress;
    if (address == null || address.isEmpty) throw const AppException('Choose a Bluetooth printer first.');
    if (!await PrintBluetoothThermal.bluetoothEnabled) {
      throw const AppException('Bluetooth is off. Turn it on and try again.');
    }
    var connected = await PrintBluetoothThermal.connectionStatus;
    if (!connected) {
      connected = await PrintBluetoothThermal.connect(macPrinterAddress: address)
          .timeout(const Duration(seconds: 12), onTimeout: () => false);
    }
    if (!connected) {
      throw AppException('Could not connect to ${config.bluetoothName ?? 'the printer'}. Is it on and nearby?');
    }
    final ok = await PrintBluetoothThermal.writeBytes(bytes);
    if (!ok) throw const AppException('The printer did not accept the data. Try again.');
  }

  Future<void> _printNetwork(PrinterConfig config, List<int> bytes) async {
    final host = config.host;
    if (host == null || host.isEmpty) throw const AppException('Enter the printer IP address first.');
    Socket? socket;
    try {
      socket = await Socket.connect(host, config.port, timeout: const Duration(seconds: 6));
      socket.add(bytes);
      await socket.flush();
    } on SocketException catch (e) {
      throw AppException('Could not reach the printer at $host:${config.port} (${e.osError?.message ?? e.message}).');
    } finally {
      await socket?.close();
    }
  }
}

final printerServiceProvider = Provider<PrinterService>((ref) => PrinterService());

final printerConfigProvider = FutureProvider<PrinterConfig>((ref) => ref.watch(printerServiceProvider).load());
