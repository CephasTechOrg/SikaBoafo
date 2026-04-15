import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../shared/providers/core_providers.dart';
import '../../../shared/widgets/sync_status_pill.dart';

/// Bottom navigation shell for main modules (stubs).
class DashboardShellScreen extends ConsumerStatefulWidget {
  const DashboardShellScreen({super.key});

  @override
  ConsumerState<DashboardShellScreen> createState() => _DashboardShellScreenState();
}

class _DashboardShellScreenState extends ConsumerState<DashboardShellScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Center(child: SyncStatusPill()),
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: const [
          _PlaceholderTab(title: 'Home', icon: Icons.home_outlined),
          _PlaceholderTab(title: 'Sales', icon: Icons.point_of_sale_outlined),
          _PlaceholderTab(title: 'Stock', icon: Icons.inventory_2_outlined),
          _PlaceholderTab(title: 'More', icon: Icons.menu),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.point_of_sale_outlined), label: 'Sales'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), label: 'Stock'),
          NavigationDestination(icon: Icon(Icons.menu), label: 'More'),
        ],
      ),
      floatingActionButton: TextButton(
        onPressed: () async {
          await ref.read(secureTokenStorageProvider).clearSession();
          if (!context.mounted) return;
          context.go(AppRoute.auth.path);
        },
        child: const Text('Sign out (dev)'),
      ),
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Screen placeholder',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
