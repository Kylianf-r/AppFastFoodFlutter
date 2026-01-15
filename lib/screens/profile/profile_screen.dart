import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  // Petite fonction pour déterminer le statut
  // On ajoute le paramètre 'isAdmin'
  Map<String, dynamic> _getLoyaltyStatus(int lifetimePoints, bool isAdmin) {
    // Si c'est un admin, on renvoie direct le statut spécial
    if (isAdmin) {
      return {'label': 'ADMIN', 'color': Colors.red, 'icon': Icons.security};
    }
    
    // Sinon, logique classique des points
    if (lifetimePoints >= 500) {
      return {'label': 'OR', 'color': const Color(0xFFFFD700), 'icon': Icons.emoji_events};
    } else if (lifetimePoints >= 100) {
      return {'label': 'ARGENT', 'color': const Color(0xFFC0C0C0), 'icon': Icons.star};
    } else {
      return {'label': 'BRONZE', 'color': const Color(0xFFCD7F32), 'icon': Icons.shield};
    }
  }

  // --- NOUVELLE FONCTION : SUPPRESSION DE COMPTE ---
  Future<void> _deleteAccount(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // 1. Demande de confirmation (Dialogue d'alerte)
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Supprimer le compte ?"),
        content: const Text(
          "Attention, cette action est irréversible.\n\nToutes vos données (points, historique, profil) seront définitivement effacées.",
          style: TextStyle(color: Colors.red),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("SUPPRIMER"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // 2. Supprimer les données Firestore AVANT de supprimer le compte Auth
      // (Car une fois le compte Auth supprimé, on perd les droits d'accès pour supprimer le doc)
      await FirebaseFirestore.instance.collection('user').doc(user.uid).delete();

      // 3. Supprimer le compte Firebase Auth
      await user.delete();

      // Note : Le Stream dans main.dart va détecter la disparition du user et renvoyer au Login
      
    } on FirebaseAuthException catch (e) {
      // Cas particulier : Si l'utilisateur est connecté depuis trop longtemps, 
      // Firebase demande de se reconnecter avant de pouvoir supprimer le compte (sécurité).
      if (e.code == 'requires-recent-login') {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Par sécurité, veuillez vous déconnecter et vous reconnecter avant de supprimer votre compte.")),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur : ${e.message}")));
        }
      }
    } catch (e) {
       if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur : $e")));
       }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return const Center(child: Text("Non connecté"));

    return Scaffold(
      appBar: AppBar(
        title: const Text("Mon Profil"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService().signOut();
            },
          )
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('user').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text("Erreur de chargement"));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Profil introuvable"));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          
          final String nom = data['nom'] ?? 'Inconnu';
          final String prenom = data['prenom'] ?? '';
          final String email = data['email'] ?? user.email;
          final bool isAdmin = data['isAdmin'] ?? false;
          final bool isPremium = data['isPremium'] ?? false;
          final int lifetimePoints = data['niveauFidelite'] ?? 0;
          final int currentPoints = data['point'] ?? 0;
          // On passe isAdmin à la fonction
          final statusInfo = _getLoyaltyStatus(lifetimePoints, isAdmin);

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
                
                // --- BOUTON DÉCONNEXION ---
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
                ),

                // --- BOUTON SUPPRIMER LE COMPTE (AJOUTÉ ICI) ---
                const SizedBox(height: 20),
                TextButton.icon(
                  onPressed: () => _deleteAccount(context),
                  icon: const Icon(Icons.delete_forever, size: 20, color: Color.fromARGB(255, 255, 0, 0)),
                  label: const Text("Supprimer mon compte définitivement", style: TextStyle(color: Color.fromARGB(255, 255, 0, 0), fontSize: 12)),
                ),
                const SizedBox(height: 20), // Marge de fin
              ],
            ),
          );
        },
      ),
    );
  }

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