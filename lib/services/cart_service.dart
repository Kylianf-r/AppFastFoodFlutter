import 'package:flutter/material.dart';
import '../models/product_model.dart';

class CartService extends ChangeNotifier {
  // La liste des produits dans le panier
  final List<Product> _items = [];

  // Getter pour lire la liste (sans pouvoir la modifier directement de l'extérieur)
  List<Product> get items => _items;

  // Calcul du total
  double get totalPrice => _items.fold(0, (sum, item) => sum + item.price);

  // Nombre d'articles
  int get count => _items.length;

  // Ajouter un produit
  void add(Product product) {
    // Règle du sujet : "Choix de 1 ou 2 menus". 
    // On peut limiter ici si tu veux, ou juste laisser libre pour l'instant.
    _items.add(product);
    notifyListeners(); // Dit à toute l'appli : "Le panier a changé !"
  }

  // Retirer un produit
  void remove(Product product) {
    _items.remove(product);
    notifyListeners();
  }

  // Vider le panier
  void clear() {
    _items.clear();
    notifyListeners();
  }
}