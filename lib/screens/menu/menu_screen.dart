import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

// Imports de tes modèles et services
import '../../models/product_model.dart';
import '../../services/cart_service.dart';
import '../cart/cart_screen.dart';

// ON PASSE EN STATEFULWIDGET POUR GÉRER L'ÉTAT DU FILTRE
class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  // Gestion du filtre sélectionné
  String _selectedCategory = "Menu";
  
  // Liste des filtres disponibles
  final List<String> _categories = ["Menu", "Burger", "Boisson", "Dessert"];

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
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CartScreen()),
                    );
                  },
                  icon: Badge(
                    label: Text(cart.count.toString()),
                    isLabelVisible: cart.count > 0,
                    child: const Icon(Icons.shopping_cart),
                  ),
                );
              },
            ),
          )
        ],
      ),
      body: Column(
        children: [
          // --- BARRE DE FILTRES ---
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: _categories.map((category) {
                  final isSelected = _selectedCategory == category;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(category),
                      selected: isSelected,
                      selectedColor: Colors.orange,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedCategory = category);
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // --- GRILLE DES PRODUITS ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('produit')
                  .where('actif', isEqualTo: true) // Attention à la majuscule/minuscule selon ta BDD
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(child: Text("Oups, une erreur est survenue."));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("Aucun produit disponible."));
                }

                // 1. On transforme tout en liste de produits
                final allProducts = snapshot.data!.docs.map((doc) {
                  return Product.fromFirestore(doc);
                }).toList();

                // 2. On applique le filtre localement (Côté Dart)
                final filteredProducts = allProducts.where((product) {
                  if (_selectedCategory == "Tout") return true;
                  // On compare en minuscules pour éviter les soucis (ex: "Burger" vs "burger")
                  return product.category.toLowerCase() == _selectedCategory.toLowerCase();
                }).toList();

                if (filteredProducts.isEmpty) {
                  return const Center(
                    child: Text("Aucun produit dans cette catégorie."),
                  );
                }

                // 3. Affichage
                return GridView.builder(
                  padding: const EdgeInsets.all(10),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: filteredProducts.length,
                  itemBuilder: (context, index) {
                    return _ProductCard(product: filteredProducts[index]);
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

// --- WIDGET CARTE PRODUIT (Inchangé, sauf imports si besoin) ---
class _ProductCard extends StatelessWidget {
  final Product product;

  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartService>(context, listen: false);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                  ? const Icon(Icons.fastfood, size: 50, color: Colors.grey)
                  : null,
            ),
          ),
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
                        cart.add(product);
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("${product.name} ajouté !"),
                            duration: const Duration(seconds: 1),
                            behavior: SnackBarBehavior.floating,
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