/// Shared senior-friendly UI building blocks.
/// Rules: every button >= 64px tall, body >= 18pt, money >= 24pt.
library;

import 'package:flutter/material.dart';

import 'theme.dart';

/// ────────────────────────────────────────────────────────────────────────
/// BIG BUTTON — the one true button of the app (>= 64dp height)
/// ────────────────────────────────────────────────────────────────────────
class BigButton extends StatelessWidget {
  const BigButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.color = AppColors.primary,
    this.foregroundColor = Colors.white,
    this.height = 64,
    this.loading = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color color;
  final Color foregroundColor;
  final double height;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || loading;
    final bg = disabled ? const Color(0xFFB9C9C0) : color;
    return Semantics(
      button: true,
      enabled: !disabled,
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          elevation: disabled ? 0 : 2,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (loading)
                    const SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Colors.white,
                      ),
                    )
                  else if (icon != null) ...[
                    Icon(icon, size: 30, color: foregroundColor),
                    const SizedBox(width: 10),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: AppStyles.buttonLabel
                          .copyWith(color: foregroundColor, fontSize: 21),
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ────────────────────────────────────────────────────────────────────────
/// Section title row:  "2️⃣ Chọn mặt hàng"
/// ────────────────────────────────────────────────────────────────────────
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.color = AppColors.ink});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: AppStyles.sectionTitle.copyWith(color: color));
  }
}

/// ────────────────────────────────────────────────────────────────────────
/// KPI card used on Dashboard / Debts. Big value, coloured accent.
/// ────────────────────────────────────────────────────────────────────────
class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    this.accent = AppColors.primary,
    this.valueColor,
    this.icon,
    this.onTap,
  });

  final String label;
  final String value;
  final Color accent;
  final Color? valueColor;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border(left: BorderSide(color: accent, width: 7)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: accent, size: 24),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkSoft,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: AppStyles.amount
                  .copyWith(color: valueColor ?? accent, fontSize: 30),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return content;
    return InkWell(borderRadius: BorderRadius.circular(20), onTap: onTap, child: content);
  }
}

/// ────────────────────────────────────────────────────────────────────────
/// Empty state (no data)
/// ────────────────────────────────────────────────────────────────────────
class EmptyHint extends StatelessWidget {
  const EmptyHint({
    super.key,
    required this.icon,
    required this.title,
    this.message,
  });

  final IconData icon;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 84, color: AppColors.primaryLight),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center, style: AppStyles.sectionTitle),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(message!,
                  textAlign: TextAlign.center, style: AppStyles.hint),
            ],
          ],
        ),
      ),
    );
  }
}

/// ────────────────────────────────────────────────────────────────────────
/// Full-area loading
/// ────────────────────────────────────────────────────────────────────────
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message = 'Đang tải dữ liệu…'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 52,
            height: 52,
            child: CircularProgressIndicator(strokeWidth: 5),
          ),
          const SizedBox(height: 20),
          Text(message, style: AppStyles.body),
        ],
      ),
    );
  }
}

/// ────────────────────────────────────────────────────────────────────────
/// Error banner with retry (offline / server problems)
/// ────────────────────────────────────────────────────────────────────────
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.dangerBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.danger, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.wifi_off,
                  color: AppColors.danger, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: AppStyles.body.copyWith(
                      color: AppColors.danger, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (onRetry != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 26),
                label: const Text('Thử lại',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
              ),
            ),
        ],
      ),
    );
  }
}

/// ────────────────────────────────────────────────────────────────────────
/// Small square chip for product units / quick money amounts
/// ────────────────────────────────────────────────────────────────────────
class SelectableChip extends StatelessWidget {
  const SelectableChip({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primary : const Color(0xFFBCC9C1),
              width: 2,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}
