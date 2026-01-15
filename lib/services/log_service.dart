import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // Pour debugPrint

class LogService {
  // Instance unique (Singleton) pour l'utiliser partout facilement
  static final LogService _instance = LogService._internal();
  factory LogService() => _instance;
  LogService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Fonction générique pour envoyer un log
  Future<void> log(String action, String level, String detail) async {
    try {
      final user = _auth.currentUser;
      
      await _firestore.collection('log').add({
        'action': action,       // Ex: 'CONNEXION', 'ERREUR_PANIER'
        'levelError': level,    // 'INFO', 'WARNING', 'ERROR'
        'detail': detail,       // Description complète
        'date': FieldValue.serverTimestamp(),
        'userId': user?.uid ?? 'Anonyme', // On note qui a fait l'action
      });
      
      // On l'affiche aussi dans la console du développeur (VS Code)
      debugPrint("📝 LOG [$level] $action : $detail");

    } catch (e) {
      // Si le log plante, on l'écrit juste dans la console pour ne pas faire crasher l'app
      debugPrint("❌ Impossible d'envoyer le log : $e");
    }
  }

  // Raccourcis pratiques
  Future<void> info(String action, String detail) => log(action, 'INFO', detail);
  Future<void> error(String action, String detail) => log(action, 'ERROR', detail);
  Future<void> warning(String action, String detail) => log(action, 'WARNING', detail);
}