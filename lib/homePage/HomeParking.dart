import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../data/database_helper.dart';
import 'login.dart';

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }

}

class HomeParking extends StatefulWidget {
  const HomeParking({super.key, required this.currentUserId, required this.currentUserEmail});

  final int currentUserId;
  final String currentUserEmail;

  @override
  State<HomeParking> createState() => _HomeParkingState();
}

class _HomeParkingState extends State<HomeParking> {
  final List<Map<String, dynamic>> _parkings = [];
  bool _loading = true;
  int _tabIndex = 0;
  Map<String, dynamic>? _user;
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    _loadMyParkings();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final u = await DatabaseHelper.instance.getUserById(widget.currentUserId);
    if (!mounted) return;
    setState(() {
      _user = u;
      _nameCtrl.text = (u?['name'] ?? '').toString();
      _phoneCtrl.text = (u?['phone'] ?? '').toString();
      _emailCtrl.text = (u?['email'] ?? widget.currentUserEmail).toString();
      final photo = (u?['photo'] ?? '').toString();
      _photoUrl = photo.isEmpty ? null : photo;
    });
  }

  Future<void> _saveProfile() async {
    if (_user == null) return;
    final values = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'photo': _photoUrl,
    };
    await DatabaseHelper.instance.updateUser(widget.currentUserId, values);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profil mis à jour')));
    await _loadUser();
  }

  Future<void> _changePhoto() async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    setState(() {
      _photoUrl = picked.path;
    });
  }

 

  // _showPromoActions removed after moving to a dedicated Promotions tab.

  Future<void> _showRemovePromotionForm() async {
    if (_parkings.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aucun parking')));
      return;
    }
    final Set<int> selected = <int>{};
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Retirer la promotion'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Sélectionnez les parkings', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: Scrollbar(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _parkings.length,
                      itemBuilder: (c, i) {
                        final p = _parkings[i];
                        final id = p['id'] as int?;
                        final nom = (p['nom'] ?? '').toString();
                        final hasPromo = (p['promoPercent'] != null) && ((double.tryParse(p['promoPercent'].toString()) ?? 0) > 0);
                        return CheckboxListTile(
                          value: id != null && selected.contains(id),
                          onChanged: (v) {
                            if (id == null) return;
                            (ctx as Element).markNeedsBuild();
                            if (v == true) {
                              selected.add(id);
                            } else {
                              selected.remove(id);
                            }
                          },
                          dense: true,
                          title: Text(nom),
                          subtitle: Text(hasPromo ? 'Promo actuelle: -${(double.tryParse(p['promoPercent'].toString()) ?? 0).toStringAsFixed(0)}%' : 'Aucune promotion'),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Annuler'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.delete_sweep),
              onPressed: () async {
                if (selected.isEmpty) return;
                for (final id in selected) {
                  await DatabaseHelper.instance.updateParking(id, {
                    'promoPercent': null,
                  });
                }
                if (!mounted) return;
                setState(() {
                  for (int i = 0; i < _parkings.length; i++) {
                    final pid = _parkings[i]['id'] as int?;
                    if (pid != null && selected.contains(pid)) {
                      _parkings[i] = {
                        ..._parkings[i],
                        'promoPercent': null,
                      };
                    }
                  }
                });
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Promotion retirée (${selected.length})')),
                );
              },
              label: const Text('Retirer'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAddPromotionForm() async {
    if (_parkings.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aucun parking à promouvoir')));
      return;
    }
    final formKey = GlobalKey<FormState>();
    final percentCtrl = TextEditingController();
    final Set<int> selected = <int>{};

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Appliquer une promotion'),
          content: Form(
            key: formKey,
            child: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Sélectionnez les parkings', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 260),
                    child: Scrollbar(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _parkings.length,
                        itemBuilder: (c, i) {
                          final p = _parkings[i];
                          final id = p['id'] as int?;
                          final nom = (p['nom'] ?? '').toString();
                          return CheckboxListTile(
                            value: id != null && selected.contains(id),
                            onChanged: (v) {
                              if (id == null) return;
                              (ctx as Element).markNeedsBuild();
                              if (v == true) {
                                selected.add(id);
                              } else {
                                selected.remove(id);
                              }
                            },
                            dense: true,
                            title: Text(nom),
                            subtitle: Text('Tarif: ${p['prixHeure']} TND/h  |  ${(p['prixJour'] ?? '-') } TND/j'),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: percentCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Pourcentage de réduction (%)',
                      hintText: 'Exemple: 10 pour -10%'
                    ),
                    validator: (v) {
                      final t = (v ?? '').trim();
                      if (t.isEmpty) return 'Pourcentage requis';
                      final d = double.tryParse(t);
                      if (d == null || d <= 0 || d > 100) return 'Valeur entre 0 et 100';
                      if (selected.isEmpty) return 'Sélectionnez au moins un parking';
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Annuler'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.check),
              onPressed: () async {
                if (!(formKey.currentState?.validate() ?? false)) return;
                final percent = double.parse(percentCtrl.text.trim());
                // Persist changes
                for (final id in selected) {
                  await DatabaseHelper.instance.updateParking(id, {
                    'promoPercent': percent,
                    // keep any date window unchanged
                  });
                }
                if (!mounted) return;
                setState(() {
                  for (int i = 0; i < _parkings.length; i++) {
                    final pid = _parkings[i]['id'] as int?;
                    if (pid != null && selected.contains(pid)) {
                      _parkings[i] = {
                        ..._parkings[i],
                        'promoPercent': percent,
                      };
                    }
                  }
                });
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Promotion -${percent.toStringAsFixed(0)}% appliquée (${selected.length})')),
                );
              },
              label: const Text('Appliquer'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadMyParkings() async {
    setState(() {
      _loading = true;
    });
    final data = await DatabaseHelper.instance.getParkingsByOwner(widget.currentUserId);
    if (!mounted) return;
    setState(() {
      _parkings
        ..clear()
        ..addAll(data);
      _loading = false;
    });
  }

  void _showEditParkingForm(Map<String, dynamic> parking, int index) {
    Navigator.of(context)
        .push<Map<String, dynamic>>(
          MaterialPageRoute(builder: (_) => EditParkingPage(parking: parking)),
        )
        .then((result) async {
      if (result != null) {
        final id = parking['id'] as int?;
        if (id == null) return;
        await DatabaseHelper.instance.updateParking(id, result);
        if (!mounted) return;
        setState(() {
          _parkings[index] = {
            'id': id,
            'ownerId': widget.currentUserId,
            ...result,
          };
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Parking modifié')),
        );
      }
    });
  }

  Future<void> _confirmDelete(Map<String, dynamic> parking, int index) async {
    final id = parking['id'] as int?;
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Suppression impossible: id manquant')),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce parking ?'),
        content: Text('"${parking['nom'] ?? ''}" sera définitivement supprimé.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok != true) return;
    await DatabaseHelper.instance.deleteParking(id);
    if (!mounted) return;
    setState(() {
      _parkings.removeAt(index);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Parking supprimé')),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_tabIndex == 0) {
      // Home tab: list of parkings with improved styling
      body = _loading
          ? const Center(child: CircularProgressIndicator())
          : (_parkings.isEmpty
              ? const Center(child: Text('Aucun parking. Allez à Ajouter pour en créer un.'))
              : RefreshIndicator(
                  onRefresh: _loadMyParkings,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: _parkings.length,
                    itemBuilder: (context, index) {
                      final p = _parkings[index];
                      final String nom = (p['nom'] ?? '').toString();
                      final String desc = (p['description'] ?? '').toString();
                      final String region = (p['region'] ?? '').toString();
                      final String cite = (p['cite'] ?? '').toString();
                      final String rue = (p['rue'] ?? '').toString();
                      final String addr = [region, cite, rue].where((e) => e.isNotEmpty).join(' • ');
                      final int available = int.tryParse((p['availablePlaces'] ?? '').toString()) ?? 0;
                      final int total = int.tryParse((p['totalPlaces'] ?? '').toString()) ?? 0;
                      final double? ph = p['prixHeure'] == null ? null : (double.tryParse(p['prixHeure'].toString()) ?? p['prixHeure']);
                      final double? pj = p['prixJour'] == null ? null : (double.tryParse(p['prixJour'].toString()) ?? p['prixJour']);

                      final double? promoPercent = p['promoPercent'] == null ? null : (double.tryParse(p['promoPercent'].toString()) ?? p['promoPercent']);
                      final String? promoStartStr = (p['promoStart']?.toString().isEmpty ?? true) ? null : p['promoStart']?.toString();
                      final String? promoEndStr = (p['promoEnd']?.toString().isEmpty ?? true) ? null : p['promoEnd']?.toString();
                      final DateTime? promoStart = promoStartStr == null ? null : DateTime.tryParse(promoStartStr);
                      final DateTime? promoEnd = promoEndStr == null ? null : DateTime.tryParse(promoEndStr);
                      final now = DateTime.now();
                      final bool promoActive = (promoPercent != null && promoPercent > 0 && promoPercent <= 100)
                          && (promoStart == null || !now.isBefore(promoStart))
                          && (promoEnd == null || !now.isAfter(promoEnd));

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        nom,
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (promoActive)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.redAccent.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: Colors.redAccent),
                                        ),
                                        child: Text(
                                          '-${promoPercent.toStringAsFixed(0)}%',
                                          style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                if (desc.isNotEmpty)
                                  Text(
                                    desc,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                if (desc.isNotEmpty) const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    if (addr.isNotEmpty)
                                      _InfoChip(icon: Icons.place, label: addr),
                                    _InfoChip(icon: Icons.event_seat, label: 'Dispo: $available/$total'),
                                    if (ph != null)
                                      _InfoChip(icon: Icons.access_time, label: '${ph.toStringAsFixed(2)} TND/h'),
                                    if (pj != null)
                                      _InfoChip(icon: Icons.calendar_today, label: '${pj.toStringAsFixed(2)} TND/j'),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton.icon(
                                      onPressed: () => _showEditParkingForm(p, index),
                                      icon: const Icon(Icons.edit, color: Colors.blueAccent),
                                      label: const Text('Modifier'),
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton.icon(
                                      onPressed: () => _confirmDelete(p, index),
                                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                                      label: const Text('Supprimer'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ));
    } else if (_tabIndex == 1) {
      // Promotions tab
      body = Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: _showAddPromotionForm,
              icon: const Icon(Icons.local_offer),
              label: const Text('Ajouter une promotion'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _showRemovePromotionForm,
              icon: const Icon(Icons.local_offer_outlined),
              label: const Text('Retirer une promotion'),
            ),
          ],
        ),
      );
    } else if (_tabIndex == 2) {
      // Réclamation tab
      body = Center(
        child: ElevatedButton.icon(
          onPressed: _openReclamationForm,
          icon: const Icon(Icons.report_problem),
          label: const Text('Faire une réclamation'),
        ),
      );
    } else if (_tabIndex == 3) {
      // Ajouter tab
      body = Center(
        child: ElevatedButton.icon(
          onPressed: _showAddParkingForm,
          icon: const Icon(Icons.add),
          label: const Text('Ajouter un parking'),
        ),
      );
    } else {
      // Profil tab (restyled)
      body = SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 160,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.primary.withOpacity(0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: 16,
                    bottom: 16,
                    child: Text(
                      'Profil responsable',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -40),
              child: Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: Colors.white,
                      child: CircleAvatar(
                        radius: 44,
                        backgroundColor: Colors.grey.shade200,
                        backgroundImage: (_photoUrl == null || _photoUrl!.isEmpty)
                            ? null
                            : (_photoUrl!.startsWith('http')
                                ? NetworkImage(_photoUrl!)
                                : FileImage(File(_photoUrl!)) as ImageProvider),
                        child: (_photoUrl == null || _photoUrl!.isEmpty)
                            ? const Icon(Icons.person, size: 44, color: Colors.grey)
                            : null,
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Material(
                        color: Theme.of(context).colorScheme.primary,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _changePhoto,
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(Icons.edit, size: 18, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_user, size: 16, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 6),
                        Text((_user?['role'] ?? '').toString(), style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(labelText: 'Nom complet', prefixIcon: Icon(Icons.badge_outlined)),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _phoneCtrl,
                        decoration: const InputDecoration(labelText: 'Téléphone', prefixIcon: Icon(Icons.phone_outlined)),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _emailCtrl,
                        decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.alternate_email_outlined)),
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _saveProfile,
                      icon: const Icon(Icons.save),
                      label: const Text('Enregistrer'),
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                          (route) => false,
                        );
                      },
                      icon: const Icon(Icons.logout),
                      label: const Text('Se déconnecter'),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Espace Parking Responsable', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: body,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabIndex,
        type: BottomNavigationBarType.fixed,
        onTap: (i) => setState(() => _tabIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.local_offer), label: 'Promotions'),
          BottomNavigationBarItem(icon: Icon(Icons.report), label: 'Réclamation'),
          BottomNavigationBarItem(icon: Icon(Icons.add_box), label: 'Ajouter'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }

  Future<void> _openReclamationForm() async {
    final reasons = const [
      'Parking plein malgré la réservation',
      'Problème de paiement',
      'Erreur de réservation',
      'Problème de compte',
      'Suggestion ou amélioration',
      'Problème technique',
    ];
    String? type;
    final descCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nouvelle réclamation'),
        content: Form(
          key: formKey,
          child: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Type de réclamation'),
                  items: reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                  onChanged: (v) => type = v,
                  validator: (v) => (v == null || v.isEmpty) ? 'Veuillez choisir un type' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: descCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Description'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Description requise' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annuler')),
          FilledButton(
            onPressed: () async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              final t = type!;
              final d = descCtrl.text.trim();
              await DatabaseHelper.instance.createReclamation(widget.currentUserId, t, d);
              if (!mounted) return;
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Réclamation envoyée')));
            },
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );
  }

  void _showAddParkingForm() {
    // Ouvre un formulaire en plein écran (meilleure interaction clavier)
    Navigator.of(context)
        .push<Map<String, dynamic>>(
          MaterialPageRoute(builder: (_) => const AddParkingPage()),
        )
        .then((result) {
      if (result != null) {
        () async {
          final toInsert = {
            ...result,
            'ownerId': widget.currentUserId,
          };
          // Insert into DB
          final id = await DatabaseHelper.instance.insertParking(toInsert);
          // Keep local display in sync
          if (mounted) {
            setState(() {
              _parkings.insert(0, {
                'id': id,
                ...toInsert,
              });
            });
          }
        }();
      }
    });
  }
}

class AddParkingPage extends StatefulWidget {
  const AddParkingPage({super.key});

  @override
  State<AddParkingPage> createState() => _AddParkingPageState();
}

class _AddParkingPageState extends State<AddParkingPage> {
  final _formKey = GlobalKey<FormState>();

  final _nomCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _regionCtrl = TextEditingController();
  final _citeCtrl = TextEditingController();
  final _rueCtrl = TextEditingController();
  final _numBlocCtrl = TextEditingController();
  final _totalCtrl = TextEditingController();
  final _dispoCtrl = TextEditingController();
  final _prixHeureCtrl = TextEditingController();
  final _prixJourCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _promoPercentCtrl = TextEditingController();
  final _promoStartCtrl = TextEditingController();
  final _promoEndCtrl = TextEditingController();

  final _nomFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nomFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _descCtrl.dispose();
    _regionCtrl.dispose();
    _citeCtrl.dispose();
    _rueCtrl.dispose();
    _numBlocCtrl.dispose();
    _totalCtrl.dispose();
    _dispoCtrl.dispose();
    _prixHeureCtrl.dispose();
    _prixJourCtrl.dispose();
    _phoneCtrl.dispose();
    _promoPercentCtrl.dispose();
    _promoStartCtrl.dispose();
    _promoEndCtrl.dispose();
    _nomFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajouter un parking')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                const Text('🏷️ Informations générales', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nomCtrl,
                  focusNode: _nomFocus,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Nom du parking'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),

                const Text('📍 Localisation', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _regionCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Région (ex: Tunis, Sfax, Sousse)'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Région requise' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _citeCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Cité / Quartier'),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _rueCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Rue'),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _numBlocCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Numéro / Bloc'),
                ),
                const SizedBox(height: 16),

                const Text('🚗 Capacité', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _totalCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Nombre total de places'),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final n = int.tryParse((v ?? '').trim());
                    if (n == null || n <= 0) return 'Nombre total invalide';
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _dispoCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Nombre de places disponibles'),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final total = int.tryParse(_totalCtrl.text.trim()) ?? 0;
                    final d = int.tryParse((v ?? '').trim());
                    if (d == null || d < 0 || d > total) return 'Disponibles invalides';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                const Text('💰 Tarification', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _prixHeureCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Prix par heure'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) => (double.tryParse((v ?? '').trim()) == null) ? 'Prix invalide' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _prixJourCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Prix par jour (optionnel)'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 16),

                const Text('🏷️ Promotion (optionnel)', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _promoPercentCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Réduction (%) ex: 10 pour -10%'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if ((v ?? '').trim().isEmpty) return null;
                    final d = double.tryParse((v ?? '').trim());
                    if (d == null || d < 0 || d > 100) return 'Pourcentage entre 0 et 100';
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _promoStartCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Début (YYYY-MM-DD, optionnel)'),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _promoEndCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Fin (YYYY-MM-DD, optionnel)'),
                ),
                const SizedBox(height: 16),

                const Text('🏷️ Promotion (optionnel)', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _promoPercentCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Réduction (%) ex: 10 pour -10%'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if ((v ?? '').trim().isEmpty) return null;
                    final d = double.tryParse((v ?? '').trim());
                    if (d == null || d < 0 || d > 100) return 'Pourcentage entre 0 et 100';
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _promoStartCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Début (YYYY-MM-DD, optionnel)'),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _promoEndCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Fin (YYYY-MM-DD, optionnel)'),
                ),
                const SizedBox(height: 16),

                const Text('📞 Contact', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Numéro de téléphone'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _onSave,
                    icon: const Icon(Icons.save),
                    label: const Text('Enregistrer'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onSave() {
    if (!_formKey.currentState!.validate()) return;
    final data = <String, dynamic>{
      'nom': _nomCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'region': _regionCtrl.text.trim(),
      'cite': _citeCtrl.text.trim(),
      'rue': _rueCtrl.text.trim(),
      'numeroBloc': _numBlocCtrl.text.trim(),
      'totalPlaces': int.tryParse(_totalCtrl.text.trim()) ?? 0,
      'availablePlaces': int.tryParse(_dispoCtrl.text.trim()) ?? 0,
      'prixHeure': double.tryParse(_prixHeureCtrl.text.trim()) ?? 0,
      'prixJour': (_prixJourCtrl.text.trim().isEmpty)
          ? null
          : double.tryParse(_prixJourCtrl.text.trim()),
      'promoPercent': (_promoPercentCtrl.text.trim().isEmpty)
          ? null
          : double.tryParse(_promoPercentCtrl.text.trim()),
      'promoStart': _promoStartCtrl.text.trim().isEmpty ? null : _promoStartCtrl.text.trim(),
      'promoEnd': _promoEndCtrl.text.trim().isEmpty ? null : _promoEndCtrl.text.trim(),
      'telephone': _phoneCtrl.text.trim(),
    };
    Navigator.of(context).pop(data);
  }
}

class EditParkingPage extends StatefulWidget {
  const EditParkingPage({super.key, required this.parking});

  final Map<String, dynamic> parking;

  @override
  State<EditParkingPage> createState() => _EditParkingPageState();
}

class _EditParkingPageState extends State<EditParkingPage> {
  final _formKey = GlobalKey<FormState>();

  final _nomCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _regionCtrl = TextEditingController();
  final _citeCtrl = TextEditingController();
  final _rueCtrl = TextEditingController();
  final _numBlocCtrl = TextEditingController();
  final _totalCtrl = TextEditingController();
  final _dispoCtrl = TextEditingController();
  final _prixHeureCtrl = TextEditingController();
  final _prixJourCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _promoPercentCtrl = TextEditingController();
  final _promoStartCtrl = TextEditingController();
  final _promoEndCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final p = widget.parking;
    _nomCtrl.text = (p['nom'] ?? '').toString();
    _descCtrl.text = (p['description'] ?? '').toString();
    _regionCtrl.text = (p['region'] ?? '').toString();
    _citeCtrl.text = (p['cite'] ?? '').toString();
    _rueCtrl.text = (p['rue'] ?? '').toString();
    _numBlocCtrl.text = (p['numeroBloc'] ?? '').toString();
    _totalCtrl.text = (p['totalPlaces'] ?? '').toString();
    _dispoCtrl.text = (p['availablePlaces'] ?? '').toString();
    _prixHeureCtrl.text = (p['prixHeure'] ?? '').toString();
    _prixJourCtrl.text = (p['prixJour'] ?? '').toString();
    _phoneCtrl.text = (p['telephone'] ?? '').toString();
    _promoPercentCtrl.text = (p['promoPercent'] ?? '').toString();
    _promoStartCtrl.text = (p['promoStart'] ?? '').toString();
    _promoEndCtrl.text = (p['promoEnd'] ?? '').toString();
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _descCtrl.dispose();
    _regionCtrl.dispose();
    _citeCtrl.dispose();
    _rueCtrl.dispose();
    _numBlocCtrl.dispose();
    _totalCtrl.dispose();
    _dispoCtrl.dispose();
    _prixHeureCtrl.dispose();
    _prixJourCtrl.dispose();
    _phoneCtrl.dispose();
    _promoPercentCtrl.dispose();
    _promoStartCtrl.dispose();
    _promoEndCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Modifier le parking')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                const Text('🏷️ Informations générales', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nomCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Nom du parking'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),

                const Text('📍 Localisation', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _regionCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Région (ex: Tunis, Sfax, Sousse)'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Région requise' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _citeCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Cité / Quartier'),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _rueCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Rue'),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _numBlocCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Numéro / Bloc'),
                ),
                const SizedBox(height: 16),

                const Text('🚗 Capacité', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _totalCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Nombre total de places'),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final n = int.tryParse((v ?? '').trim());
                    if (n == null || n <= 0) return 'Nombre total invalide';
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _dispoCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Nombre de places disponibles'),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final total = int.tryParse(_totalCtrl.text.trim()) ?? 0;
                    final d = int.tryParse((v ?? '').trim());
                    if (d == null || d < 0 || d > total) return 'Disponibles invalides';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                const Text('💰 Tarification', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _prixHeureCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Prix par heure'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) => (double.tryParse((v ?? '').trim()) == null) ? 'Prix invalide' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _prixJourCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Prix par jour (optionnel)'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 16),

                const Text('📞 Contact', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Numéro de téléphone'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _onSave,
                    icon: const Icon(Icons.save),
                    label: const Text('Enregistrer'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onSave() {
    if (!_formKey.currentState!.validate()) return;
    final data = <String, dynamic>{
      'nom': _nomCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'region': _regionCtrl.text.trim(),
      'cite': _citeCtrl.text.trim(),
      'rue': _rueCtrl.text.trim(),
      'numeroBloc': _numBlocCtrl.text.trim(),
      'totalPlaces': int.tryParse(_totalCtrl.text.trim()) ?? 0,
      'availablePlaces': int.tryParse(_dispoCtrl.text.trim()) ?? 0,
      'prixHeure': double.tryParse(_prixHeureCtrl.text.trim()) ?? 0,
      'prixJour': (_prixJourCtrl.text.trim().isEmpty)
          ? null
          : double.tryParse(_prixJourCtrl.text.trim()),
      'promoPercent': (_promoPercentCtrl.text.trim().isEmpty)
          ? null
          : double.tryParse(_promoPercentCtrl.text.trim()),
      'promoStart': _promoStartCtrl.text.trim().isEmpty ? null : _promoStartCtrl.text.trim(),
      'promoEnd': _promoEndCtrl.text.trim().isEmpty ? null : _promoEndCtrl.text.trim(),
      'telephone': _phoneCtrl.text.trim(),
    };
    Navigator.of(context).pop(data);
  }
}

