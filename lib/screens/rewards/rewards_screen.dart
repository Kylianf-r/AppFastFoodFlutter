import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  // Catégorie sélectionnée pour le filtre
  String _selectedCategory = "Tout";
  final List<String> _categories = ["Tout", "Boisson", "Dessert", "Menu"];

  bool _isLoading = false;

  // --- LOGIQUE D'ACHAT DE RÉCOMPENSE ---
  Future<void> _unlockReward(String rewardId, String name, int cost) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Petite boîte de dialogue de confirmation
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Obtenir $name ?"),
        content: Text("Cela vous coûtera $cost points."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Annuler")),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Confirmer")),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      // Transaction sécurisée (Même logique que le Don)
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // 1. Lire le solde actuel
        final userDocRef = FirebaseFirestore.instance.collection('user').doc(user.uid);
        final userSnapshot = await transaction.get(userDocRef);

        if (!userSnapshot.exists) throw Exception("Utilisateur introuvable");

        final int currentPoints = userSnapshot['point'] ?? 0;

        // 2. Vérifier si assez de points
        if (currentPoints < cost) {
          throw Exception("Points insuffisants ! Mangez plus de burgers d'abord.");
        }

        // 3. Débiter les points
        transaction.update(userDocRef, {
          'point': FieldValue.increment(-cost) // On enlève les points
          // NOTE: On ne touche PAS au 'niveauFidelite', car c'est un score à vie.
        });

        // 4. Loguer l'échange
        final logRef = FirebaseFirestore.instance.collection('log').doc();
        transaction.set(logRef, {
          'action': 'RECOMPENSE_DEBLOQUEE',
          'userId': user.uid,
          'rewardName': name,
          'cost': cost,
          'date': FieldValue.serverTimestamp(),
          'detail': 'Achat récompense : $name',
          'levelError': 'INFO'
        });
      });

      if (mounted) {
        // Succès visuel
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(child: Text("Félicitations ! Vous avez obtenu : $name")),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur : ${e.toString().replaceAll('Exception: ', '')}"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text("Mes Récompenses")),
      body: Column(
        children: [
          // --- HEADER : SOLDE ---
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('user').doc(user?.uid).snapshots(),
            builder: (context, snapshot) {
              int myPoints = 0;
              if (snapshot.hasData && snapshot.data!.exists) {
                myPoints = snapshot.data!['point'] ?? 0;
              }
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: Colors.orange.shade50,
                child: Column(
                  children: [
                    const Text("VOTRE SOLDE ACTUEL", style: TextStyle(letterSpacing: 1.2, fontSize: 12, color: Colors.orange)),
                    Text("$myPoints pts", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                  ],
                ),
              );
            },
          ),

          // --- FILTRES (Catégories) ---
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    selectedColor: Colors.orange,
                    labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedCategory = cat);
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          // --- LISTE DES RÉCOMPENSES ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('recompense').orderBy('pointprix').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("Aucune récompense configurée."));
                }

                // Filtrage Côté Client (car filtrer + trier en Firestore demande des index complexes)
                final rewards = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  if (_selectedCategory == "Tout") return true;
                  // On compare la catégorie (attention à la casse dans ta BDD)
                  // J'utilise toLowerCase() pour être sûr que "Dessert" matche "dessert"
                  final catBDD = (data['categorie'] ?? "").toString().toLowerCase();
                  return catBDD == _selectedCategory.toLowerCase();
                }).toList();

                // On a besoin du solde utilisateur pour savoir si on grise le bouton
                return StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('user').doc(user?.uid).snapshots(),
                  builder: (context, userSnap) {
                    int userPoints = 0;
                    if (userSnap.hasData) userPoints = userSnap.data!['point'] ?? 0;

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: rewards.length,
                      itemBuilder: (context, index) {
                        final data = rewards[index].data() as Map<String, dynamic>;
                        final String name = data['nom'] ?? 'Cadeau mystère';
                        final int cost = data['pointprix'] ?? 9999;
                        final String imageUrl = data['imageUrl'] ?? '';
                        final String desc = data['description'] ?? '';

                        final bool canAfford = userPoints >= cost;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          // Si pas abordable, on grise un peu la carte
                          color: canAfford ? Colors.white : Colors.grey.shade100,
                          child: Column(
                            children: [
                              // Image
                              Container(
                                height: 120,
                                decoration: BoxDecoration(
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                                  color: Colors.grey.shade300,
                                  image: imageUrl.isNotEmpty
                                    ? DecorationImage(image: AssetImage("assets/images/$imageUrl"), fit: BoxFit.cover)
                                    : null,
                                ),
                                child: imageUrl.isEmpty 
                                  ? const Center(child: Icon(Icons.card_giftcard, size: 50, color: Colors.white))
                                  : null,
                              ),
                              
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                          Text(desc, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                          const SizedBox(height: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: canAfford ? Colors.orange.shade100 : Colors.red.shade50,
                                              borderRadius: BorderRadius.circular(8)
                                            ),
                                            child: Text(
                                              "$cost points",
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold, 
                                                color: canAfford ? Colors.deepOrange : Colors.red
                                              ),
                                            ),
                                          )
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    ElevatedButton(
                                      onPressed: canAfford && !_isLoading 
                                        ? () => _unlockReward(rewards[index].id, name, cost)
                                        : null, // Bouton désactivé si pas assez de points
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: canAfford ? Colors.orange : Colors.grey,
                                        shape: const CircleBorder(),
                                        padding: const EdgeInsets.all(16),
                                      ),
                                      child: _isLoading 
                                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                        : Icon(canAfford ? Icons.lock_open : Icons.lock, color: Colors.white),
                                    )
                                  ],
                                ),
                              )
                            ],
                          ),
                        );
                      },
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