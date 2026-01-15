import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/cart_service.dart';
import '../../models/product_model.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool _isLoading = false;

  // --- NOUVELLE VERSION AVEC PLAFOND DE 300 POINTS ---
  Future<void> _submitOrder(BuildContext context, CartService cart, bool isPremium) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      // 1. Calculs financiers
      final double basePrice = cart.totalPrice;
      final double discountAmount = isPremium ? basePrice * 0.10 : 0.0;
      final double finalPrice = basePrice - discountAmount;
      final int pointsEarned = basePrice.floor(); 

      // Préparation des items
      final List<Map<String, dynamic>> orderItems = cart.items.map((item) => {
        'productId': item.id,
        'nom': item.name,
        'prix': item.price,
        'quantite': 1 
      }).toList();

      // 2. TRANSACTION SÉCURISÉE (Lecture + Écriture)
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // A. Références
        final userRef = FirebaseFirestore.instance.collection('user').doc(user.uid);
        final newOrderRef = userRef.collection('commande').doc();
        final newLogRef = FirebaseFirestore.instance.collection('log').doc();

        // B. Lecture du solde actuel
        final userSnapshot = await transaction.get(userRef);
        if (!userSnapshot.exists) throw Exception("Profil introuvable");

        final int currentPoints = userSnapshot['point'] ?? 0;
        
        // C. Application du PLAFOND de 300
        int newBalance = currentPoints + pointsEarned;
        if (newBalance > 300) {
          newBalance = 300; // On coupe l'excédent
        }

        // D. Écritures
        // Création de la commande
        transaction.set(newOrderRef, {
          'date': FieldValue.serverTimestamp(),
          'items': orderItems,
          'prixSansReduction': basePrice,
          'reductionAppliquee': discountAmount,
          'totalPaiement': finalPrice,
          'pointGagne': pointsEarned, // On note quand même combien il "aurait" gagné
        });

        // Mise à jour du User
        transaction.update(userRef, {
          'point': newBalance, // Valeur plafonnée à 300
          // Le niveau fidélité (score à vie), lui, n'est PAS plafonné
          'niveauFidelite': FieldValue.increment(pointsEarned), 
        });

        // Log
        transaction.set(newLogRef, {
          'action': 'NOUVELLE_COMMANDE',
          'userId': user.uid,
          'date': FieldValue.serverTimestamp(),
          'detail': 'Commande de ${finalPrice.toStringAsFixed(2)}€',
          'levelError': 'INFO'
        });
      });

      // 3. Succès
      cart.clear();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text("Commande validée ! (Attention 300 points maximum !)")),
        );
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final cart = Provider.of<CartService>(context); // Écoute le panier

    return Scaffold(
      appBar: AppBar(title: const Text("Mon Panier")),
      body: cart.items.isEmpty
          ? const Center(child: Text("Votre panier est vide..."))
          : StreamBuilder<DocumentSnapshot>(
              // On écoute le user pour savoir s'il est PREMIUM en temps réel
              stream: FirebaseFirestore.instance.collection('user').doc(user?.uid).snapshots(),
              builder: (context, snapshot) {
                // Par défaut, pas premium si ça charge ou erreur
                bool isPremium = false;
                if (snapshot.hasData && snapshot.data!.exists) {
                  final data = snapshot.data!.data() as Map<String, dynamic>;
                  isPremium = data['isPremium'] ?? false;
                }

                // --- CALCULS D'AFFICHAGE ---
                final double totalBase = cart.totalPrice;
                final double reduction = isPremium ? totalBase * 0.10 : 0.0;
                final double totalFinal = totalBase - reduction;
                final int futurePoints = totalBase.floor(); // Points sur prix de base

                return Column(
                  children: [
                    // --- LISTE DES ARTICLES ---
                    Expanded(
                      child: ListView.separated(
                        itemCount: cart.items.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (context, index) {
                          final item = cart.items[index];
                          return ListTile(
                            leading: item.imageUrl.isNotEmpty 
                              ? Image.asset("assets/images/${item.imageUrl}", width: 50, height: 50, fit: BoxFit.cover)
                              : const Icon(Icons.fastfood),
                            title: Text(item.name),
                            subtitle: Text("${item.price} €"),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => cart.remove(item),
                            ),
                          );
                        },
                      ),
                    ),

                    // --- RÉSUMÉ FINANCIER ---
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, -5))],
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      child: Column(
                        children: [
                          _buildPriceLine("Sous-total", totalBase, isBold: false),
                          
                          if (isPremium)
                            _buildPriceLine("Réduction Premium (-10%)", -reduction, color: Colors.green),
                          
                          if (!isPremium)
                             Padding(
                               padding: const EdgeInsets.only(bottom: 8.0),
                               child: Row(
                                 children: const [
                                   Icon(Icons.info_outline, size: 16, color: Colors.grey),
                                   SizedBox(width: 5),
                                   Text("Devenez Premium pour économiser 10% !", style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic)),
                                 ],
                               ),
                             ),

                          const Divider(),
                          _buildPriceLine("TOTAL À PAYER", totalFinal, isBold: true, fontSize: 20),
                          
                          const SizedBox(height: 10),
                          Text("Vous gagnerez +$futurePoints points fidélité", 
                            style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // --- BOUTON PAYER ---
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : () => _submitOrder(context, cart, isPremium),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                              child: _isLoading 
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text("COMMANDER ET PAYER", style: TextStyle(fontSize: 18)),
                            ),
                          )
                        ],
                      ),
                    )
                  ],
                );
              },
            ),
    );
  }

  Widget _buildPriceLine(String label, double amount, {bool isBold = false, Color? color, double fontSize = 16}) {
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