import 'package:flutter/material.dart';
import '../data/database_helper.dart';
import 'login.dart';

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

  @override
  void initState() {
    super.initState();
    _loadMyParkings();
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Espace Parking Responsable', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
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
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                widget.currentUserEmail,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_parkings.isEmpty
              ? const Center(child: Text('Aucun parking. Ajoutez-en un avec le bouton +'))
              : ListView.builder(
              itemCount: _parkings.length,
              itemBuilder: (context, index) {
                final p = _parkings[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: ListTile(
                    title: Text(p['nom'] ?? ''),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p['description'] ?? ''),
                        const SizedBox(height: 4),
                        Text('Localisation: ${p['region']}, ${p['cite']}, ${p['rue']} - ${p['numeroBloc']}'),
                        Text('Capacité: ${p['availablePlaces']}/${p['totalPlaces']}'),
                        Text('Tarif: ${p['prixHeure']} TND/h  |  ${p['prixJour'] ?? '-'} TND/j'),
                        Text('Contact: ${p['telephone']}'),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Modifier',
                          onPressed: () => _showEditParkingForm(p, index),
                          icon: const Icon(Icons.edit, color: Colors.blueAccent),
                        ),
                        IconButton(
                          tooltip: 'Supprimer',
                          onPressed: () => _confirmDelete(p, index),
                          icon: const Icon(Icons.delete, color: Colors.redAccent),
                        ),
                      ],
                    ),
                  ),
                );
              },
            )),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddParkingForm,
        icon: const Icon(Icons.add),
        label: const Text('Ajouter parking'),
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
      'telephone': _phoneCtrl.text.trim(),
    };
    Navigator.of(context).pop(data);
  }
}

