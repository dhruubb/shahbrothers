import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/common.dart';
import '../../data/models/models.dart';
import '../../domain/exceptions.dart';
import '../../providers/providers.dart';

class CustomerFormScreen extends ConsumerStatefulWidget {
  const CustomerFormScreen({super.key, this.customerId});
  final String? customerId;

  @override
  ConsumerState<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends ConsumerState<CustomerFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _city = TextEditingController();
  final _notes = TextEditingController();
  Customer? _original;
  DateTime? _dob;
  DateTime? _anniversary;
  String _language = 'en';
  ContactChannel _channel = ContactChannel.none;
  bool _consent = false;
  String _consentSource = 'in_store_verbal';
  bool _whatsapp = false, _sms = false, _emailOpt = false, _telegram = false;
  Set<String> _tags = {};
  bool _loaded = false;
  bool _saving = false;

  static const _languages = {'en': 'English', 'hi': 'Hindi', 'mr': 'Marathi', 'gu': 'Gujarati'};
  static const _sources = {'in_store_verbal': 'Verbal, in store', 'signed_form': 'Signed form', 'app': 'In app'};
  static const _tagOptions = ['bridal', 'festive', 'silk-lover', 'regular', 'corporate', 'wholesale'];

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _city, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  void _load(Customer c) {
    _original = c;
    _name.text = c.name;
    _phone.text = c.phone;
    _email.text = c.email ?? '';
    _city.text = c.city ?? '';
    _notes.text = c.notes ?? '';
    _dob = c.dateOfBirth;
    _anniversary = c.anniversary;
    _language = c.preferredLanguage;
    _channel = c.preferredChannel;
    _consent = c.marketingConsent;
    _consentSource = c.marketingConsentSource ?? 'in_store_verbal';
    _whatsapp = c.whatsappOptIn;
    _sms = c.smsOptIn;
    _emailOpt = c.emailOptIn;
    _telegram = c.telegramOptIn;
    _tags = {...c.tags};
  }

  Future<void> _pickDate(bool dob) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime(1930),
      lastDate: now,
      initialDate: (dob ? _dob : _anniversary) ?? DateTime(now.year - (dob ? 30 : 5)),
    );
    if (d == null) return;
    setState(() {
      if (dob) {
        _dob = d;
      } else {
        _anniversary = d;
      }
    });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final c = Customer(
      id: _original?.id ?? '',
      name: _name.text.trim(),
      phone: Validators.normalizePhone(_phone.text),
      email: _email.text.trim().isEmpty ? null : _email.text.trim(),
      city: _city.text.trim().isEmpty ? null : _city.text.trim(),
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      dateOfBirth: _dob,
      anniversary: _anniversary,
      preferredLanguage: _language,
      preferredChannel: _channel,
      marketingConsent: _consent,
      marketingConsentAt: _consent ? (_original?.marketingConsentAt ?? DateTime.now()) : null,
      marketingConsentSource: _consent ? _consentSource : null,
      whatsappOptIn: _consent && _whatsapp,
      smsOptIn: _consent && _sms,
      emailOptIn: _consent && _emailOpt,
      telegramOptIn: _consent && _telegram,
      tags: _tags.toList(),
      createdAt: _original?.createdAt,
    );
    try {
      final saved = await ref.read(repositoryProvider).saveCustomer(c);
      ref.refreshData();
      if (!mounted) return;
      showSnack(context, _original == null ? 'Customer added' : 'Customer updated');
      if (_original == null) {
        context.pushReplacement('/customers/${saved.id}');
      } else {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showSnack(context, friendlyError(e), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.customerId != null;
    if (editing && !_loaded) {
      final list = ref.watch(customersProvider).valueOrNull;
      final c = list?.where((x) => x.id == widget.customerId).firstOrNull;
      if (c == null) {
        return Scaffold(appBar: AppBar(), body: const LoadingView(blocks: 3));
      }
      _load(c);
      _loaded = true;
    }

    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit customer' : 'New customer')),
      body: Form(
        key: _form,
        child: MaxWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              AppTextField(
                controller: _name,
                label: 'Full name',
                prefixIcon: Icons.person_outline_rounded,
                textCapitalization: TextCapitalization.words,
                validator: (v) => Validators.required(v, 'Name'),
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _phone,
                label: 'Mobile number',
                prefixText: '+91 ',
                prefixIcon: Icons.phone_iphone_rounded,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                validator: Validators.mobile,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _email,
                label: 'Email (optional)',
                prefixIcon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                validator: (v) => Validators.email(v),
              ),
              const SizedBox(height: 12),
              AppTextField(controller: _city, label: 'Area / city', prefixIcon: Icons.place_outlined, textCapitalization: TextCapitalization.words),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _DateField(label: 'Birthday', value: _dob, onTap: () => _pickDate(true), onClear: () => setState(() => _dob = null))),
                const SizedBox(width: 12),
                Expanded(
                  child: _DateField(
                      label: 'Anniversary', value: _anniversary, onTap: () => _pickDate(false), onClear: () => setState(() => _anniversary = null)),
                ),
              ]),
              const SizedBox(height: 12),
              AppDropdown<String>(
                label: 'Preferred language',
                value: _language,
                items: _languages.keys.toList(),
                itemLabel: (k) => _languages[k]!,
                onChanged: (v) => setState(() => _language = v ?? 'en'),
              ),
              const SizedBox(height: 14),
              Text('Tags', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 6, children: [
                for (final t in _tagOptions)
                  FilterChip(
                    label: Text(t),
                    selected: _tags.contains(t),
                    onSelected: (s) => setState(() => s ? _tags.add(t) : _tags.remove(t)),
                  ),
              ]),
              const SizedBox(height: 12),
              AppTextField(controller: _notes, label: 'Notes', maxLines: 3, hint: 'Preferences, measurements, occasions…'),
              const SectionHeader('Marketing consent'),
              AppCard(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SwitchListTile(
                    value: _consent,
                    onChanged: (v) => setState(() => _consent = v),
                    title: const Text('Customer agrees to receive offers & updates', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Only switch on when the customer has clearly said yes.'),
                  ),
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 220),
                    crossFadeState: _consent ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                    secondChild: const SizedBox(width: double.infinity),
                    firstChild: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const SizedBox(height: 6),
                        AppDropdown<String>(
                          label: 'How was consent given?',
                          value: _consentSource,
                          items: _sources.keys.toList(),
                          itemLabel: (k) => _sources[k]!,
                          onChanged: (v) => setState(() => _consentSource = v ?? 'in_store_verbal'),
                        ),
                        const SizedBox(height: 12),
                        AppDropdown<ContactChannel>(
                          label: 'Preferred channel',
                          value: _channel,
                          items: ContactChannel.values,
                          itemLabel: (c) => c.label,
                          onChanged: (v) => setState(() => _channel = v ?? ContactChannel.none),
                        ),
                        const SizedBox(height: 10),
                        Text('Allowed channels', style: Theme.of(context).textTheme.labelLarge),
                        Wrap(spacing: 8, runSpacing: 6, children: [
                          FilterChip(label: const Text('WhatsApp'), selected: _whatsapp, onSelected: (v) => setState(() => _whatsapp = v)),
                          FilterChip(label: const Text('SMS'), selected: _sms, onSelected: (v) => setState(() => _sms = v)),
                          FilterChip(label: const Text('Email'), selected: _emailOpt, onSelected: (v) => setState(() => _emailOpt = v)),
                          FilterChip(label: const Text('Telegram'), selected: _telegram, onSelected: (v) => setState(() => _telegram = v)),
                        ]),
                      ]),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.ivory))
                    : Text(editing ? 'Save changes' : 'Add customer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.value, required this.onTap, required this.onClear});
  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: InputDecorator(
        decoration: AppTheme.input(
          label: label,
          dense: true,
          suffixIcon: value != null
              ? IconButton(icon: const Icon(Icons.close_rounded, size: 18), onPressed: onClear)
              : const Icon(Icons.event_outlined, size: 20),
        ),
        isEmpty: value == null,
        child: Text(value == null ? '' : Dates.day(value!)),
      ),
    );
  }
}
