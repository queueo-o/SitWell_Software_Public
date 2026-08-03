import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/posture_provider.dart';
import '../theme/app_colors.dart';

class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  bool _agreed = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 40, 28, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.surface,
                    border: Border.all(color: c.border, width: 1.5),
                  ),
                  child: Image.asset(
                    'assets/logo.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) =>
                        Icon(Icons.bluetooth, color: c.accent, size: 32),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Title
              Center(
                child: Text(
                  'Privacy & Data',
                  style: TextStyle(
                    color: c.textPri,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Before you get started, here\'s how your data is handled.',
                  style: TextStyle(color: c.textMuted, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 36),

              // Policy cards
              _PolicyItem(
                icon: Icons.phone_android_rounded,
                title: 'Stored locally on your device',
                body:
                    'All session history, posture scores, and sensor readings are saved only on this device. Nothing is sent to external servers.',
              ),
              const SizedBox(height: 14),
              _PolicyItem(
                icon: Icons.cloud_off_rounded,
                title: 'No cloud sync or accounts',
                body:
                    'This app does not require an account and does not connect to the internet. Your data stays private.',
              ),
              const SizedBox(height: 14),
              _PolicyItem(
                icon: Icons.delete_sweep_rounded,
                title: 'You control your data',
                body:
                    'You can erase all stored data at any time from Settings → Privacy & Data → Clear All Data.',
              ),

              const Spacer(),

              // Agree checkbox
              GestureDetector(
                onTap: () => setState(() => _agreed = !_agreed),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: _agreed ? c.accent : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _agreed ? c.accent : c.border,
                          width: 1.5,
                        ),
                      ),
                      child: _agreed
                          ? Icon(Icons.check_rounded,
                              size: 14,
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.black
                                  : Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'I understand how my data is used.',
                        style:
                            TextStyle(color: c.textPri, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Get started button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _agreed
                      ? () => context.read<PostureProvider>().acceptPrivacy()
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: c.accent,
                    disabledBackgroundColor: c.border,
                    foregroundColor:
                        Theme.of(context).brightness == Brightness.dark
                            ? Colors.black
                            : Colors.white,
                    disabledForegroundColor: c.textMuted,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                    'Get Started',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PolicyItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _PolicyItem({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: c.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: c.accent, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: c.textPri,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(color: c.textMuted, fontSize: 12, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
