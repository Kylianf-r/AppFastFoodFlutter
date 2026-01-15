import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

// Imports de tes modèles et services
import '../../models/product_model.dart';
import '../../services/cart_service.dart';
import '../cart/cart_screen.dart'; // <--- L'import crucial pour la navigation

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Commander"),
        actions: [
          // --- BOUTON PANIER ---
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Consumer<CartService>(
              builder: (context, cart, child) {
                return IconButton(
                  onPressed: () {
                    // C'est ici qu'on navigue vers l'écran Panier
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CartScreen()),
                    );
                  },
                  icon: Badge(
                    label: Text(cart.count.toString()), // Affiche le nombre d'articles
                    isLabelVisible: cart.count > 0,     // Cache le badge si 0
                    child: const Icon(Icons.shopping_cart),
                  ),
                );
              },
            ),
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        // On récupère uniquement les produits où "Actif" est vrai
        stream: FirebaseFirestore.instance
            .collection('produit')
            .where('actif', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          // 1. Chargement
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          // 2. Erreur
          if (snapshot.hasError) {
            return const Center(child: Text("Oups, une erreur est survenue."));
          }
          // 3. Pas de données
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Aucun produit disponible pour le moment."));
          }

          // 4. On transforme les documents en objets Product
          final products = snapshot.data!.docs.map((doc) {
            return Product.fromFirestore(doc);
          }).toList();

          // 5. Affichage de la Grille
          return GridView.builder(
            padding: const EdgeInsets.all(10),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,       // 2 colonnes
              childAspectRatio: 0.75,  // Format un peu plus haut que large
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: products.length,
            itemBuilder: (context, index) {
              return _ProductCard(product: products[index]);
            },
          );
        },
      ),
    );
  }
}

// --- WIDGET CARTE PRODUIT ---
class _ProductCard extends StatelessWidget {
  final Product product;

  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    // On récupère le service panier pour pouvoir ajouter des items
    final cart = Provider.of<CartService>(context, listen: false);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // IMAGE
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                image: product.imageUrl.isNotEmpty
                    ? DecorationImage(
                        image: AssetImage("assets/images/${product.imageUrl}"),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: product.imageUrl.isEmpty
                  ? const Icon(Icons.fastfood, size: 50, color: Colors.grey) // Image par défaut
                  : null,
            ),
          ),
          
          // INFORMATIONS
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  product.description,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                
                // PRIX + BOUTON AJOUTER
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "${product.price.toStringAsFixed(2)} €",
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 16),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.orange, size: 30),
                      onPressed: () {
                        // Action d'ajout au panier
                        cart.add(product);
                        
                        // Petit message de confirmation
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("${product.name} ajouté au panier !"),
                            duration: const Duration(seconds: 1),
                            behavior: SnackBarBehavior.floating, // Flotte au-dessus du bas
                          ),
                        );
                      },
                    )
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}