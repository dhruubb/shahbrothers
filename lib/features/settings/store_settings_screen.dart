import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/common.dart';
import '../../data/models/models.dart';
import '../../domain/exceptions.dart';
import '../../providers/providers.dart';

class StoreSettingsScreen extends ConsumerStatefulWidget {
  const StoreSettingsScreen({super.key});

  @override
  ConsumerState<StoreSettingsScreen> createState() => _StoreSettingsScreenState();
}

class _StoreSettingsScreenState extends ConsumerState<StoreSettingsScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _tagline = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _gstin = TextEditingController();
  final _gst = TextEditingController();
  final _prefix = TextEditingController();
  final _footer = TextEditingController();
  AppSettings? _original;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _tagline, _address, _phone, _email, _gstin, _gst, _prefix, _footer]) {
      c.dispose();
    }
    super.dispose();
  }

  void _load(AppSettings s) {
    _original = s;
    _name.text = s.storeName;
    _tagline.text = s.tagline ?? '';
    _address.text = s.address ?? '';
    _phone.text = s.phone ?? '';
    _email.text = s.email ?? '';
    _gstin.text = s.gstin ?? '';
    _gst.text = s.gstRate == s.gstRate.roundToDouble() ? s.gstRate.toStringAsFixed(0) : s.gstRate.toString();
    _prefix.text = s.invoicePrefix;
    _footer.text = s.invoiceFooter ?? '';
  }

  String? _nullIfEmpty(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final gst = double.parse(_gst.text.trim());
    if (gst != _original!.gstRate) {
      final ok = await confirmDialog(context,
          title: 'Change GST to $gst%?',
          message: 'New bills will use $gst%. Existing invoices keep the rate they were billed at.',
          confirm: 'Change GST');
      if (!ok) return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(repositoryProvider).updateSettings(AppSettings(
            storeName: _name.text.trim(),
            tagline: _nullIfEmpty(_tagline),
            address: _nullIfEmpty(_address),
            phone: _nullIfEmpty(_phone),
            email: _nullIfEmpty(_email),
            gstin: _nullIfEmpty(_gstin)?.toUpperCase(),
            gstRate: gst,
            invoicePrefix: _prefix.text.trim().toUpperCase(),
            invoiceFooter: _nullIfEmpty(_footer),
          ));
      ref.refreshData();
      if (!mounted) return;
      showSnack(context, 'Settings saved');
      context.pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showSnack(context, friendlyError(e), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    if (_original == null && settings.hasValue) _load(settings.value!);

    return Scaffold(
      appBar: AppBar(title: const Text('Store & GST')),
      body: _original == null
          ? AsyncView<AppSettings>(value: settings, builder: (_) => const SizedBox.shrink())
          : Form(
              key: _form,
              child: MaxWidth(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    const SectionHeader('GST', padding: EdgeInsets.fromLTRB(4, 4, 4, 10)),
                    Row(children: [
                      Expanded(
                        child: AppTextField(
                          controller: _gst,
                          label: 'GST rate',
                          helperText: 'Split equally as CGST + SGST',
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                          suffixIcon: const Padding(padding: EdgeInsets.all(14), child: Text('%')),
                          validator: (v) {
                            final d = double.tryParse(v ?? '');
                            if (d == null || d < 0 || d > 28) return '0–28';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppTextField(
                          controller: _prefix,
                          label: 'Invoice prefix',
                          helperText: 'e.g. SB → SB/26-27/00001',
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                            LengthLimitingTextInputFormatter(6)
                          ],
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, children: [
                      for (final r in [0, 5, 12, 18])
                        ActionChip(label: Text('$r%'), onPressed: () => setState(() => _gst.text = '$r')),
                    ]),
                    const SizedBox(height: 4),
                    Text('Sarees are generally taxed at 5%. Check with your accountant for your products.',
                        style: Theme.of(context).textTheme.bodySmall),
                    const SectionHeader('Store details (printed on invoices)'),
                    AppTextField(controller: _name, label: 'Store name', validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null),
                    const SizedBox(height: 12),
                    AppTextField(controller: _tagline, label: 'Tagline'),
                    const SizedBox(height: 12),
                    AppTextField(controller: _address, label: 'Address', maxLines: 2),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: AppTextField(controller: _phone, label: 'Phone', keyboardType: TextInputType.phone)),
                      const SizedBox(width: 12),
                      Expanded(child: AppTextField(controller: _email, label: 'Email', keyboardType: TextInputType.emailAddress)),
                    ]),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _gstin,
                      label: 'GSTIN',
                      textCapitalization: TextCapitalization.characters,
                      validator: (v) {
                        final t = (v ?? '').trim();
                        if (t.isEmpty) return null;
                        return RegExp(r'^[0-9]{2}[A-Za-z0-9]{13}$').hasMatch(t) ? null : 'GSTIN has 15 characters';
                      },
                    ),
                    const SizedBox(height: 12),
                    AppTextField(controller: _footer, label: 'Invoice footer', maxLines: 3, hint: 'Exchange policy, thank-you note…'),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.ivory))
                          : const Text('Save settings'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
