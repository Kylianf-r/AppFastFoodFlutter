import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final bool isActive;
  final String category;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.isActive,
    required this.category,
  });

  // Factory pour créer un Produit depuis un document Firestore
  factory Product.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Product(
      id: doc.id,
      name: data['nom'] ?? 'Produit sans nom',
      description: data['description'] ?? '',
      // Astuce : on convertit en double peu importe si c'est int ou double dans la BDD
      price: (data['prix'] ?? 0).toDouble(), 
      imageUrl: data['imageUrl'] ?? '',
      isActive: data['actif'] ?? false,
      // On récupère la catégorie (ou "divers" par défaut si vide)
      category: data['categorie'] ?? 'divers',
    );
  }
}