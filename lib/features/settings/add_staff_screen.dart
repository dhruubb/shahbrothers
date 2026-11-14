import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/money.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/common.dart';
import '../../data/models/models.dart';
import '../../data/repositories/data_repository.dart';
import '../../domain/exceptions.dart';
import '../../providers/providers.dart';

class AddStaffScreen extends ConsumerStatefulWidget {
  const AddStaffScreen({super.key});

  @override
  ConsumerState<AddStaffScreen> createState() => _AddStaffScreenState();
}

class _AddStaffScreenState extends ConsumerState<AddStaffScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _target = TextEditingController(text: '100000');
  UserRole _role = UserRole.salesperson;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _password, _target]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(repositoryProvider).addStaff(NewStaffInput(
            fullName: _name.text.trim(),
            email: _email.text.trim(),
            password: _password.text,
            role: _role,
            phone: _phone.text.trim().isEmpty ? null : Validators.normalizePhone(_phone.text),
            monthlyTargetPaise: _role == UserRole.salesperson ? (Money.parse(_target.text) ?? 0) : 0,
          ));
      ref.refreshData();
      if (!mounted) return;
      showSnack(context, '${_name.text.trim()} can now sign in');
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
    final repo = ref.watch(repositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Add staff')),
      body: !repo.isDemoMode
          ? const EmptyState(
              icon: Icons.admin_panel_settings_outlined,
              title: 'Create the login in Supabase',
              message: 'In the Supabase dashboard, go to Authentication → Users → Add user, then set the user\'s '
                  'app_metadata to {"role": "salesperson"} (or "manager"). The person appears in Team automatically. '
                  'See README → Adding staff.',
            )
          : Form(
              key: _form,
              child: MaxWidth(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    SegmentedButton<UserRole>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: UserRole.salesperson, label: Text('Salesperson')),
                        ButtonSegment(value: UserRole.manager, label: Text('Manager')),
                      ],
                      selected: {_role},
                      onSelectionChanged: (s) => setState(() => _role = s.first),
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _name,
                      label: 'Full name',
                      textCapitalization: TextCapitalization.words,
                      validator: (v) => Validators.required(v, 'Name'),
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _email,
                      label: 'Email (used to sign in)',
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => Validators.email(v, optional: false),
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _phone,
                      label: 'Mobile (optional)',
                      prefixText: '+91 ',
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                      validator: (v) => (v == null || v.isEmpty) ? null : Validators.mobile(v),
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _password,
                      label: 'Temporary password',
                      validator: (v) => (v == null || v.length < 6) ? 'At least 6 characters' : null,
                    ),
                    if (_role == UserRole.salesperson) ...[
                      const SizedBox(height: 12),
                      AppTextField(
                        controller: _target,
                        label: 'Monthly target (net sales)',
                        prefixText: '₹ ',
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.ivory))
                          : const Text('Add staff member'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
