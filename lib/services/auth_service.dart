import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Stream pour écouter si l'utilisateur est connecté ou non
  Stream<User?> get user => _auth.authStateChanges();

  // Connexion
  Future<UserCredential> signIn(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
          email: email, password: password);
    } catch (e) {
      rethrow; // On renvoie l'erreur pour l'afficher dans l'UI
    }
  }

  // Déconnexion
  Future<void> signOut() async {
    await _auth.signOut();
  }
  
  // Inscription (On fera le lien avec Firestore à l'étape suivante)
  Future<UserCredential> signUp(String email, String password) async {
      return await _auth.createUserWithEmailAndPassword(email: email, password: password);
  }
}