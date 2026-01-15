import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  // Petite fonction pour formater la date proprement sans librairie externe
  String _formatDate(Timestamp timestamp) {
    final DateTime date = timestamp.toDate();
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} à ${date.hour}h${date.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text("Mes Commandes")),
      body: StreamBuilder<QuerySnapshot>(
        // On récupère la sous-collection 'commande' de l'utilisateur
        // On trie par date décroissante (le plus récent en haut)
        stream: FirebaseFirestore.instance
            .collection('user')
            .doc(user?.uid)
            .collection('commande')
            .orderBy('date', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          // 1. Chargement
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          // 2. Erreur
          if (snapshot.hasError) {
            return const Center(child: Text("Erreur de chargement"));
          }
          // 3. Vide
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.receipt_long, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text("Aucune commande pour l'instant", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          final orders = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final orderData = orders[index].data() as Map<String, dynamic>;
              final orderId = orders[index].id; // L'ID du document

              // Extraction sécurisée des données
              final double total = (orderData['totalPaiement'] ?? 0).toDouble();
              final int points = orderData['pointGagne'] ?? 0;
              final Timestamp? dateTs = orderData['date'];
              final String dateStr = dateTs != null ? _formatDate(dateTs) : "Date inconnue";
              final int itemCount = (orderData['items'] as List?)?.length ?? 0;

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange.shade100,
                    child: const Icon(Icons.fastfood, color: Colors.orange),
                  ),
                  title: Text(
                    dateStr,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text("$itemCount articles"),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "${total.toStringAsFixed(2)} €",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        "+$points pts",
                        style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  onTap: () {
                    // Navigation vers le détail de la commande
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => _OrderDetailScreen(
                          orderId: orderId,
                          data: orderData,
                          dateStr: dateStr,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// --- ÉCRAN DE DÉTAIL (INTERNE) ---
// Je le mets dans le même fichier pour simplifier, c'est une sous-page dédiée
class _OrderDetailScreen extends StatelessWidget {
  final String orderId;
  final Map<String, dynamic> data;
  final String dateStr;

  const _OrderDetailScreen({
    required this.orderId,
    required this.data,
    required this.dateStr,
  });

  @override
  Widget build(BuildContext context) {
    // Récupération des listes et infos
    final List<dynamic> items = data['items'] ?? [];
    final double prixBase = (data['prixSansReduction'] ?? 0).toDouble();
    final double reduction = (data['reductionAppliquee'] ?? 0).toDouble();
    final double totalFinal = (data['totalPaiement'] ?? 0).toDouble();
    final int points = data['pointGagne'] ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text("Détail commande")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Ticket
            Center(
              child: Column(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 60),
                  const SizedBox(height: 10),
                  const Text("Commande terminée", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  Text(dateStr, style: const TextStyle(color: Colors.grey)),
                  Text("ID: ${orderId.substring(0, 8)}...", style: const TextStyle(color: Colors.grey, fontSize: 10)),
                ],
              ),
            ),
            const Divider(height: 40),

            // Liste des produits
            const Text("Vos produits", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            ListView.builder(
              shrinkWrap: true, // Important pour être dans un ScrollView
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index] as Map<String, dynamic>;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("${item['quantite']}x ${item['nom']}"),
                      Text("${(item['prix'] as num).toStringAsFixed(2)} €"),
                    ],
                  ),
                );
              },
            ),
            const Divider(height: 30),

            // Résumé Financier
            _buildRow("Sous-total", prixBase),
            if (reduction > 0)
              _buildRow("Réduction Premium", -reduction, color: Colors.green),
            const Divider(),
            _buildRow("TOTAL PAYÉ", totalFinal, isBold: true, fontSize: 18),
            
            const SizedBox(height: 20),
            
            // Résumé Points
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200)
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.stars, color: Colors.orange),
                  const SizedBox(width: 10),
                  Text(
                    "Vous avez gagné $points points !",
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, double amount, {bool isBold = false, Color? color, double fontSize = 14}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color)),
          Text("${amount.toStringAsFixed(2)} €", style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color)),
        ],
      ),
    );
  }
}