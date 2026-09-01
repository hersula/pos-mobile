import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_exception.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/role_labels.dart';
import '../../data/models/app_user.dart';
import '../../data/repositories/user_repository.dart';
import '../../state/auth_provider.dart';
import 'user_form_screen.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final _userRepo = UserRepository();

  List<AppUser> _users = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final users = await _userRepo.getUsers();
      if (mounted) setState(() => _users = users);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.read<AuthProvider>().currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen User'),
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadUsers)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const UserFormScreen()),
          );
          if (created == true) _loadUsers();
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('User'),
      ),
      body: SafeArea(child: _buildBody(currentUserId)),
    );
  }

  Widget _buildBody(String? currentUserId) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _loadUsers, child: const Text('Coba Lagi')),
            ],
          ),
        ),
      );
    }
    if (_users.isEmpty) {
      return const Center(child: Text('Belum ada user', style: TextStyle(color: AppColors.muted)));
    }

    return RefreshIndicator(
      onRefresh: _loadUsers,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
        itemCount: _users.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final u = _users[i];
          return Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              onTap: () async {
                final updated = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => UserFormScreen(user: u)),
                );
                if (updated == true) _loadUsers();
              },
              title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('${u.email} · ${roleLabels[u.role] ?? u.role}', style: const TextStyle(fontSize: 12.5)),
              trailing: !u.isActive
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: AppColors.dangerSoft, borderRadius: BorderRadius.circular(6)),
                      child: const Text('Nonaktif', style: TextStyle(color: AppColors.danger, fontSize: 11, fontWeight: FontWeight.w600)),
                    )
                  : null,
            ),
          );
        },
      ),
    );
  }
}
