import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/posture_provider.dart';
import '../providers/theme_notifier.dart';
import '../theme/app_colors.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PostureProvider>();

    return Scaffold(
      backgroundColor: AppColors.of(context).bg,
      body: SafeArea(
        child: Column(
          children: [
            const _Header(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  const _SectionLabel('DEVICE'),
                  const SizedBox(height: 10),
                  _DeviceCard(p: p),
                  const SizedBox(height: 24),
                  const _SectionLabel('NOTIFICATIONS'),
                  const SizedBox(height: 10),
                  _NotificationsCard(p: p),
                  const SizedBox(height: 24),
                  const _SectionLabel('APPEARANCE'),
                  const SizedBox(height: 10),
                  const _ThemeCard(),
                  const SizedBox(height: 24),
                  const _SectionLabel('PRIVACY & DATA'),
                  const SizedBox(height: 10),
                  const _PrivacyCard(),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      child: Row(
        children: [
          Text(
            'SETTINGS',
            style: TextStyle(
              color: c.textPri,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.8,
            ),
          ),
          const Spacer(),
          Container(
            width: 38,
            height: 38,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.surface,
              border: Border.all(color: c.border),
            ),
            child: Image.asset(
              'assets/logo.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) =>
                  Icon(Icons.bluetooth, color: c.accent, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: AppColors.of(context).textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 2.0,
      ),
    );
  }
}

// ── Device card ──────────────────────────────────────────────────────────────

class _DeviceCard extends StatelessWidget {
  final PostureProvider p;
  const _DeviceCard({required this.p});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final connected = p.isConnected;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: connected ? c.accent.withValues(alpha: 0.3) : c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: c.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.accent.withValues(alpha: 0.4)),
                ),
                child: Icon(Icons.memory_rounded, color: c.accent, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.deviceName,
                      style: TextStyle(
                        color: c.textPri,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: connected ? c.green : c.textMuted,
                            boxShadow: connected
                                ? [
                                    BoxShadow(
                                      color: c.green.withValues(alpha: 0.5),
                                      blurRadius: 6,
                                    )
                                  ]
                                : null,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          connected ? 'Connected' : 'Disconnected',
                          style:
                              TextStyle(color: c.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Battery',
                    style: TextStyle(color: c.textMuted, fontSize: 10),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        connected ? '${p.batteryPercent}%' : '—',
                        style: TextStyle(
                          color: c.textPri,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.battery_full_rounded,
                        size: 14,
                        color: connected ? c.green : c.textMuted,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: c.surfaceDeep,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                _kvRow(c, 'Firmware Version', p.firmwareVersion),
                const SizedBox(height: 8),
                _kvRow(c, 'Last Sync', p.lastSyncLabel),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: connected ? p.disconnect : p.connect,
              style: OutlinedButton.styleFrom(
                foregroundColor: c.textPri,
                side: BorderSide(color: c.border),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                connected ? 'Disconnect' : 'Connect',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kvRow(AppColors c, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: c.textMuted, fontSize: 12)),
        Text(
          value,
          style: TextStyle(
            color: c.textPri,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ── Notifications ────────────────────────────────────────────────────────────

class _NotificationsCard extends StatelessWidget {
  final PostureProvider p;
  const _NotificationsCard({required this.p});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          _NotifRow(
            title: 'Posture Reminders',
            subtitle: 'Vibrate when slouching detected',
            value: p.postureReminders,
            onChanged: p.savePostureReminders,
          ),
        ],
      ),
    );
  }
}

class _NotifRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _NotifRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: c.textPri,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(color: c.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: c.accent,
          ),
        ],
      ),
    );
  }
}

// ── Theme card ───────────────────────────────────────────────────────────────

class _ThemeCard extends StatelessWidget {
  const _ThemeCard();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final theme = context.watch<ThemeNotifier>();
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Icon(
            theme.isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
            color: c.accent,
            size: 22,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dark Mode',
                  style: TextStyle(
                    color: c.textPri,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  theme.isDark ? 'On' : 'Off — using light theme',
                  style: TextStyle(color: c.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: theme.isDark,
            onChanged: (_) => context.read<ThemeNotifier>().toggle(),
            activeThumbColor: c.accent,
          ),
        ],
      ),
    );
  }
}

// ── Privacy & data ───────────────────────────────────────────────────────────

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.storage_rounded,
            title: 'Data stored on device',
            subtitle: 'Session history and settings are stored locally',
          ),
          Divider(color: c.border, height: 1, indent: 14, endIndent: 14),
          _InfoRow(
            icon: Icons.cloud_off_rounded,
            title: 'No cloud sync',
            subtitle: 'Your data never leaves this device',
          ),
          Divider(color: c.border, height: 1, indent: 14, endIndent: 14),
          const _ClearDataRow(),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _InfoRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: c.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: c.textPri,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(color: c.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ClearDataRow extends StatelessWidget {
  const _ClearDataRow();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          Icon(Icons.delete_sweep_rounded, size: 18, color: c.pink),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Clear All Data',
                  style: TextStyle(
                    color: c.pink,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Erase session history and reset all settings',
                  style: TextStyle(color: c.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _confirmClear(context),
            style: TextButton.styleFrom(
              foregroundColor: c.pink,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: const Text(
              'Clear',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final c = AppColors.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.of(ctx).surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Clear All Data?',
          style: TextStyle(
              color: AppColors.of(ctx).textPri,
              fontWeight: FontWeight.w700),
        ),
        content: Text(
          'This will erase all session history and reset every setting to its default. This cannot be undone.',
          style: TextStyle(
              color: AppColors.of(ctx).textMuted, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(color: AppColors.of(ctx).textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Clear',
                style: TextStyle(
                  color: AppColors.of(ctx).pink,
                  fontWeight: FontWeight.w700,
                )),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<PostureProvider>().clearAllData();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: c.surface,
            behavior: SnackBarBehavior.floating,
            content: Text(
              'All data cleared.',
              style: TextStyle(color: c.textPri),
            ),
          ),
        );
      }
    }
  }
}
