import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/common.dart';
import '../../data/models/models.dart';
import '../../data/repositories/data_repository.dart';
import '../../domain/exceptions.dart';
import '../../providers/providers.dart';

final demoCredentialsProvider = FutureProvider<List<DemoCredential>>(
  (ref) => ref.read(repositoryProvider).demoCredentials(),
);

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).signIn(_email.text, _password.text);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _fill(DemoCredential c) {
    setState(() {
      _email.text = c.email;
      _password.text = c.password;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repositoryProvider);
    final creds = ref.watch(demoCredentialsProvider);
    final topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: AppColors.ivory,
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          children: [
            // Brand header
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(24, topInset + 36, 24, 0),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.maroon, AppColors.maroon900],
                ),
              ),
              child: const Column(
                children: [
                  BrandMark(size: 76, onDark: true),
                  SizedBox(height: 16),
                  BrandWordmark(onDark: true, size: 32),
                  SizedBox(height: 30),
                  ZariBorder(height: 14, opacity: 0.7),
                ],
              ),
            ),
            MaxWidth(
              width: 520,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Welcome back', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 4),
                    Text('Sign in to billing, sales and customer records.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.inkMuted)),
                    const SizedBox(height: 20),
                    Form(
                      key: _form,
                      child: AutofillGroup(
                        child: Column(
                          children: [
                            AppTextField(
                              controller: _email,
                              label: 'Email',
                              prefixIcon: Icons.alternate_email_rounded,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.email],
                              validator: (v) => (v == null || !v.contains('@')) ? 'Enter your email' : null,
                            ),
                            const SizedBox(height: 14),
                            AppTextField(
                              controller: _password,
                              label: 'Password',
                              prefixIcon: Icons.lock_outline_rounded,
                              obscureText: _obscure,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.password],
                              onSubmitted: (_) => _submit(),
                              validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
                              suffixIcon: IconButton(
                                tooltip: _obscure ? 'Show password' : 'Hide password',
                                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                onPressed: () => setState(() => _obscure = !_obscure),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      child: _error == null
                          ? const SizedBox(height: 18)
                          : Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: AppColors.errorBg, borderRadius: BorderRadius.circular(12)),
                                child: Row(children: [
                                  const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.error))),
                                ]),
                              ),
                            ),
                    ),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.ivory))
                          : const Text('Sign in'),
                    ),
                    const SizedBox(height: 28),
                    Row(children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('DEMO ACCOUNTS', style: Theme.of(context).textTheme.labelSmall),
                      ),
                      const Expanded(child: Divider()),
                    ]),
                    const SizedBox(height: 6),
                    Text('Tap an account to fill in its details.',
                        textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 12),
                    creds.when(
                      loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
                      error: (e, _) => Text(friendlyError(e)),
                      data: (list) => _DemoAccounts(list: list, onPick: _fill),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: Pill(
                        repo.isDemoMode ? 'Offline demo mode · data stays on this device' : repo.backendLabel,
                        tone: repo.isDemoMode ? PillTone.gold : PillTone.success,
                        icon: repo.isDemoMode ? Icons.phone_android_rounded : Icons.cloud_done_outlined,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DemoAccounts extends StatefulWidget {
  const _DemoAccounts({required this.list, required this.onPick});
  final List<DemoCredential> list;
  final ValueChanged<DemoCredential> onPick;

  @override
  State<_DemoAccounts> createState() => _DemoAccountsState();
}

class _DemoAccountsState extends State<_DemoAccounts> {
  bool _showAll = false;

  static const _icons = {
    UserRole.owner: Icons.workspace_premium_outlined,
    UserRole.manager: Icons.point_of_sale_rounded,
    UserRole.salesperson: Icons.person_pin_outlined,
  };
  static const _blurb = {
    UserRole.owner: 'Analytics, team, bonuses, reports',
    UserRole.manager: 'Billing, customers, printing',
    UserRole.salesperson: 'Own sales, target and bonus',
  };

  @override
  Widget build(BuildContext context) {
    final primary = <DemoCredential>[];
    for (final role in UserRole.values) {
      final c = widget.list.where((c) => c.role == role).firstOrNull;
      if (c != null) primary.add(c);
    }
    final others = widget.list.where((c) => !primary.contains(c)).toList();

    Widget tile(DemoCredential c, {bool compact = false}) => AppCard(
          margin: const EdgeInsets.only(bottom: 10),
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: compact ? 10 : 14),
          onTap: () => widget.onPick(c),
          child: Row(
            children: [
              if (!compact)
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(color: AppColors.goldPale, borderRadius: BorderRadius.circular(12)),
                  child: Icon(_icons[c.role], color: AppColors.maroon, size: 22),
                ),
              if (!compact) const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(compact ? c.name : c.role.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      if (!compact) ...[
                        const SizedBox(width: 8),
                        Text(c.name, style: const TextStyle(color: AppColors.inkMuted, fontSize: 12.5)),
                      ],
                    ]),
                    const SizedBox(height: 2),
                    if (!compact) Text(_blurb[c.role]!, style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 4),
                    Text('${c.email}  ·  ${c.password}',
                        style: const TextStyle(fontSize: 12.5, color: AppColors.maroon, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const Icon(Icons.north_west_rounded, size: 18, color: AppColors.inkSoft),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final c in primary) tile(c),
        if (others.isNotEmpty)
          TextButton.icon(
            onPressed: () => setState(() => _showAll = !_showAll),
            icon: Icon(_showAll ? Icons.expand_less_rounded : Icons.expand_more_rounded),
            label: Text(_showAll ? 'Hide other staff accounts' : 'Show all ${widget.list.length} staff accounts'),
          ),
        if (_showAll) for (final c in others) tile(c, compact: true),
      ],
    );
  }
}
