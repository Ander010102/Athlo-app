import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  static String? userEmail;
  static String? userPassword;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _apelidoController = TextEditingController();
  final TextEditingController _emailController   = TextEditingController();
  final TextEditingController _senhaController   = TextEditingController();

  bool _loading = false;

  @override
  void dispose() {
    _apelidoController.dispose();
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  Future<void> _registrar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final email = _emailController.text.trim();
      final senha = _senhaController.text.trim();
      final apelido = _apelidoController.text.trim();

      final cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: senha);

      await cred.user?.updateDisplayName(apelido);

      RegisterPage.userEmail = email;
      RegisterPage.userPassword = senha;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cadastro realizado! Faça login.')),
      );
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      String msg = 'Erro inesperado. Tente novamente.';
      switch (e.code) {
        case 'email-already-in-use':
          msg = 'Este e-mail já está cadastrado.';
          break;
        case 'invalid-email':
          msg = 'E-mail inválido.';
          break;
        case 'weak-password':
          msg = 'A senha é muito fraca (mín. 6 caracteres).';
          break;
        case 'operation-not-allowed':
          msg = 'Método de login desativado no projeto.';
          break;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// ---- NOVO: login com Google ----
  Future<void> _loginComGoogle() async {
    setState(() => _loading = true);
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _loading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      final user = userCredential.user;

      if (user != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Bem-vindo, ${user.displayName ?? 'usuário'}!")),
        );
        // Aqui você pode redirecionar para sua HomePage:
        // Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomePage()));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro no login Google: $e")),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF5D6652),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          const SizedBox(height: 30),
                          const Text(
                            "Cadastre-se",
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 30),

                          // --- campos ---
                          TextFormField(
                            controller: _apelidoController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              hintText: "Digite seu apelido",
                              hintStyle: TextStyle(color: Colors.white70),
                              prefixIcon: Icon(Icons.person, color: Colors.white),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.white70),
                              ),
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.white),
                              ),
                            ),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'Informe um apelido' : null,
                          ),
                          const SizedBox(height: 20),

                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              hintText: "Digite seu email",
                              hintStyle: TextStyle(color: Colors.white70),
                              prefixIcon: Icon(Icons.email, color: Colors.white),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.white70),
                              ),
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.white),
                              ),
                            ),
                            validator: (v) {
                              final email = v?.trim() ?? '';
                              if (email.isEmpty) return 'Informe o e-mail';
                              if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
                                return 'E-mail inválido';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          TextFormField(
                            controller: _senhaController,
                            obscureText: true,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              hintText: "Digite sua senha",
                              hintStyle: TextStyle(color: Colors.white70),
                              prefixIcon: Icon(Icons.lock, color: Colors.white),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.white70),
                              ),
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.white),
                              ),
                            ),
                            validator: (v) {
                              final s = v?.trim() ?? '';
                              if (s.isEmpty) return 'Informe a senha';
                              if (s.length < 6) return 'Mínimo de 6 caracteres';
                              return null;
                            },
                          ),
                          const SizedBox(height: 30),

                          // --- botão registrar ---
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE37B40),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: _loading ? null : _registrar,
                              child: _loading
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text(
                                      "Acessar",
                                      style: TextStyle(fontSize: 16, color: Colors.white),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          const Text("ou", style: TextStyle(color: Colors.white70)),
                          const SizedBox(height: 20),

                          // --- botão Google atualizado ---
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFDAD3B0),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              icon: const Icon(Icons.g_mobiledata,
                                  color: Colors.black, size: 28),
                              label: const Text(
                                "Entrar com Google",
                                style: TextStyle(color: Colors.black),
                              ),
                              onPressed: _loading ? null : _loginComGoogle,
                            ),
                          ),
                          const SizedBox(height: 20),

                          TextButton(
                            onPressed: _loading ? null : () => Navigator.pop(context),
                            child: const Text(
                              "Já possui uma conta? Entrar",
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // fundo azul + imagem
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Color(0xFF2F4858),
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
          ],
        ),
      ),
    );
  }
}
