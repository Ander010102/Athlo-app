import 'package:flutter/material.dart';
import 'login_page.dart';
import 'register_page.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFF4B4B3D),
      body: SafeArea(
        child: Column(
          children: [
            // --- Topo oval + imagemm ---
            Stack(
              alignment: Alignment.topCenter,
              children: [
                // Oval amarelo responsiva
                Positioned(
                  top: -screenHeight *
                      0.35, // sobe para mostrar só a base arredondada
                  child: Container(
                    width: screenWidth * 1.5,
                    height: screenHeight * 0.7,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEBCC6E),
                      borderRadius: BorderRadius.circular(screenWidth),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 1,
                          spreadRadius: -50,
                          offset: Offset(0, 0),
                        ),
                      ],
                    ),
                  ),
                ),

                // Imagem de esportes responsiva
                Padding(
                  padding: const EdgeInsets.only(top: 25),
                  child: Image.asset(
                    'assets/images/image.png',
                    width: screenWidth * 1.2, // aumenta em 20% além da tela
                    height: screenHeight * 0.34, // ocupa ~32% da altura
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ),

            SizedBox(height: screenHeight * 0.05), // espaço até "Bem Vindo!"

            // --- Título ---
            const Text(
              'Bem Vindo!',
              style: TextStyle(
                fontSize: 26,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 23),

            // --- Botão Login ---
            SizedBox(
              width: screenWidth * 0.85,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE37B40),
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                  );
                },
                child: const Text(
                  'Login',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 34),

            // --- Botão Registre-se ---
            SizedBox(
              width: screenWidth * 0.85,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF0E6C8),
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const RegisterPage()),
                  );
                },
                child: const Text(
                  'Registre-se',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const Spacer(),

            // --- Rodapé ---
            Stack(
              alignment: Alignment.bottomCenter,
              children: [
                Positioned(
                  bottom: 0,
                  child: Image.asset(
                    'assets/images/DETALHE.png',
                    height: 12,
                    fit: BoxFit.contain,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 80),
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 80,
                    height: 92,
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
