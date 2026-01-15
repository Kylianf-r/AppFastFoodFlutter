import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Imports des futurs écrans
import '../rewards/rewards_screen.dart';
import '../history/history_screen.dart';
import '../donation/donation_screen.dart';
import '../reviews/reviews_screen.dart';
import '../admin/logs_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      // Pas d'AppBar classique, on veut un design plus "App de commande"
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('user').doc(user?.uid).snapshots(),
        builder: (context, snapshot) {
          // 1. Chargement / Erreur
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Erreur profil"));
          }

          // 2. Récupération des données
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final int points = data['point'] ?? 0;
          final bool isPremium = data['isPremium'] ?? false;
          final String prenom = data['prenom'] ?? 'Gourmand';
          final bool isAdmin = data['isAdmin'] ?? false;

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- HEADER DE BIENVENUE ---
                  Text(
                    "Bonjour, $prenom 👋",
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    "Envie de s'exploser le ventre aujourd'hui ?",
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                  const SizedBox(height: 20),

                  // --- CARTE FIDÉLITÉ (Points & Statut) ---
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isAdmin 
                            ? [const Color(0xFFD32F2F), const Color(0xFFEF5350)] // ROUGE SI ADMIN
                            : isPremium 
                                ? [Colors.purple.shade700, Colors.purple.shade400] 
                                : [Colors.orange.shade700, Colors.orange.shade400],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: isAdmin 
                            ? Colors.red.withOpacity(0.3) 
                            : (isPremium ? Colors.purple.withOpacity(0.3) : Colors.orange.withOpacity(0.3)),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "MES POINTS FIDÉLITÉ",
                              style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 1.2),
                            ),
                            // Badge Premium/Classique
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isPremium ? Icons.verified : Icons.person_outline,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    isAdmin ? "ADMIN" : (isPremium ? "PREMIUM" : "CLASSIQUE"),
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ],
                              ),
                            )
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "$points / 300",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          "points disponibles",
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),
                  
                  // --- GRILLE DE NAVIGATION ---
                  const Text("Accès rapide", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),

                  GridView.count(
                    shrinkWrap: true, // Important car dans une Column
                    physics: const NeverScrollableScrollPhysics(), // Pas de scroll interne
                    crossAxisCount: 2,
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 15,
                    childAspectRatio: 1.1,
                    children: [
                      // BOUTON 1 : RÉCOMPENSES
                      _MenuButton(
                        title: "Récompenses",
                        subtitle: "Produits offerts",
                        icon: Icons.card_giftcard,
                        color: Colors.pink,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const RewardsScreen()),
                          );
                        },
                      ),

                      // BOUTON 2 : HISTORIQUE
                      _MenuButton(
                        title: "Historique",
                        subtitle: "Mes commandes",
                        icon: Icons.receipt_long,
                        color: Colors.blue,
                        onTap: () {
                           Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const HistoryScreen()),
                          );
                        },
                      ),

                      // BOUTON 3 : DON DE POINTS
                      _MenuButton(
                        title: "Faire un don",
                        subtitle: "Offrir des points",
                        icon: Icons.volunteer_activism,
                        color: Colors.teal,
                        onTap: () {
                           Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const DonationScreen()),
                          );
                        },
                      ),

                      // BOUTON 4 : AVIS
                      _MenuButton(
                        title: "Avis",
                        subtitle: "Laissez un avis !",
                        icon: Icons.rate_review,
                        color: const Color.fromARGB(255, 255, 164, 28),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const ReviewsScreen()),
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // --- BOUTON ADMIN (Style "En long") ---
                  if (isAdmin)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20.0),
                      child: SizedBox(
                        width: double.infinity, // Prend toute la largeur
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const LogsScreen()),
                            );
                          },
                          // J'utilise une icône de sécurité
                          icon: const Icon(Icons.security),
                          label: const Text("ESPACE ADMIN - LOGS"),
                          style: OutlinedButton.styleFrom(
                            // Utilisation BlueGrey pour différencier du Rouge (Logout/Danger)
                            // Style (bordure, fond transparent) est identique
                            foregroundColor: Colors.blueGrey, 
                            side: const BorderSide(color: Colors.blueGrey, width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30), // Bords très arrondis (capsule)
                            ),
                            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// Petit widget pour uniformiser les boutons du menu
class _MenuButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MenuButton({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: color.withOpacity(0.1),
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}