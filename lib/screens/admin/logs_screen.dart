import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  // Filtre sélectionné par défaut : "Activité" (ce qui intéresse le plus souvent)
  String _selectedFilter = "Activité";
  
  final List<String> _filters = ["Activité", "Système & Erreurs"];

  // --- LOGIQUE DE TRI ---
  // On définit quelles actions vont dans quelle catégorie
  bool _isActivityLog(String action) {
    const activityActions = [
      'NOUVELLE_COMMANDE', 
      'DON_POINTS', 
      'RECOMPENSE_DEBLOQUEE',
      'SUPPRESSION_COMPTE'
    ];
    return activityActions.contains(action);
  }

  // --- HELPERS VISUELS ---
  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return "Date inconnue";
    final DateTime d = timestamp.toDate();
    return "${d.day}/${d.month}/${d.year} ${d.hour}h${d.minute.toString().padLeft(2, '0')}";
  }

  Color _getColor(String level, String action) {
    if (level == 'ERROR') return Colors.red.shade100;
    if (level == 'WARNING') return Colors.orange.shade100;
    if (action == 'CONNEXION') return Colors.blue.shade50;
    if (action == 'NOUVELLE_COMMANDE' || action == 'DON_POINTS') return Colors.green.shade50;
    return Colors.grey.shade50;
  }

  IconData _getIcon(String action, String level) {
    if (level == 'ERROR') return Icons.bug_report;
    switch (action) {
      case 'CONNEXION': return Icons.login;
      case 'NOUVELLE_COMMANDE': return Icons.shopping_bag;
      case 'DON_POINTS': return Icons.volunteer_activism;
      case 'RECOMPENSE_DEBLOQUEE': return Icons.card_giftcard;
      case 'SUPPRESSION_COMPTE': return Icons.person_off;
      case 'FLUTTER_CRASH': return Icons.dangerous;
      default: return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Journal d'activité"),
        backgroundColor: Colors.blueGrey,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // --- BARRE DE FILTRES ---
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: _filters.map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: ChoiceChip(
                    label: Text(filter),
                    selected: isSelected,
                    selectedColor: filter == "Activité" ? Colors.green.shade100 : Colors.red.shade100,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.black : Colors.grey,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedFilter = filter);
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          // --- LISTE DES LOGS ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('log')
                  .orderBy('date', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(child: Text("Erreur de chargement des logs"));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("Aucun log pour le moment."));
                }

                final allLogs = snapshot.data!.docs;

                // FILTRAGE LOCAL
                final filteredLogs = allLogs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final String action = data['action'] ?? '';
                  final String level = data['levelError'] ?? 'INFO';

                  // Si on est dans l'onglet "Activité"
                  if (_selectedFilter == "Activité") {
                    // On garde les actions métier
                    return _isActivityLog(action);
                  } 
                  // Si on est dans l'onglet "Système & Erreurs"
                  else {
                    // On garde tout ce qui N'EST PAS une activité (donc technique)
                    // OU ce qui est explicitement marqué comme ERREUR
                    return !_isActivityLog(action) || level == 'ERROR';
                  }
                }).toList();

                if (filteredLogs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.filter_list_off, size: 50, color: Colors.grey),
                        SizedBox(height: 10),
                        Text("Aucun événement dans cette catégorie."),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: filteredLogs.length,
                  itemBuilder: (context, index) {
                    final data = filteredLogs[index].data() as Map<String, dynamic>;
                    
                    final String action = data['action'] ?? 'ACTION';
                    final String detail = data['detail'] ?? '';
                    final String level = data['levelError'] ?? 'INFO';
                    final String userId = data['userId'] ?? 'Inconnu';
                    final Timestamp? date = data['date'];

                    return Card(
                      color: _getColor(level, action),
                      elevation: 1,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.white60,
                          child: Icon(_getIcon(action, level), color: Colors.black87),
                        ),
                        title: Text(
                          action, 
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(detail, maxLines: 2, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Text(
                              "${_formatDate(date)} • ID: $userId",
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade700, fontFamily: 'monospace'),
                            ),
                          ],
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}