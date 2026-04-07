import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:harmonia_ai/core/theme/app_theme.dart';
import 'package:harmonia_ai/features/auth/providers/auth_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeMode themeMode = ref.watch(themeModeProvider);
    final User? user = ref.watch(authStateProvider).valueOrNull;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _AccountHeader(user: user),
          const SizedBox(height: 16),
          _SectionCard(
            child: SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Dark mode'),
              subtitle: const Text('Match the app to the light or dark palette'),
              value: themeMode == ThemeMode.dark,
              onChanged: (bool value) {
                ref.read(themeModeProvider.notifier).state =
                    value ? ThemeMode.dark : ThemeMode.light;
              },
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            child: Column(
              children: [
                _ActionRow(
                  icon: Icons.notifications_outlined,
                  title: 'Notification preferences',
                  subtitle: 'Focus reminders, workout nudges, and alerts',
                  onTap: () {},
                ),
                const Divider(height: 1),
                _ActionRow(
                  icon: Icons.delete_outline,
                  title: 'Clear chat history',
                  subtitle: 'Remove local assistant conversation data',
                  onTap: () {},
                ),
                const Divider(height: 1),
                _ActionRow(
                  icon: Icons.person_remove_outlined,
                  title: 'Delete account',
                  subtitle: 'Permanently remove your profile',
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            child: Column(
              children: [
                _ActionRow(
                  icon: Icons.logout,
                  title: 'Sign out',
                  subtitle: 'Disconnect the current Google or email session',
                  onTap: () async {
                    await ref.read(authControllerProvider.notifier).signOut();
                    if (context.mounted) {
                      context.go('/auth');
                    }
                  },
                  accent: isDark ? const Color(0xFFFFA3A3) : const Color(0xFFD91F3A),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountHeader extends StatelessWidget {
  const _AccountHeader({required this.user});

  final User? user;

  @override
  Widget build(BuildContext context) {
    final Color cardColor = Theme.of(context).colorScheme.surfaceContainerHighest;
    final String name = user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!.trim()
        : 'Harmonia User';
    final String email = user?.email ?? 'Signed in session';
    final String? photoUrl = user?.photoURL;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                ? NetworkImage(photoUrl)
                : null,
            child: photoUrl == null || photoUrl.isEmpty
                ? const Icon(Icons.person, size: 28)
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(email, style: Theme.of(context).textTheme.bodyMedium),
                if (photoUrl != null && photoUrl.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SelectableText(
                    photoUrl,
                    maxLines: 2,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accent,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final Color effectiveAccent = accent ?? Theme.of(context).colorScheme.primary;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: effectiveAccent.withValues(alpha: 0.12),
        child: Icon(icon, color: effectiveAccent),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
