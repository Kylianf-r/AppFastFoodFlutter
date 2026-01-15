import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DonationScreen extends StatefulWidget {
  const DonationScreen({super.key});

  @override
  State<DonationScreen> createState() => _DonationScreenState();
}

class _DonationScreenState extends State<DonationScreen> {
  final _recipientController = TextEditingController(); // Pour l'email ou le pseudo
  final _amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  bool _isLoading = false;

  // Fonction principale de don
  Future<void> _processDonation(int currentPoints) async {
    if (!_formKey.currentState!.validate()) return;

    // 1. Validation locale basique
    final int amount = int.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) {
      _showError("Le montant doit être positif.");
      return;
    }
    if (amount > currentPoints) {
      _showError("Vous n'avez pas assez de points.");
      return;
    }

    final String targetIdentifier = _recipientController.text.trim();
    final currentUser = FirebaseAuth.instance.currentUser!;

    // Empêcher de se donner à soi-même (vérification simple sur l'email)
    if (targetIdentifier == currentUser.email) {
      _showError("Vous ne pouvez pas vous donner des points à vous-même !");
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 2. Recherche du destinataire (Par Email OU par Pseudo)
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('user')
          .where('email', isEqualTo: targetIdentifier)
          .limit(1)
          .get();

      // Si pas trouvé par email, on cherche par pseudo
      if (querySnapshot.docs.isEmpty) {
        querySnapshot = await FirebaseFirestore.instance
            .collection('user')
            .where('pseudo', isEqualTo: targetIdentifier)
            .limit(1)
            .get();
      }

      // Si toujours pas trouvé
      if (querySnapshot.docs.isEmpty) {
        _showError("Utilisateur introuvable (vérifiez l'email ou le pseudo).");
        setState(() => _isLoading = false);
        return;
      }

      final receiverDoc = querySnapshot.docs.first;
      final String receiverId = receiverDoc.id;
      final String receiverName = receiverDoc['pseudo'] ?? 'L\'utilisateur';

      // Vérification finale : on ne se donne pas à soi-même (via ID cette fois)
      if (receiverId == currentUser.uid) {
        _showError("Vous ne pouvez pas vous donner des points à vous-même !");
        setState(() => _isLoading = false);
        return;
      }

      // 3. LA TRANSACTION MODIFIÉE
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // A. Lecture Envoyer
        DocumentSnapshot senderSnapshot = await transaction.get(
          FirebaseFirestore.instance.collection('user').doc(currentUser.uid)
        );
        if (!senderSnapshot.exists) throw Exception("Expéditeur introuvable");

        // B. Lecture Receveur (pour vérifier son plafond)
        DocumentSnapshot receiverSnapshot = await transaction.get(receiverDoc.reference);
        if (!receiverSnapshot.exists) throw Exception("Receveur introuvable");

        int senderPoints = senderSnapshot['point'] ?? 0;
        int receiverPoints = receiverSnapshot['point'] ?? 0;

        // VÉRIFICATIONS
        if (senderPoints < amount) {
          throw Exception("Solde insuffisant.");
        }
        
        // LE CHECK DU PLAFOND
        if (receiverPoints + amount > 300) {
          throw Exception("Impossible : Le destinataire dépasserait la limite de 300 points !");
        }

        // C. Opérations
        transaction.update(senderSnapshot.reference, {
          'point': FieldValue.increment(-amount)
        });

        transaction.update(receiverDoc.reference, {
          'point': FieldValue.increment(amount)
        });

        // Log
        DocumentReference logRef = FirebaseFirestore.instance.collection('log').doc();
        transaction.set(logRef, {
          'action': 'DON_POINTS',
          'userId': currentUser.uid,
          'targetId': receiverId,
          'montant': amount,
          'date': FieldValue.serverTimestamp(),
          'detail': 'Don de points',
          'levelError': 'INFO'
        });
      });

      // 4. Succès
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Succès ! $amount points envoyés à $receiverName 🎁")),
        );
        Navigator.pop(context); // On revient à l'accueil
      }

    } catch (e) {
      _showError("Erreur lors du don : ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text("Faire un don")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: StreamBuilder<DocumentSnapshot>(
          // On écoute le solde en temps réel pour l'afficher
          stream: FirebaseFirestore.instance.collection('user').doc(user?.uid).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const LinearProgressIndicator();

            final int myPoints = snapshot.data!['point'] ?? 0;

            return Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- AFFICHAGE SOLDE ---
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.teal.shade200),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.volunteer_activism, size: 50, color: Colors.teal),
                        const SizedBox(height: 10),
                        const Text("Votre solde actuel", style: TextStyle(color: Colors.teal)),
                        Text(
                          "$myPoints pts",
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.teal),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  // --- FORMULAIRE ---
                  const Text("À qui voulez-vous donner ?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _recipientController,
                    decoration: const InputDecoration(
                      labelText: "Pseudo ou Email de votre ami(e)",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                    validator: (v) => v!.isEmpty ? "Requis" : null,
                  ),
                  const SizedBox(height: 20),

                  const Text("Combien ?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Montant à transférer",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.numbers),
                      suffixText: "pts"
                    ),
                    validator: (v) {
                      if (v!.isEmpty) return "Requis";
                      if (int.tryParse(v) == null) return "Chiffre entier requis";
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 40),

                  _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton.icon(
                        onPressed: () => _processDonation(myPoints),
                        icon: const Icon(Icons.send),
                        label: const Text("ENVOYER LES POINTS", style: TextStyle(fontSize: 18)),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                        ),
                      ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}