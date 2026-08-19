import 'package:flutter/material.dart';

void main() {
  runApp(AthloApp());
}

class AthloApp extends StatelessWidget {
  const AthloApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Athlo',
      debugShowCheckedModeBanner: false,
      home: WelcomeScreen(),
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF585239), // Cor do fundo (marrom esverdeado)
      body: Column(
        children: [
          // Parte de cima com imagem e curva
          ClipPath(
            clipper: TopClipper(),
            child: Container(
              width: double.infinity,
              height: 300,
              color: Color(0xFFFAD672), // Amarelo
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Image.asset(
                  'assets/images/header_sports.png', // Substitua com o nome da imagem no seu projeto
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          SizedBox(height: 24),
          Text(
            'Bem Vindo!',
            style: TextStyle(
              fontSize: 24,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 32),
          // Botão Login
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFDF6A33),
                minimumSize: Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('Login'),
            ),
          ),
          SizedBox(height: 16),
          // Botão Registre-se
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFEFEBDD), // tom off-white
                foregroundColor: Colors.black,
                minimumSize: Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('Registre-se'),
            ),
          ),
          Spacer(),
          // Ícone de colmeia (substitua por SVG ou imagem se quiser)
          Padding(
            padding: const EdgeInsets.only(bottom: 24.0),
            child: Icon(Icons.apps, color: Color(0xFFFAD672), size: 48),
          ),
        ],
      ),
    );
  }
}

// Clipador para fazer a curva da parte superior
class TopClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 100);
    path.quadraticBezierTo(
      size.width / 2, size.height,
      size.width, size.height - 100,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
