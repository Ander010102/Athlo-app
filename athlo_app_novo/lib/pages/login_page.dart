import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'home_feed_page.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  void _login() {
    final email = _emailController.text.trim();
    final senha = _passwordController.text.trim();

    final isAdmin = email == "ADM123" && senha == "ADM123";
    final isUser =
        email == RegisterPage.userEmail && senha == RegisterPage.userPassword;

    if (isAdmin || isUser) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const HomeFeedPage()));
    } else {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Erro"),
          content: const Text("Usuário não encontrado"),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK"))
          ],
        ),
      );
    }
  }

  Future<void> _loginWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      if (googleUser == null) return; // Usuário cancelou o login

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeFeedPage()),
      );
    } catch (e) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Erro"),
          content: Text("Falha no login com Google: $e"),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK"))
          ],
        ),
      );
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Erro"),
          content: const Text("Digite seu email para redefinir a senha."),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK"))
          ],
        ),
      );
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Sucesso"),
          content: Text("Um e-mail de redefinição foi enviado para $email."),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK"))
          ],
        ),
      );
    } catch (e) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Erro"),
          content: Text("Falha ao enviar e-mail: $e"),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK"))
          ],
        ),
      );
    }
  }

  void _goRegister() {
    Navigator.pushNamed(context, '/register');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF4D6B6D),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    const Text(
                      "Entrar",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Campo Email
                    TextField(
                      controller: _emailController,
                      style: const TextStyle(color: Colors.black),
                      decoration: InputDecoration(
                        hintText: "Digite seu email",
                        prefixIcon: const Icon(Icons.email_outlined),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Campo Senha
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      style: const TextStyle(color: Colors.black),
                      decoration: InputDecoration(
                        hintText: "Digite sua senha",
                        prefixIcon: const Icon(Icons.lock_outline),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _resetPassword, // ✅ corrigido
                        child: const Text(
                          "Esqueceu a senha?",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Botão Acessar
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE67845),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: _login,
                        child: const Text(
                          "Acessar",
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    const Center(
                      child: Text(
                        "ou",
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Botão Google
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: const Icon(Icons.g_mobiledata,
                            size: 28, color: Colors.black),
                        onPressed: _loginWithGoogle,
                        label: const Text(
                          "Entrar com Google",
                          style: TextStyle(color: Colors.black, fontSize: 16),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                    Center(
                      child: TextButton(
                        onPressed: _goRegister,
                        child: const Text(
                          "Ainda não possui uma conta? Cadastre-se",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // --- PARTE DE BAIXO
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFF2F3E3E),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(80),
                    topRight: Radius.circular(80),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(80),
                    topRight: Radius.circular(80),
                  ),
                  child: Image.asset(
                    "assets/images/loggin_itch.png",
                    fit: BoxFit.cover,
                    width: double.infinity,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
