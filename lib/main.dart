import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'services/cart_service.dart';

// Import de tes fichiers
import 'services/auth_service.dart';
import 'screens/main_scaffold.dart';
import 'screens/auth/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialisation de Firebase SANS les options.
  // Flutter va automatiquement détecter ton fichier android/app/google-services.json
  await Firebase.initializeApp();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // On injecte le service d'authentification et cart service pour pouvoir l'utiliser partout
        Provider<AuthService>(create: (_) => AuthService()),
        ChangeNotifierProvider<CartService>(create: (_) => CartService()),
      ],
      child: MaterialApp(
        title: 'Fast Food App',
        debugShowCheckedModeBanner: false, // Retire le bandeau "DEBUG" en haut à droite
        theme: ThemeData(
          // Thème Orange typique Fast Food
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
          useMaterial3: true,
          // Exemple de style global (optionnel)
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
        ),
        // Le StreamBuilder écoute l'état de la connexion (Connecté / Pas connecté)
        home: StreamBuilder(
          stream: AuthService().user,
          builder: (context, snapshot) {
            // 1. État de chargement (vérification du token au démarrage)
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            // 2. Si l'utilisateur est connecté (hasData = true)
            if (snapshot.hasData) {
              return const MainScaffold(); // On affiche l'appli principale
            }

            // 3. Sinon, on affiche l'écran de connexion
            return const LoginScreen();
          },
        ),
      ),
    );
  }
}