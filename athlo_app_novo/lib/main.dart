import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

import 'pages/main_navigation.dart';
import 'pages/welcome_page.dart';
import 'pages/home_feed_page.dart';
import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'pages/profile_page.dart';
import 'pages/search_page.dart';
import 'pages/create_community_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Athlo App',
      theme: ThemeData(
        primarySwatch: Colors.orange,
        scaffoldBackgroundColor: const Color(0xFF4B4B3D),
      ),
      // Em vez de usar initialRoute fixo, usamos o estado do FirebaseAuth
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // Enquanto carrega o estado da auth → mostra loading
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData) {
              // Usuário logado → vai para navegação principal (com a nova barra)
              return const MainNavigation();
          }
          // Usuário não logado → vai para Welcome
          return const WelcomePage();
        },
      ),
      routes: {
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/home': (context) => const HomeFeedPage(),
        '/profile': (context) => const ProfilePage(),
        '/search': (context) => const SearchPage(),
        '/create-community': (context) => const CreateCommunityPage(),
      },
    );
  }
}
