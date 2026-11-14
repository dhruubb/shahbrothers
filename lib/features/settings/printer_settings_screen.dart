import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/common.dart';
import '../../data/models/models.dart';
import '../../domain/exceptions.dart';
import '../../providers/providers.dart';
import '../printing/escpos.dart';
import '../printing/printer_service.dart';

class PrinterSettingsScreen extends ConsumerStatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  ConsumerState<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends ConsumerState<PrinterSettingsScreen> {
  PrinterConfig? _config;
  final _host = TextEditingController();
  final _port = TextEditingController(text: '9100');
  List<BluetoothPrinterDevice>? _devices;
  bool _scanning = false;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    ref.read(printerServiceProvider).load().then((c) {
      if (!mounted) return;
      setState(() {
        _config = c;
        _host.text = c.host ?? '';
        _port.text = '${c.port}';
      });
    });
  }

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    setState(() => _scanning = true);
    try {
      final list = await ref.read(printerServiceProvider).pairedBluetoothPrinters();
      if (mounted) setState(() => _devices = list);
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  PrinterConfig get _current => _config!.copyWith(host: _host.text.trim(), port: int.tryParse(_port.text) ?? 9100);

  Future<void> _save({bool quiet = false}) async {
    await ref.read(printerServiceProvider).save(_current);
    ref.invalidate(printerConfigProvider);
    if (mounted && !quiet) showSnack(context, 'Printer saved');
  }

  Future<void> _test() async {
    setState(() => _testing = true);
    try {
      await _save(quiet: true);
      final settings = ref.read(settingsProvider).valueOrNull ?? const AppSettings();
      await ref.read(printerServiceProvider).printBytes(_current, buildTestPage(settings, _current.paper));
      if (mounted) showSnack(context, 'Test page sent');
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _config;
    return Scaffold(
      appBar: AppBar(title: const Text('Receipt printer')),
      body: c == null
          ? const LoadingView(blocks: 3)
          : MaxWidth(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  Text('ESC/POS thermal printers (58 mm or 80 mm) over Bluetooth or Wi-Fi.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.inkMuted)),
                  const SizedBox(height: 14),
                  SegmentedButton<PrinterConnection>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: PrinterConnection.bluetooth, label: Text('Bluetooth'), icon: Icon(Icons.bluetooth_rounded)),
                      ButtonSegment(value: PrinterConnection.network, label: Text('Wi-Fi / LAN'), icon: Icon(Icons.wifi_rounded)),
                      ButtonSegment(value: PrinterConnection.none, label: Text('None')),
                    ],
                    selected: {c.connection},
                    onSelectionChanged: (s) => setState(() => _config = c.copyWith(connection: s.first)),
                  ),
                  const SizedBox(height: 16),
                  Text('Paper width', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  SegmentedButton<PaperWidth>(
                    showSelectedIcon: false,
                    segments: [for (final p in PaperWidth.values) ButtonSegment(value: p, label: Text('${p.label} · ${p.chars} cols'))],
                    selected: {c.paper},
                    onSelectionChanged: (s) => setState(() => _config = c.copyWith(paper: s.first)),
                  ),
                  const SizedBox(height: 20),
                  if (c.connection == PrinterConnection.bluetooth) ...[
                    AppCard(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          const Icon(Icons.bluetooth_connected_rounded, color: AppColors.maroon),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(c.bluetoothName ?? 'No printer selected', style: const TextStyle(fontWeight: FontWeight.w700)),
                          ),
                          TextButton.icon(
                            onPressed: _scanning ? null : _scan,
                            icon: _scanning
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.search_rounded),
                            label: const Text('Find'),
                          ),
                        ]),
                        if (c.bluetoothAddress != null)
                          Text(c.bluetoothAddress!, style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 6),
                        Text('Pair the printer in your phone\'s Bluetooth settings first, then tap Find.',
                            style: Theme.of(context).textTheme.bodySmall),
                        if (_devices != null) ...[
                          const Divider(height: 20),
                          if (_devices!.isEmpty) const Text('No paired devices found.'),
                          for (final d in _devices!)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.print_outlined),
                              title: Text(d.name.isEmpty ? 'Unnamed device' : d.name),
                              subtitle: Text(d.address),
                              trailing: c.bluetoothAddress == d.address ? const Icon(Icons.check_circle_rounded, color: AppColors.success) : null,
                              onTap: () => setState(() => _config = c.copyWith(bluetoothAddress: d.address, bluetoothName: d.name)),
                            ),
                        ],
                      ]),
                    ),
                  ],
                  if (c.connection == PrinterConnection.network) ...[
                    Row(children: [
                      Expanded(
                        flex: 3,
                        child: AppTextField(
                          controller: _host,
                          label: 'Printer IP address',
                          hint: '192.168.1.50',
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppTextField(
                          controller: _port,
                          label: 'Port',
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        ),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    Text('The phone and printer must be on the same Wi-Fi network. Most printers use port 9100.',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                  const SizedBox(height: 24),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _testing || c.connection == PrinterConnection.none ? null : _test,
                        icon: _testing
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.receipt_outlined),
                        label: const Text('Test print'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: FilledButton(onPressed: () => _save(), child: const Text('Save'))),
                  ]),
                  const SizedBox(height: 16),
                  Text(
                    'No thermal printer? Open any invoice and use "PDF / Share" to print on a regular printer or send it on WhatsApp.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
    );
  }
}
