import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:galonfibonacci/screens/main_screen.dart';

import 'main_screen.dart';

class LoginScreen extends StatefulWidget {
  final bool isRegister;

  const LoginScreen({super.key, this.isRegister = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  late bool isLogin;

  @override
  void initState() {
    super.initState();
    isLogin = !widget.isRegister;
  }

  Future<void> submit() async {
    try {
      // LOGIN
      if (isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );
      }
      // REGISTER
      else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );
      }

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message ?? "Terjadi kesalahan")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],

      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(25),

            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.9,

              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ICON
                  Icon(Icons.water_drop, size: 90, color: Colors.blue[700]),

                  const SizedBox(height: 15),

                  // TITLE
                  Text(
                    "Galon Rajeg Bahagia",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    "Pemesanan air galon digital",
                    style: TextStyle(color: Colors.grey[700]),
                  ),

                  const SizedBox(height: 40),

                  // EMAIL
                  TextField(
                    controller: emailController,
                    decoration: InputDecoration(
                      labelText: "Email",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // PASSWORD
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: "Password",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),

                  const SizedBox(height: 25),

                  // LOGIN / REGISTER BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 55,

                    child: ElevatedButton(
                      onPressed: submit,

                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),

                      child: Text(
                        isLogin ? "Login" : "Register",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 15),

                  // TOGGLE LOGIN REGISTER
                  TextButton(
                    onPressed: () {
                      setState(() {
                        isLogin = !isLogin;
                      });
                    },

                    child: Text(
                      isLogin
                          ? "Belum punya akun? Register"
                          : "Sudah punya akun? Login",
                    ),
                  ),

                  const SizedBox(height: 10),

                  // GUEST MODE
                  TextButton(
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();

                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const MainScreen()),
                      );
                    },

                    child: const Text("Masuk Sebagai Tamu"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
