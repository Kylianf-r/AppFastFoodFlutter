import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Contrôleurs pour récupérer le texte
  final _nomController = TextEditingController();
  final _prenomController = TextEditingController();
  final _pseudoController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _formKey = GlobalKey<FormState>(); // Pour la validation du formulaire
  bool _isLoading = false;

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // 1. Créer l'utilisateur dans l'Authentification (Email/Mdp)
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // 2. Créer le document utilisateur dans Firestore
      // On utilise l'UID fourni par l'auth comme ID du document
      final String uid = userCredential.user!.uid;

      await FirebaseFirestore.instance.collection('user').doc(uid).set({
        'nom': _nomController.text.trim(),
        'prenom': _prenomController.text.trim(),
        'pseudo': _pseudoController.text.trim(),
        'email': _emailController.text.trim(),
        'point': 0,              // Solde de départ
        'niveauFidelite': 0,     // Niveau de départ
        'isPremium': false,      // Compte classique par défaut
        'dateCreation': FieldValue.serverTimestamp(),
      });

      // 3. Si tout est bon, le Stream dans main.dart redirigera automatiquement
      // Mais on peut fermer cette page pour revenir à la racine de la navigation
      if (mounted) {
        Navigator.of(context).pop(); 
      }

    } on FirebaseAuthException catch (e) {
      String message = "Une erreur est survenue";
      if (e.code == 'weak-password') message = "Le mot de passe est trop faible.";
      if (e.code == 'email-already-in-use') message = "Cet email est déjà utilisé.";
      
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Créer un compte")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const Icon(Icons.person_add, size: 60, color: Colors.orange),
              const SizedBox(height: 20),
              
              // Nom et Prénom sur la même ligne pour gagner de la place
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _nomController,
                      decoration: const InputDecoration(labelText: "Nom", border: OutlineInputBorder()),
                      validator: (v) => v!.isEmpty ? "Requis" : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _prenomController,
                      decoration: const InputDecoration(labelText: "Prénom", border: OutlineInputBorder()),
                      validator: (v) => v!.isEmpty ? "Requis" : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _pseudoController,
                decoration: const InputDecoration(labelText: "Pseudo", border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? "Requis" : null,
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: "Email", border: OutlineInputBorder()),
                validator: (v) => v!.contains('@') ? null : "Email invalide",
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: "Mot de passe", border: OutlineInputBorder()),
                validator: (v) => v!.length < 6 ? "Trop court" : null,
              ),
              const SizedBox(height: 24),
              
              _isLoading
                  ? const CircularProgressIndicator()
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _register,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white
                        ),
                        child: const Text("S'INSCRIRE"),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}