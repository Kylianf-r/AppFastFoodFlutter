import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReviewsScreen extends StatelessWidget {
  const ReviewsScreen({super.key});

  // Fonction pour afficher la fenêtre d'ajout d'avis
  void _showAddReviewModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Permet au clavier de ne pas cacher le champ
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const _AddReviewForm(),
    );
  }

  // Helper pour formater la date
  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return "";
    final DateTime date = timestamp.toDate();
    return "${date.day}/${date.month}/${date.year}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Avis Clients")),
      
      // Le bouton "+" flottant pour ajouter un avis
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddReviewModal(context),
        label: const Text("Donner mon avis"),
        icon: const Icon(Icons.rate_review),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),

      body: StreamBuilder<QuerySnapshot>(
        // On récupère les avis triés par date (le plus récent en haut)
        stream: FirebaseFirestore.instance
            .collection('reviews')
            .orderBy('date', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.comment_bank, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text("Aucun avis pour le moment.", style: TextStyle(color: Colors.grey)),
                  Text("Soyez le premier !", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }

          final reviews = snapshot.data!.docs;

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: reviews.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final data = reviews[index].data() as Map<String, dynamic>;
              final double rating = (data['rating'] ?? 0).toDouble();
              final String comment = data['comment'] ?? "";
              final String pseudo = data['pseudo'] ?? "Anonyme";
              final Timestamp? dateTs = data['date'];

              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // En-tête : Pseudo + Date
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(pseudo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(_formatDate(dateTs), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      
                      // Étoiles (affichage statique)
                      Row(
                        children: List.generate(5, (index) {
                          return Icon(
                            index < rating ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 20,
                          );
                        }),
                      ),
                      const SizedBox(height: 10),
                      
                      // Commentaire
                      if (comment.isNotEmpty)
                        Text(comment, style: const TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// --- FORMULAIRE D'AJOUT D'AVIS (Widget Interne) ---
class _AddReviewForm extends StatefulWidget {
  const _AddReviewForm();

  @override
  State<_AddReviewForm> createState() => _AddReviewFormState();
}

class _AddReviewFormState extends State<_AddReviewForm> {
  final _commentController = TextEditingController();
  int _selectedRating = 5; // Note par défaut
  bool _isLoading = false;

  Future<void> _submitReview() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Merci d'écrire un petit commentaire !")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Récupérer le pseudo actuel de l'utilisateur pour le stocker dans l'avis
      // (Cela évite de devoir faire plein de lectures plus tard)
      final userDoc = await FirebaseFirestore.instance.collection('user').doc(user.uid).get();
      final String pseudo = userDoc.exists ? (userDoc['pseudo'] ?? 'Client') : 'Client';

      // 2. Créer l'avis
      await FirebaseFirestore.instance.collection('reviews').add({
        'userId': user.uid,
        'pseudo': pseudo,
        'rating': _selectedRating,
        'comment': _commentController.text.trim(),
        'date': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context); // Fermer la modale
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Merci pour votre avis !"), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Gestion du clavier qui remonte
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20, right: 20, top: 20
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Prend juste la place nécessaire
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Laisser un avis", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          
          const Text("Votre note :"),
          // --- SÉLECTEUR D'ÉTOILES ---
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return IconButton(
                onPressed: () {
                  setState(() => _selectedRating = index + 1);
                },
                icon: Icon(
                  index < _selectedRating ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 40,
                ),
              );
            }),
          ),
          
          const SizedBox(height: 20),
          
          TextField(
            controller: _commentController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: "Votre commentaire...",
              border: OutlineInputBorder(),
              hintText: "C'était délicieux ? Dites-le nous !"
            ),
          ),
          
          const SizedBox(height: 20),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitReview,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16)
              ),
              child: _isLoading 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white)) 
                : const Text("ENVOYER"),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}