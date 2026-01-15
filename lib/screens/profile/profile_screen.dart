import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  // Petite fonction pour déterminer le statut selon les points cumulés
  Map<String, dynamic> _getLoyaltyStatus(int lifetimePoints) {
    if (lifetimePoints >= 500) {
      return {'label': 'OR', 'color': const Color(0xFFFFD700), 'icon': Icons.emoji_events};
    } else if (lifetimePoints >= 100) {
      return {'label': 'ARGENT', 'color': const Color(0xFFC0C0C0), 'icon': Icons.star};
    } else {
      return {'label': 'BRONZE', 'color': const Color(0xFFCD7F32), 'icon': Icons.shield};
    }
  }

  @override
  Widget build(BuildContext context) {
    // On récupère l'ID de l'utilisateur connecté
    final user = FirebaseAuth.instance.currentUser;

    // Sécurité si jamais l'utilisateur est null (ne devrait pas arriver ici)
    if (user == null) return const Center(child: Text("Non connecté"));

    return Scaffold(
      appBar: AppBar(
        title: const Text("Mon Profil"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              // Déconnexion
              await AuthService().signOut();
              // Le Stream dans main.dart détectera la déconnexion et affichera le LoginScreen
            },
          )
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        // On écoute le document de l'utilisateur en temps réel
        stream: FirebaseFirestore.instance.collection('user').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          // 1. Cas de chargement
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // 2. Cas d'erreur
          if (snapshot.hasError) {
            return const Center(child: Text("Erreur de chargement"));
          }

          // 3. Vérification que le document existe
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Profil introuvable"));
          }

          // 4. Récupération des données brutes
          final data = snapshot.data!.data() as Map<String, dynamic>;
          
          final String nom = data['nom'] ?? 'Inconnu';
          final String prenom = data['prenom'] ?? '';
          final String email = data['email'] ?? user.email;
          final bool isPremium = data['isPremium'] ?? false;
          final int lifetimePoints = data['niveauFidelite'] ?? 0; // Points à vie
          final int currentPoints = data['point'] ?? 0; // Solde actuel

          // Calcul du statut
          final statusInfo = _getLoyaltyStatus(lifetimePoints);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // --- EN-TÊTE ---
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.orange.shade100,
                  child: Text(
                    prenom.isNotEmpty ? prenom[0].toUpperCase() : "?",
                    style: const TextStyle(fontSize: 40, color: Colors.orange),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "$prenom $nom",
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                Text(
                  email,
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 30),

                // --- CARTE FIDÉLITÉ ---
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Text("NIVEAU DE FIDÉLITÉ", style: TextStyle(color: Colors.grey, fontSize: 12)),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(statusInfo['icon'], color: statusInfo['color'], size: 30),
                            const SizedBox(width: 10),
                            Text(
                              statusInfo['label'],
                              style: TextStyle(
                                fontSize: 28, 
                                fontWeight: FontWeight.bold, 
                                color: statusInfo['color']
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 30),
                        Text(
                          "$lifetimePoints pts cumulés à vie",
                          style: const TextStyle(fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),

                // --- TYPE DE COMPTE & SOLDE ---
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoCard(
                        title: "TYPE DE COMPTE",
                        value: isPremium ? "PREMIUM" : "CLASSIQUE",
                        color: isPremium ? Colors.purple : Colors.blueGrey,
                        icon: isPremium ? Icons.verified : Icons.person,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildInfoCard(
                        title: "SOLDE POINTS",
                        value: "$currentPoints",
                        color: Colors.orange,
                        icon: Icons.savings,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 40),
                
                // --- BOUTON DÉCONNEXION (Optionnel en bas aussi) ---
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.logout, color: Colors.red),
                    label: const Text("Se déconnecter", style: TextStyle(color: Colors.red)),
                    onPressed: () => AuthService().signOut(),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 16)
                    ),
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }

  // Petit widget helper pour éviter de répéter du code
  Widget _buildInfoCard({required String title, required String value, required Color color, required IconData icon}) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}