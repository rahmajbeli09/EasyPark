import 'package:flutter/material.dart';
import '../data/database_helper.dart';
import 'login.dart';

class HomeAdmin extends StatefulWidget {
  const HomeAdmin({super.key});

  @override
  State<HomeAdmin> createState() => _HomeAdminState();
}

class _HomeAdminState extends State<HomeAdmin> {
  List<Map<String, dynamic>> _notifs = [];
  bool _loadingNotifs = true;

  int get _unreadCount => _notifs.where((n) => (n['read'] ?? 0) == 0).length;

  @override
  void initState() {
    super.initState();
    _loadNotifs();
  }

  Future<void> _loadNotifs() async {
    setState(() => _loadingNotifs = true);
    final list = await DatabaseHelper.instance.getNotifications(unreadOnly: false);
    if (!mounted) return;
    setState(() {
      _notifs = list;
      _loadingNotifs = false;
    });
  }

  Future<void> _openNotificationsDialog() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Notifications'),
        content: SizedBox(
          width: 400,
          child: _loadingNotifs
              ? const Center(child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ))
              : (_notifs.isEmpty
                  ? const Text('Aucune notification')
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: _notifs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final n = _notifs[i];
                        final title = (n['title'] ?? '').toString();
                        final body = (n['body'] ?? '').toString();
                        final date = (n['date'] ?? '').toString();
                        final read = (n['read'] ?? 0) == 1;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                          dense: true,
                          leading: Icon(read ? Icons.notifications_none : Icons.notifications_active,
                              color: read ? Colors.grey : Theme.of(context).colorScheme.primary),
                          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text([body, date].where((e) => e.isNotEmpty).join(' • ')),
                        );
                      },
                    )),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
    await DatabaseHelper.instance.markAllNotificationsRead();
    await _loadNotifs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accueil Admin'),
        actions: [
          IconButton(
            tooltip: 'Rafraîchir',
            onPressed: _loadNotifs,
            icon: const Icon(Icons.refresh),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  tooltip: 'Notifications',
                  onPressed: _openNotificationsDialog,
                  icon: const Icon(Icons.notifications_outlined),
                ),
                if (_unreadCount > 0)
                  Positioned(
                    right: 10,
                    top: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('$_unreadCount', style: const TextStyle(color: Colors.white, fontSize: 11)),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Se déconnecter',
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
              );
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tableau de bord',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 1.05,
                  children: [
                    AdminActionTile(
                      title: 'Utilisateurs',
                      icon: Icons.people_alt_rounded,
                      startColor: const Color(0xFF1A73E8),
                      endColor: const Color(0xFF54A0FF),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const UsersListPage()),
                        );
                      },
                    ),
                    AdminActionTile(
                      title: 'Parkings',
                      icon: Icons.local_parking_rounded,
                      startColor: const Color(0xFF34A853),
                      endColor: const Color(0xFF66D07F),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ParkingsListPage()),
                        );
                      },
                    ),
                    AdminActionTile(
                      title: 'Réclamations',
                      icon: Icons.report_gmailerrorred_rounded,
                      startColor: const Color(0xFFEA4335),
                      endColor: const Color(0xFFFF7C6E),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ReclamationsListPage()),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminActionTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final Color startColor;
  final Color endColor;

  const AdminActionTile({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    required this.startColor,
    required this.endColor,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = Colors.white;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [startColor, endColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: startColor.withOpacity(0.25),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: foreground.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(10),
                child: Icon(icon, color: foreground, size: 28),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class UsersListPage extends StatefulWidget {
  const UsersListPage({super.key});

  @override
  State<UsersListPage> createState() => _UsersListPageState();
}

class _UsersListPageState extends State<UsersListPage> {
  static const String _adminEmail = 'hela.nefla@gmail.com';
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;

  List<Map<String, dynamic>> get _filteredUsers {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _users;
    return _users.where((u) {
      final email = (u['email'] ?? '').toString().toLowerCase();
      final role = (u['role'] ?? '').toString().toLowerCase();
      return email.contains(q) || role.contains(q);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await DatabaseHelper.instance.getAllUsersExcept(_adminEmail);
    if (!mounted) return;
    setState(() {
      _users = data;
      _loading = false;
    });
  }

  Future<void> _refresh() async {
    await _load();
  }

  Future<void> _confirmAndDelete(int id, String email) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer l\'utilisateur ?'),
        content: Text('Êtes-vous sûr de vouloir supprimer "$email" ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (confirm == true) {
      await DatabaseHelper.instance.deleteUser(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Utilisateur supprimé')));
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Utilisateurs')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher par email ou rôle...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_filteredUsers.length} utilisateur(s)',
                    style: TextStyle(color: Theme.of(context).colorScheme.primary),
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Rafraîchir',
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredUsers.isEmpty
                      ? const Center(child: Text('Aucun utilisateur'))
                      : RefreshIndicator(
                          onRefresh: _refresh,
                          child: ListView.separated(
                            itemCount: _filteredUsers.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final u = _filteredUsers[index];
                              final id = u['id'] as int;
                              final email = (u['email'] ?? '').toString();
                              final role = (u['role'] ?? '').toString();
                              return Card(
                                elevation: 1.5,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Theme.of(context).colorScheme.primary,
                                    child: Text(
                                      email.isNotEmpty ? email[0].toUpperCase() : '?',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  title: Text(email),
                                  subtitle: Text(role.isEmpty ? '—' : role),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                    onPressed: () => _confirmAndDelete(id, email),
                                    tooltip: 'Supprimer',
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class ParkingsListPage extends StatefulWidget {
  const ParkingsListPage({super.key});

  @override
  State<ParkingsListPage> createState() => _ParkingsListPageState();
}

class _ParkingsListPageState extends State<ParkingsListPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _parkings = [];
  bool _loading = true;

  List<Map<String, dynamic>> get _filteredParkings {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _parkings;
    return _parkings.where((p) {
      String s(String k) => (p[k] ?? '').toString().toLowerCase();
      return s('nom').contains(q) ||
          s('region').contains(q) ||
          s('cite').contains(q) ||
          s('rue').contains(q) ||
          s('description').contains(q);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await DatabaseHelper.instance.getAllParkings();
    if (!mounted) return;
    setState(() {
      _parkings = data;
      _loading = false;
    });
  }

  Future<void> _refresh() async {
    await _load();
  }

  Future<void> _confirmAndDelete(int id, String nom) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le parking ?'),
        content: Text('Êtes-vous sûr de vouloir supprimer "$nom" ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (confirm == true) {
      await DatabaseHelper.instance.deleteParking(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Parking supprimé')));
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Parkings')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher par nom, région, cité, rue...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_filteredParkings.length} parking(s)',
                    style: TextStyle(color: Theme.of(context).colorScheme.primary),
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Rafraîchir',
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredParkings.isEmpty
                      ? const Center(child: Text('Aucun parking'))
                      : RefreshIndicator(
                          onRefresh: _refresh,
                          child: ListView.separated(
                            itemCount: _filteredParkings.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final p = _filteredParkings[index];
                              final id = p['id'] as int;
                              final nom = (p['nom'] ?? '').toString();
                              final region = (p['region'] ?? '').toString();
                              final cite = (p['cite'] ?? '').toString();
                              final rue = (p['rue'] ?? '').toString();
                              final total = int.tryParse((p['totalPlaces'] ?? '').toString()) ?? (p['totalPlaces'] as int? ?? 0);
                              final dispo = int.tryParse((p['availablePlaces'] ?? '').toString()) ?? (p['availablePlaces'] as int? ?? 0);
                              final prixHeure = double.tryParse((p['prixHeure'] ?? '').toString()) ?? (p['prixHeure'] as double? ?? 0);
                              return Card(
                                elevation: 1.5,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Theme.of(context).colorScheme.secondary,
                                    child: const Icon(Icons.local_parking, color: Colors.white),
                                  ),
                                  title: Text(nom.isEmpty ? 'Parking #$id' : nom),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text([
                                        if (region.isNotEmpty) region,
                                        if (cite.isNotEmpty) cite,
                                        if (rue.isNotEmpty) rue,
                                      ].join(' · ')),
                                      const SizedBox(height: 4),
                                      Text('Places: $dispo / $total · ${prixHeure.toStringAsFixed(2)} dt/heure'),
                                    ],
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                    onPressed: () => _confirmAndDelete(id, nom.isEmpty ? 'Parking #$id' : nom),
                                    tooltip: 'Supprimer',
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class ReclamationsListPage extends StatelessWidget {
  const ReclamationsListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ReclamationsList();
  }
}

class _ReclamationsList extends StatefulWidget {
  const _ReclamationsList();
  @override
  State<_ReclamationsList> createState() => _ReclamationsListState();
}

class _ReclamationsListState extends State<_ReclamationsList> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _all = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(() => _apply(_searchController.text));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await DatabaseHelper.instance.getAllReclamations();
    if (!mounted) return;
    setState(() {
      _all = data;
      _filtered = List<Map<String, dynamic>>.from(_all);
      _loading = false;
    });
  }

  void _apply(String q0) {
    final q = q0.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = List<Map<String, dynamic>>.from(_all);
      } else {
        _filtered = _all.where((r) {
          final hay = [
            r['type'] ?? '',
            r['description'] ?? '',
            r['status'] ?? '',
            r['date'] ?? '',
            (r['userId'] ?? '').toString(),
          ].join(' ').toLowerCase();
          return hay.contains(q);
        }).toList();
      }
    });
  }

  Future<void> _refresh() async => _load();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Réclamations')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher par type, statut, description...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_filtered.length} réclamation(s)',
                    style: TextStyle(color: Theme.of(context).colorScheme.primary),
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Rafraîchir',
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _filtered.isEmpty
                      ? const Center(child: Text('Aucune réclamation'))
                      : RefreshIndicator(
                          onRefresh: _refresh,
                          child: ListView.separated(
                            itemCount: _filtered.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final r = _filtered[index];
                              final userId = r['userId'];
                              final type = (r['type'] ?? '').toString();
                              final status = (r['status'] ?? '').toString();
                              final date = (r['date'] ?? '').toString();
                              final desc = (r['description'] ?? '').toString();
                              return Card(
                                elevation: 1.5,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Theme.of(context).colorScheme.primary,
                                    child: const Icon(Icons.report, color: Colors.white),
                                  ),
                                  title: Text(type.isEmpty ? 'Réclamation' : type),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('User: #$userId  •  Statut: ${status.isEmpty ? 'Nouvelle' : status}'),
                                      if (desc.isNotEmpty) Padding(
                                        padding: const EdgeInsets.only(top:4.0),
                                        child: Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis),
                                      ),
                                      if (date.isNotEmpty) Padding(
                                        padding: const EdgeInsets.only(top:4.0),
                                        child: Text(date, style: const TextStyle(color: Colors.grey)),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
