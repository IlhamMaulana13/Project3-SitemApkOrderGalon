import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:galonfibonacci/api_config.dart';
import 'package:galonfibonacci/screens/admin_dashboard_screen.dart';
import 'package:galonfibonacci/screens/kurir_screen.dart';
import 'package:galonfibonacci/screens/main_screen.dart';
import 'package:http/http.dart' as http;

class LoginScreen extends StatefulWidget {
  final bool isRegister;

  const LoginScreen({super.key, this.isRegister = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final addressController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool isPasswordHidden = true;
  bool isConfirmPasswordHidden = true;

  late bool isLogin;

  @override
  void initState() {
    super.initState();
    isLogin = !widget.isRegister;
  }

  // =========================
  // GET ROLE
  // =========================
  Future<String> getRole(String uid) async {
    final response = await http.get(
      Uri.parse("${ApiConfig.baseUrl}/users/$uid"),
    );

    if (response.statusCode != 200) {
      return "customer";
    }

    final data = jsonDecode(response.body);

    return data["role"] ?? "customer";
  }

  // =========================
  // SUBMIT
  // =========================
  Future<void> submit() async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();

      // =========================
      // LOGIN
      // =========================
      if (isLogin) {
        UserCredential userCredential = await FirebaseAuth.instance
            .signInWithEmailAndPassword(
              email: emailController.text.trim(),
              password: passwordController.text.trim(),
            );

        final user = userCredential.user;

        // UPDATE TOKEN
        await http.post(
          Uri.parse("${ApiConfig.baseUrl}/users"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "firebase_uid": user!.uid,
            "email": user.email,
            "fcm_token": token,
          }),
        );

        // AMBIL ROLE
        String role = await getRole(user.uid);

        Widget nextScreen;

        if (role == "admin") {
          nextScreen = const AdminDashboardScreen();
        } else if (role == "kurir") {
          nextScreen = const KurirScreen();
        } else {
          nextScreen = const MainScreen();
        }

        if (!mounted) return;

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => nextScreen),
          (route) => false,
        );
      }
      // =========================
      // REGISTER
      // =========================
      else {
        if (passwordController.text != confirmPasswordController.text) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Konfirmasi password tidak cocok")),
          );
          return;
        }

        if (nameController.text.isEmpty ||
            phoneController.text.isEmpty ||
            addressController.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Semua data harus diisi")),
          );
          return;
        }

        UserCredential userCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
              email: emailController.text.trim(),
              password: passwordController.text.trim(),
            );

        final user = userCredential.user;

        // SIMPAN PROFILE
        await http.post(
          Uri.parse("${ApiConfig.baseUrl}/profile"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "firebase_uid": user!.uid,
            "email": user.email,
            "name": nameController.text,
            "phone": phoneController.text,
            "address": addressController.text,
          }),
        );

        await http.post(
          Uri.parse("${ApiConfig.baseUrl}/users"),

          headers: {"Content-Type": "application/json"},

          body: jsonEncode({
            "firebase_uid": user.uid,
            "email": user.email,
            "name": nameController.text,
            "phone": phoneController.text,
            "address": addressController.text,
            "fcm_token": token,
          }),
        );

        await FirebaseAuth.instance.signOut();

        if (!mounted) return;

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),

              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),

                  CircleAvatar(
                    radius: 35,
                    backgroundColor: Colors.green[100],

                    child: Icon(
                      Icons.check,
                      color: Colors.green[700],
                      size: 45,
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    "REGISTER BERHASIL",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),

                  const SizedBox(height: 10),

                  const Text(
                    "Silakan login menggunakan akun anda",
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 25),

                  SizedBox(
                    width: double.infinity,

                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);

                        setState(() {
                          isLogin = true;

                          // CLEAR FORM
                          emailController.clear();
                          passwordController.clear();
                          confirmPasswordController.clear();
                          nameController.clear();
                          phoneController.clear();
                          addressController.clear();
                        });
                      },

                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),

                      child: const Text("OK"),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message ?? "Terjadi kesalahan")));
    }
  }

  // =========================
  // TEXTFIELD
  // =========================
  Widget buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    Widget? suffixIcon,
    int maxLines = 1,
    TextInputType keyboard = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      maxLines: maxLines,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(25),

          child: Column(
            children: [
              const SizedBox(height: 20),

              Icon(Icons.water_drop, size: 90, color: Colors.blue[700]),

              const SizedBox(height: 15),

              Text(
                "Galon Rizki Faras",
                style: TextStyle(
                  fontSize: 28,
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

              // REGISTER FIELD
              if (!isLogin) ...[
                buildTextField(
                  controller: nameController,
                  label: "Nama Lengkap",
                  icon: Icons.person,
                ),

                const SizedBox(height: 18),

                buildTextField(
                  controller: phoneController,
                  label: "No HP",
                  icon: Icons.phone,
                  keyboard: TextInputType.phone,
                ),

                const SizedBox(height: 18),

                buildTextField(
                  controller: addressController,
                  label: "Alamat",
                  icon: Icons.location_on,
                  maxLines: 3,
                ),

                const SizedBox(height: 18),
              ],

              // EMAIL
              buildTextField(
                controller: emailController,
                label: "Email",
                icon: Icons.email,
                keyboard: TextInputType.emailAddress,
              ),

              const SizedBox(height: 18),

              // PASSWORD
              buildTextField(
                controller: passwordController,
                label: "Password",
                icon: Icons.lock,
                obscure: isPasswordHidden,
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      isPasswordHidden = !isPasswordHidden;
                    });
                  },
                  icon: Icon(
                    isPasswordHidden ? Icons.visibility_off : Icons.visibility,
                  ),
                ),
              ),

              // CONFIRM PASSWORD
              if (!isLogin) ...[
                const SizedBox(height: 18),

                buildTextField(
                  controller: confirmPasswordController,
                  label: "Konfirmasi Password",
                  icon: Icons.lock_outline,
                  obscure: isConfirmPasswordHidden,
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        isConfirmPasswordHidden = !isConfirmPasswordHidden;
                      });
                    },
                    icon: Icon(
                      isConfirmPasswordHidden
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 30),

              // BUTTON
              SizedBox(
                width: double.infinity,
                height: 55,

                child: ElevatedButton(
                  onPressed: submit,

                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
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

              // TOGGLE
              Row(
                mainAxisAlignment: MainAxisAlignment.center,

                children: [
                  Text(isLogin ? "Belum punya akun?" : "Sudah punya akun?"),

                  TextButton(
                    onPressed: () {
                      setState(() {
                        isLogin = !isLogin;
                      });
                    },

                    child: Text(
                      isLogin ? "Register" : "Login",
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

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

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
