import 'package:flutter/material.dart';
import '../data/database_helper.dart';
import '../notifications/notification_service.dart';
import 'login.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Réservation annulée')), 
    );
  }

  @override
  void initState() {
    super.initState();
    _loadParkings();
    _searchController.addListener(() {
      _applyFilter(_searchController.text);
    });
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
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'EasyParque',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
          IconButton(
            tooltip: 'Se déconnecter',
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
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
                                Text(
                                  ph == null ? '-' : '${ph.toStringAsFixed(2)} TND/h${pj != null ? ' • ${pj.toStringAsFixed(2)} TND/j' : ''}',
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                        color: Theme.of(context).colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
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
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Accueil'),
          BottomNavigationBarItem(icon: Icon(Icons.location_on), label: 'Carte'),
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
