import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/exceptions.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Rounded ivory card with a hairline border.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color = AppColors.card,
    this.margin,
    this.borderColor = AppColors.border,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color color;
  final EdgeInsetsGeometry? margin;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(18);
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Material(
        color: color,
        shape: RoundedRectangleBorder(borderRadius: radius, side: BorderSide(color: borderColor)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
      ),
    );
  }
}

/// Small uppercase heading with optional action.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction, this.padding});

  final String title;
  final String? action;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(4, 22, 4, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 19)),
          ),
          if (action != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              child: Text(action!),
            ),
        ],
      ),
    );
  }
}

/// Number styled with tabular figures.
class MoneyText extends StatelessWidget {
  const MoneyText(this.text, {super.key, this.size = 15, this.weight = FontWeight.w600, this.color, this.align});

  final String text;
  final double size;
  final FontWeight weight;
  final Color? color;
  final TextAlign? align;

  @override
  Widget build(BuildContext context) => Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontFamily: AppTheme.sans,
          fontSize: size,
          fontWeight: weight,
          color: color ?? AppColors.ink,
          fontFeatures: AppTheme.tabular,
          letterSpacing: -0.2,
        ),
      );
}

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.caption,
    this.captionColor,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? caption;
  final Color? captionColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: AppColors.goldPale, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 18, color: AppColors.maroon),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: MoneyText(value, size: 21, weight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.labelMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
          if (caption != null) ...[
            const SizedBox(height: 4),
            Text(
              caption!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: captionColor ?? AppColors.inkMuted),
            ),
          ],
        ],
      ),
    );
  }
}

/// Two-column responsive grid of [StatCard]s (three on wide screens).
class StatGrid extends StatelessWidget {
  const StatGrid({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth > 720 ? 4 : (c.maxWidth > 520 ? 3 : 2);
      const gap = 12.0;
      final w = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final child in children) SizedBox(width: w, child: child)],
      );
    });
  }
}

class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar(this.initials, {super.key, this.size = 40, this.highlight = false});

  final String initials;
  final double size;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: highlight ? AppColors.maroon : AppColors.goldPale,
        border: Border.all(color: highlight ? AppColors.gold : AppColors.goldLight, width: 1.2),
      ),
      child: Text(
        initials,
        style: TextStyle(
          fontFamily: AppTheme.serif,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.38,
          color: highlight ? AppColors.goldLight : AppColors.maroon,
        ),
      ),
    );
  }
}

enum PillTone { neutral, success, warning, danger, gold, maroon }

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.tone = PillTone.neutral, this.icon});

  final String text;
  final PillTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      PillTone.neutral => (AppColors.cream, AppColors.inkMuted),
      PillTone.success => (AppColors.successBg, AppColors.success),
      PillTone.warning => (AppColors.warningBg, AppColors.warning),
      PillTone.danger => (AppColors.errorBg, AppColors.error),
      PillTone.gold => (AppColors.goldPale, AppColors.goldDeep),
      PillTone.maroon => (AppColors.maroon100, AppColors.maroon),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 12, color: fg), const SizedBox(width: 4)],
          Text(text, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: fg)),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action, this.onAction});

  final IconData icon;
  final String title;
  final String? message;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(color: AppColors.goldPale, shape: BoxShape.circle),
              child: Icon(icon, size: 30, color: AppColors.maroon),
            ),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(message!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.inkMuted)),
            ],
            if (action != null) ...[
              const SizedBox(height: 18),
              FilledButton(onPressed: onAction, child: Text(action!)),
            ],
          ],
        ),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.cloud_off_rounded,
      title: 'Something went wrong',
      message: friendlyError(error),
      action: onRetry == null ? null : 'Try again',
      onAction: onRetry,
    );
  }
}

/// Shimmering placeholder blocks while data loads.
class LoadingView extends StatefulWidget {
  const LoadingView({super.key, this.blocks = 4});
  final int blocks;

  @override
  State<LoadingView> createState() => _LoadingViewState();
}

class _LoadingViewState extends State<LoadingView> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final color = Color.lerp(AppColors.cream, AppColors.sand, _c.value)!;
        return ListView(
          padding: const EdgeInsets.all(16),
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (var i = 0; i < widget.blocks; i++)
              Container(
                height: i == 0 ? 150 : 84,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(18)),
              ),
          ],
        );
      },
    );
  }
}

/// Renders an [AsyncValue] with consistent loading / error states.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({super.key, required this.value, required this.builder, this.onRetry, this.loading});

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback? onRetry;
  final Widget? loading;

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      data: builder,
      loading: () => loading ?? const LoadingView(),
      error: (e, _) => ErrorView(error: e, onRetry: onRetry),
    );
  }
}

/// Text field with the shared decoration.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.validator,
    this.keyboardType,
    this.prefixIcon,
    this.suffixIcon,
    this.prefixText,
    this.maxLines = 1,
    this.onChanged,
    this.inputFormatters,
    this.textInputAction,
    this.obscureText = false,
    this.autofillHints,
    this.enabled = true,
    this.textCapitalization = TextCapitalization.none,
    this.helperText,
    this.onSubmitted,
    this.focusNode,
    this.autofocus = false,
    this.dense = false,
    this.initialValue,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final String? prefixText;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final Iterable<String>? autofillHints;
  final bool enabled;
  final TextCapitalization textCapitalization;
  final String? helperText;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool dense;
  final String? initialValue;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      initialValue: controller == null ? initialValue : null,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      onChanged: onChanged,
      inputFormatters: inputFormatters,
      textInputAction: textInputAction,
      obscureText: obscureText,
      autofillHints: autofillHints,
      enabled: enabled,
      focusNode: focusNode,
      autofocus: autofocus,
      textCapitalization: textCapitalization,
      onFieldSubmitted: onSubmitted,
      style: const TextStyle(fontSize: 15.5, color: AppColors.ink),
      decoration: AppTheme.input(
        label: label,
        hint: hint,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, size: 20, color: AppColors.inkMuted),
        suffixIcon: suffixIcon,
        prefixText: prefixText,
        helperText: helperText,
        dense: dense,
      ),
    );
  }
}

/// Dropdown that matches [AppTextField] (uses DropdownButton inside an
/// InputDecorator to avoid API churn in DropdownButtonFormField).
class AppDropdown<T> extends StatelessWidget {
  const AppDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.itemLabel,
    this.errorText,
  });

  final String label;
  final T? value;
  final List<T> items;
  final ValueChanged<T?> onChanged;
  final String Function(T)? itemLabel;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: AppTheme.input(label: label, errorText: errorText, dense: true),
      isEmpty: value == null,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: items.contains(value) ? value : null,
          isExpanded: true,
          isDense: true,
          borderRadius: BorderRadius.circular(14),
          dropdownColor: AppColors.ivory,
          items: [
            for (final i in items)
              DropdownMenuItem<T>(value: i, child: Text(itemLabel?.call(i) ?? i.toString(), overflow: TextOverflow.ellipsis)),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

void showSnack(BuildContext context, String message, {bool error = false}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger?.hideCurrentSnackBar();
  messenger?.showSnackBar(SnackBar(
    content: Row(children: [
      Icon(error ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
          color: error ? const Color(0xFFFFB4AB) : AppColors.goldLight, size: 20),
      const SizedBox(width: 10),
      Expanded(child: Text(message)),
    ]),
  ));
}

Future<bool> confirmDialog(BuildContext context,
    {required String title, required String message, String confirm = 'Confirm', bool destructive = false}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.ivory,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: AppColors.error) : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirm),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Constrains content width on tablets.
class MaxWidth extends StatelessWidget {
  const MaxWidth({super.key, required this.child, this.width = 760});
  final Widget child;
  final double width;

  @override
  Widget build(BuildContext context) =>
      Align(alignment: Alignment.topCenter, child: ConstrainedBox(constraints: BoxConstraints(maxWidth: width), child: child));
}
