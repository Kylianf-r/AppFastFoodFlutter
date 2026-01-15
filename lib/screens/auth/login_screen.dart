import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/log_service.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;

  void _login() async {
    setState(() => _isLoading = true);
    try {
      await _authService.signIn(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      
      // ✅ LOG DE SUCCÈS
      // On attend un tout petit peu pour être sûr que l'utilisateur est bien set par Firebase
      Future.delayed(const Duration(milliseconds: 500), () {
         LogService().info('CONNEXION', 'Connexion réussie via email');
      });

    } catch (e) {
      // ❌ LOG D'ERREUR
      LogService().error('ERREUR_CONNEXION', e.toString());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur : ${e.toString()}")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- NOUVELLE FONCTION : GESTION DU MOT DE PASSE OUBLIÉ ---
  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController();
    // On pré-remplit avec ce que l'utilisateur a déjà tapé dans le champ principal
    resetEmailController.text = _emailController.text;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Réinitialiser le mot de passe"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Entrez votre email pour recevoir un lien de réinitialisation."),
            const SizedBox(height: 10),
            TextField(
              controller: resetEmailController,
              decoration: const InputDecoration(labelText: "Email", border: OutlineInputBorder()),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (resetEmailController.text.isEmpty) return;
              
              Navigator.pop(context); // Fermer la modale
              
              try {
                await _authService.sendPasswordResetEmail(resetEmailController.text.trim());
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Email de réinitialisation envoyé ! Vérifiez vos spams.")),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Erreur : ${e.toString()}")),
                  );
                }
              }
            },
            child: const Text("Envoyer"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lunch_dining, size: 80, color: Colors.orange),
              const SizedBox(height: 20),
              const Text("BurgerQueen", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 40),
              
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: "Email", border: OutlineInputBorder()),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: "Mot de passe", border: OutlineInputBorder()),
                obscureText: true,
              ),

              // --- AJOUT DU BOUTON MOT DE PASSE OUBLIÉ ---
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _showForgotPasswordDialog,
                  child: const Text("Mot de passe oublié ?", style: TextStyle(color: Colors.grey)),
                ),
              ),

              const SizedBox(height: 20),
              
              _isLoading
                  ? const CircularProgressIndicator()
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _login,
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                        child: const Text("SE CONNECTER"),
                      ),
                    ),
                    
              const SizedBox(height: 10),
              
              TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const RegisterScreen()),
                    );
                  },
                  child: const Text("Créer un compte")
              )
            ],
          ),
        ),
      ),
    );
  }
}