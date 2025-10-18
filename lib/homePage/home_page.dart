import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../data/database_helper.dart';
import '../notifications/notification_service.dart';
import 'login.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.currentUserId, required this.currentUserEmail});

  final int currentUserId;
  final String currentUserEmail;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  bool _loading = true;
  List<Map<String, dynamic>> _allParkings = [];
  List<Map<String, dynamic>> _filteredParkings = [];
  final Set<int> _reservedIds = <int>{};
  final TextEditingController _hoursCtrl = TextEditingController(text: '1');
  int _tabIndex = 0;
  List<Map<String, dynamic>> _reservations = [];
  Map<String, dynamic>? _user;
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  String? _photoUrl;
  
  Future<void> _reserveSpot(Map<String, dynamic> p, int filteredIndex) async {
    final dynamic rawId = p['id'];
    final int? id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
    if (id == null) return;
    final int? hours = await _promptReservationHours();
    if (hours == null || hours <= 0) return;
    final int currentAvail = int.tryParse((p['availablePlaces'] ?? '').toString()) ?? (p['availablePlaces'] ?? 0);
    if (currentAvail <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucune place disponible')),
      );
      return;
    }


    final int newAvail = currentAvail - 1;
    await DatabaseHelper.instance.updateParking(id, {'availablePlaces': newAvail});

    // Schedule reminder at (now + hours - 5 minutes)
    final DateTime now = DateTime.now();
    DateTime when = now.add(Duration(hours: hours)).subtract(const Duration(minutes: 5));
    if (!when.isAfter(now)) {
      when = now.add(const Duration(minutes: 1));
    }
    await NotificationService.instance.scheduleReminder(
      id: id,
      title: 'Rappel de réservation',
      body: 'Votre réservation se termine dans 5 minutes. Pensez à libérer la place.',
      when: when,
    );
    // Persist reservation
    await DatabaseHelper.instance.createReservation(
      userId: widget.currentUserId,
      parkingId: id,
      hours: hours,
      startAt: now,
      endAt: now.add(Duration(hours: hours)),
      status: 'active',
    );
    if (!mounted) return;
    setState(() {
      // Mettre à jour via nouvelles listes (évite les listes en lecture seule)
      _allParkings = _allParkings.map((e) {
        final dynamic rid = e['id'];
        final int? eid = rid is int ? rid : int.tryParse(rid?.toString() ?? '');
        if (eid == id) {
          return {
            ...e,
            'availablePlaces': newAvail,
          };
        }
        return e;
      }).toList();

      _filteredParkings = _filteredParkings.map((e) {
        final dynamic rid = e['id'];
        final int? eid = rid is int ? rid : int.tryParse(rid?.toString() ?? '');
        if (eid == id) {
          return {
            ...e,
            'availablePlaces': newAvail,
          };
        }
        return e;
      }).toList();
      _reservedIds.add(id);
    });
    // refresh reservations list
    await _loadReservations();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Place réservée')),
    );
    // Afficher le QR code via API externe
    await _showQrForReservation(id: id, hours: hours, endAt: now.add(Duration(hours: hours)));
  }

  Future<void> _cancelReservation(Map<String, dynamic> p, int filteredIndex) async {
    final dynamic rawId = p['id'];
    final int? id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
    if (id == null) return;
    final int currentAvail = int.tryParse((p['availablePlaces'] ?? '').toString()) ?? (p['availablePlaces'] ?? 0);
    final int newAvail = currentAvail + 1;
    await DatabaseHelper.instance.updateParking(id, {'availablePlaces': newAvail});
    await NotificationService.instance.cancel(id);
    await DatabaseHelper.instance.cancelReservationByParking(widget.currentUserId, id);
    if (!mounted) return;
    setState(() {
      _allParkings = _allParkings.map((e) {
        final dynamic rid = e['id'];
        final int? eid = rid is int ? rid : int.tryParse(rid?.toString() ?? '');
        if (eid == id) {
          return {
            ...e,
            'availablePlaces': newAvail,
          };
        }
        return e;
      }).toList();
      _filteredParkings = _filteredParkings.map((e) {
        final dynamic rid = e['id'];
        final int? eid = rid is int ? rid : int.tryParse(rid?.toString() ?? '');
        if (eid == id) {
          return {
            ...e,
            'availablePlaces': newAvail,
          };
        }
        return e;
      }).toList();
      _reservedIds.remove(id);
    });
    await _loadReservations();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Réservation annulée')), 
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
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        scrollable: true,
        title: Row(
          children: const [
            Icon(Icons.report_gmailerrorred_outlined, color: Colors.redAccent),
            SizedBox(width: 8),
            Expanded(child: Text('Nouvelle réclamation', overflow: TextOverflow.ellipsis)),
          ],
        ),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 280, maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Type de réclamation',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                    onChanged: (v) => type = v,
                    validator: (v) => (v == null || v.isEmpty) ? 'Veuillez choisir un type' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'Décrivez votre problème avec détails...',
                      prefixIcon: Icon(Icons.edit_outlined),
                      helperText: 'Soyez le plus précis possible (max ~300 caractères)',
                      counterText: '',
                    ),
                    maxLength: 300,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Description requise' : null,
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          OutlinedButton.icon(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(ctx).pop(),
            label: const Text('Annuler'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.send_rounded),
            onPressed: () async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              final t = type!;
              final d = descCtrl.text.trim();
              await DatabaseHelper.instance.createReclamation(widget.currentUserId, t, d);
              if (!mounted) return;
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Réclamation envoyée')));
            },
            label: const Text('Envoyer'),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadParkings();
    _searchController.addListener(() {
      _applyFilter(_searchController.text);
    });
    _loadReservations();
    _loadUser();
  }

  Future<void> _loadParkings() async {
    final data = await DatabaseHelper.instance.getAllParkings();
    if (!mounted) return;
    setState(() {
      _allParkings = List<Map<String, dynamic>>.from(data);
      _filteredParkings = List<Map<String, dynamic>>.from(_allParkings);
      _loading = false;
    });
  }

  Future<void> _loadReservations() async {
    final data = await DatabaseHelper.instance.getUserReservations(widget.currentUserId);
    if (!mounted) return;
    setState(() {
      _reservations = List<Map<String, dynamic>>.from(data);
    });
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
      _photoUrl = picked.path; // local file path
    });
  }

  void _applyFilter(String value) {
    final q = value.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filteredParkings = List<Map<String, dynamic>>.from(_allParkings);
      } else {
        _filteredParkings = _allParkings.where((p) {
          final haystack = [
            p['nom'] ?? '',
            p['region'] ?? '',
            p['cite'] ?? '',
            p['rue'] ?? '',
            p['description'] ?? '',
          ].join(' ').toLowerCase();
          return haystack.contains(q);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_tabIndex == 0) {
      body = SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Barre de recherche
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Colors.grey),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Rechercher par nom ou lieu (tous par défaut)',
                        border: InputBorder.none,
                        hintStyle: TextStyle(color: Colors.grey[400]),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Catégories
            Text(
              'Catégories',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 100,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildCategoryItem(context, Icons.local_parking, 'Tous', true),
                  _buildCategoryItem(context, Icons.directions_car, 'Voiture', false),
                  _buildCategoryItem(context, Icons.two_wheeler, 'Moto', false),
                  _buildCategoryItem(context, Icons.electric_car, 'Électrique', false),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Section des parkings
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'À proximité',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () => _applyFilter(''),
                  child: const Text('Voir tout'),
                ),
              ],
            ),

            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_filteredParkings.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('Aucun parking trouvé')),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _filteredParkings.length,
                itemBuilder: (context, index) {
                  final p = _filteredParkings[index];
                  final String nom = (p['nom'] ?? '').toString();
                  final String region = (p['region'] ?? '').toString();
                  final String cite = (p['cite'] ?? '').toString();
                  final String rue = (p['rue'] ?? '').toString();
                  final int available = int.tryParse((p['availablePlaces'] ?? '').toString()) ?? (p['availablePlaces'] ?? 0);
                  final int total = int.tryParse((p['totalPlaces'] ?? '').toString()) ?? (p['totalPlaces'] ?? 0);
                  final double? ph = p['prixHeure'] == null ? null : (double.tryParse(p['prixHeure'].toString()) ?? p['prixHeure']);
                  final double? pj = p['prixJour'] == null ? null : (double.tryParse(p['prixJour'].toString()) ?? p['prixJour']);
                  final String addr = [rue, cite, region].where((s) => s.isNotEmpty).join(', ');

                  final double? promoPercent = p['promoPercent'] == null ? null : (double.tryParse(p['promoPercent'].toString()) ?? p['promoPercent']);
                  final String? promoStartStr = (p['promoStart']?.toString().isEmpty ?? true) ? null : p['promoStart']?.toString();
                  final String? promoEndStr = (p['promoEnd']?.toString().isEmpty ?? true) ? null : p['promoEnd']?.toString();
                  final DateTime? promoStart = promoStartStr == null ? null : DateTime.tryParse(promoStartStr);
                  final DateTime? promoEnd = promoEndStr == null ? null : DateTime.tryParse(promoEndStr);
                  final DateTime now = DateTime.now();
                  final bool promoActive = (promoPercent != null && promoPercent > 0 && promoPercent <= 100)
                      && (promoStart == null || !now.isBefore(promoStart))
                      && (promoEnd == null || !now.isAfter(promoEnd));
                  final double? phDisc = (ph != null && promoActive) ? (ph * (1 - (promoPercent / 100))).toDouble() : null;
                  final double? pjDisc = (pj != null && promoActive) ? (pj * (1 - (promoPercent / 100))).toDouble() : null;

                  final dynamic rawId = p['id'];
                  final int? id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
                  final bool isReserved = id != null && _reservedIds.contains(id);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (promoActive)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.redAccent),
                                ),
                                child: Text(
                                  '-${promoPercent.toStringAsFixed(0)}% PROMO',
                                  style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                            if (promoActive) const SizedBox(height: 6),
                            Text(
                              nom,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              addr.isEmpty ? 'Adresse non spécifiée' : addr,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Dispo: $available / $total',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
                                ),
                                if (ph == null)
                                  const Text('-')
                                else
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      if (promoActive)
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              '${ph.toStringAsFixed(2)} TND/h',
                                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                    color: Colors.grey,
                                                    decoration: TextDecoration.lineThrough,
                                                  ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              '${(phDisc ?? ph).toStringAsFixed(2)} TND/h',
                                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                                    color: Theme.of(context).colorScheme.primary,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                          ],
                                        )
                                      else
                                        Text(
                                          '${ph.toStringAsFixed(2)} TND/h',
                                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                                color: Theme.of(context).colorScheme.primary,
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                      if (pj != null)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2),
                                          child: promoActive
                                              ? Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      '${pj.toStringAsFixed(2)} TND/j',
                                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                            color: Colors.grey,
                                                            decoration: TextDecoration.lineThrough,
                                                          ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      '${(pjDisc ?? pj).toStringAsFixed(2)} TND/j',
                                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                            color: Theme.of(context).colorScheme.primary,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                    ),
                                                  ],
                                                )
                                              : Text(
                                                  '${pj.toStringAsFixed(2)} TND/j',
                                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                        color: Theme.of(context).colorScheme.primary,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                ),
                                        ),
                                    ],
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            isReserved
                                ? OutlinedButton(
                                    onPressed: () => _cancelReservation(p, index),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      side: const BorderSide(color: Colors.red),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    ),
                                    child: const Text('Quitter'),
                                  )
                                : ElevatedButton(
                                    onPressed: () => _reserveSpot(p, index),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Theme.of(context).colorScheme.primary,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    ),
                                    child: const Text('Réserver', style: TextStyle(color: Colors.white)),
                                  ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      );
    } else if (_tabIndex == 1) {
      // Réclamation tab
      body = Center(
        child: ElevatedButton.icon(
          onPressed: _openReclamationForm,
          icon: const Icon(Icons.report_problem),
          label: const Text('Faire une réclamation'),
        ),
      );
    } else if (_tabIndex == 2) {
      // Réservations tab
      body = _reservations.isEmpty
          ? const Center(child: Text('Aucune réservation'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _reservations.length,
              itemBuilder: (ctx, i) {
                final r = _reservations[i];
                final start = DateTime.tryParse((r['startAt'] ?? '').toString());
                final end = DateTime.tryParse((r['endAt'] ?? '').toString());
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const Icon(Icons.local_parking),
                    title: Text('Parking #${r['parkingId']} • ${r['hours']}h'),
                    subtitle: Text('${start?.toLocal().toString().substring(0, 16)} → ${end?.toLocal().toString().substring(0, 16)}\nStatut: ${r['status']}'),
                  ),
                );
              },
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
                      'Mon profil',
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
        title: const Text('EasyParque', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: body,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabIndex,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (i) async {
          setState(() => _tabIndex = i);
          if (i == 2) {
            await _loadReservations();
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Accueil'),
          BottomNavigationBarItem(icon: Icon(Icons.report), label: 'Réclamation'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt), label: 'Réservations'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _hoursCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<int?> _promptReservationHours() async {
    _hoursCtrl.text = _hoursCtrl.text.isEmpty ? '1' : _hoursCtrl.text;
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Durée de réservation'),
          content: TextField(
            controller: _hoursCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "Nombre d'heures",
              hintText: 'Ex: 1',
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annuler')),
            TextButton(
              onPressed: () {
                final h = int.tryParse(_hoursCtrl.text.trim());
                if (h == null || h <= 0) {
                  Navigator.of(ctx).pop();
                } else {
                  Navigator.of(ctx).pop(h);
                }
              },
              child: const Text('Valider'),
            ),
          ],
        );
      },
    );
    return result;
  }

  Future<void> _showQrForReservation({required int id, required int hours, required DateTime endAt}) async {
    final payload = {
      'parkingId': id,
      'hours': hours,
      'endAt': endAt.toIso8601String(),
    };
    final dataString = Uri.encodeComponent(payload.toString());
    final url = 'https://api.qrserver.com/v1/create-qr-code/?size=240x240&data=' + dataString;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Votre code QR de réservation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.network(url, width: 240, height: 240),
            const SizedBox(height: 12),
            const Text("Scannez ce code à l'entrée du parking."),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Fermer')),
        ],
      ),
    );
  }

  Widget _buildCategoryItem(
      BuildContext context, IconData icon, String label, bool isSelected) {
    return Container(
      width: 90,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: isSelected
            ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isSelected
            ? Border.all(color: Theme.of(context).colorScheme.primary)
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color:
                isSelected ? Theme.of(context).colorScheme.primary : Colors.grey,
            size: 28,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
