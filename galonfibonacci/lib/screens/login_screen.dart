import 'dart:convert';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:galonfibonacci/api_config.dart';
import 'package:galonfibonacci/screens/admin_dashboard_screen.dart';
import 'package:galonfibonacci/screens/kasir_screen.dart';
import 'package:galonfibonacci/screens/kurir_screen.dart';
import 'package:galonfibonacci/screens/main_screen.dart';
import 'package:http/http.dart' as http;

class LoginScreen extends StatefulWidget {
  final bool isRegister;

  const LoginScreen({super.key, this.isRegister = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _waveController;
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final addressController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool isPasswordHidden = true;
  bool isConfirmPasswordHidden = true;

  static const Duration _switchDuration = Duration(milliseconds: 420);

  late bool isLogin;

  @override
  void initState() {
    super.initState();
    isLogin = !widget.isRegister;
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    emailController.dispose();
    passwordController.dispose();
    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
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
        } else if (role == "kasir") {
          nextScreen = const KasirScreen();
        } else {
          nextScreen = const MainScreen();
        }

        if (!mounted) return;

        Navigator.pushAndRemoveUntil(
          context,
          _createPageRoute(nextScreen),
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

  Route _createPageRoute(Widget screen) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => screen,
      transitionDuration: const Duration(milliseconds: 420),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.16),
            end: Offset.zero,
          ).animate(curved),
          child: FadeTransition(opacity: curved, child: child),
        );
      },
    );
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
    TextCapitalization capitalization = TextCapitalization.none,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      maxLines: maxLines,
      keyboardType: keyboard,
      textCapitalization: capitalization,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.blue[800]),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withOpacity(0.95),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 18,
          horizontal: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.blue.shade300, width: 2),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.blue.shade800,
                  Colors.blue.shade600,
                  Colors.lightBlue.shade200,
                ],
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SizedBox(
              height: 220,
              child: AnimatedBuilder(
                animation: _waveController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: WavePainter(_waveController.value * 2 * math.pi),
                    child: Container(),
                  );
                },
              ),
            ),
          ),
          Positioned(
            top: 24,
            left: 26,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.14),
              ),
            ),
          ),
          Positioned(
            top: 48,
            right: 18,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.16),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 6),
                  Image.asset(
                    'assets/images/logo_galon.png',
                    width: 200,
                    height: 200,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Galon Rizzki Faras',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pemesanan air galon digital dengan pengalaman segar dan modern.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.92),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(width: 12),
                            Text(
                              isLogin ? 'Masuk Akun' : 'Daftar Akun Baru',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),
                        AnimatedSwitcher(
                          duration: _switchDuration,
                          layoutBuilder: (currentChild, previousChildren) {
                            return Stack(
                              alignment: Alignment.topCenter,
                              children: [
                                ...previousChildren,
                                if (currentChild != null) currentChild,
                              ],
                            );
                          },
                          child: Text(
                            isLogin
                                ? 'Masukkan kredensial Anda untuk melanjutkan.'
                                : 'Lengkapi data untuk membuat akun pelanggan.',
                            key: ValueKey<bool>(isLogin),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blueGrey.shade600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        AnimatedSwitcher(
                          duration: _switchDuration,
                          layoutBuilder: (currentChild, previousChildren) {
                            return Stack(
                              alignment: Alignment.topCenter,
                              children: [
                                ...previousChildren,
                                if (currentChild != null) currentChild,
                              ],
                            );
                          },
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: child,
                            );
                          },
                          child: isLogin
                              ? Column(
                                  key: const ValueKey('login-form'),
                                  children: [
                                    buildTextField(
                                      controller: emailController,
                                      label: 'Email',
                                      icon: Icons.email,
                                      keyboard: TextInputType.emailAddress,
                                    ),
                                    const SizedBox(height: 16),
                                    buildTextField(
                                      controller: passwordController,
                                      label: 'Password',
                                      icon: Icons.lock,
                                      obscure: isPasswordHidden,
                                      suffixIcon: IconButton(
                                        onPressed: () {
                                          setState(() {
                                            isPasswordHidden =
                                                !isPasswordHidden;
                                          });
                                        },
                                        icon: Icon(
                                          isPasswordHidden
                                              ? Icons.visibility_off
                                              : Icons.visibility,
                                          color: Colors.blue[800],
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  key: const ValueKey('register-form'),
                                  children: [
                                    buildTextField(
                                      controller: nameController,
                                      label: 'Nama Lengkap',
                                      icon: Icons.person,
                                      capitalization: TextCapitalization.words,
                                    ),
                                    const SizedBox(height: 16),
                                    buildTextField(
                                      controller: phoneController,
                                      label: 'No HP',
                                      icon: Icons.phone,
                                      keyboard: TextInputType.phone,
                                    ),
                                    const SizedBox(height: 16),
                                    buildTextField(
                                      controller: addressController,
                                      label: 'Alamat',
                                      icon: Icons.location_on,
                                      maxLines: 3,
                                      capitalization:
                                          TextCapitalization.sentences,
                                    ),
                                    const SizedBox(height: 16),
                                    buildTextField(
                                      controller: emailController,
                                      label: 'Email',
                                      icon: Icons.email,
                                      keyboard: TextInputType.emailAddress,
                                    ),
                                    const SizedBox(height: 16),
                                    buildTextField(
                                      controller: passwordController,
                                      label: 'Password',
                                      icon: Icons.lock,
                                      obscure: isPasswordHidden,
                                      suffixIcon: IconButton(
                                        onPressed: () {
                                          setState(() {
                                            isPasswordHidden =
                                                !isPasswordHidden;
                                          });
                                        },
                                        icon: Icon(
                                          isPasswordHidden
                                              ? Icons.visibility_off
                                              : Icons.visibility,
                                          color: Colors.blue[800],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    buildTextField(
                                      controller: confirmPasswordController,
                                      label: 'Konfirmasi Password',
                                      icon: Icons.lock_outline,
                                      obscure: isConfirmPasswordHidden,
                                      suffixIcon: IconButton(
                                        onPressed: () {
                                          setState(() {
                                            isConfirmPasswordHidden =
                                                !isConfirmPasswordHidden;
                                          });
                                        },
                                        icon: Icon(
                                          isConfirmPasswordHidden
                                              ? Icons.visibility_off
                                              : Icons.visibility,
                                          color: Colors.blue[800],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade700,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 6,
                            ),
                            child: Text(
                              isLogin ? 'Login' : 'Register',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isLogin
                                  ? 'Belum punya akun?'
                                  : 'Sudah punya akun?',
                              style: TextStyle(color: Colors.blueGrey.shade700),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  isLogin = !isLogin;
                                });
                              },
                              child: Text(
                                isLogin ? 'Register' : 'Login',
                                style: TextStyle(
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        TextButton(
                          onPressed: () async {
                            await FirebaseAuth.instance.signOut();
                            Navigator.pushReplacement(
                              context,
                              _createPageRoute(const MainScreen()),
                            );
                          },
                          child: Text(
                            'Masuk Sebagai Tamu',
                            style: TextStyle(color: Colors.blue.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withOpacity(0.65),
                                Colors.white.withOpacity(0.18),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      CircleAvatar(
                        radius: 10,
                        backgroundColor: Colors.white.withOpacity(0.35),
                        child: Padding(
                          padding: const EdgeInsets.all(2.0),
                          child: Image.asset(
                            'assets/images/logo_galon.png',
                            width: 20,
                            height: 20,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class WavePainter extends CustomPainter {
  final double animationValue;

  WavePainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    _drawWave(canvas, size, Colors.white.withOpacity(0.22), 0, 1.0, 0.60);
    _drawWave(
      canvas,
      size,
      Colors.white.withOpacity(0.14),
      math.pi * 0.9,
      0.85,
      0.68,
    );
  }

  void _drawWave(
    Canvas canvas,
    Size size,
    Color color,
    double phase,
    double scale,
    double yFactor,
  ) {
    final paint = Paint()..color = color;
    final path = Path();
    final yOffset = size.height * yFactor;
    final amplitude = size.height * 0.12 * scale;
    path.moveTo(0, yOffset);

    for (double x = 0; x <= size.width; x += 1) {
      final y =
          yOffset +
          math.sin((x / size.width * 2 * math.pi) + animationValue + phase) *
              amplitude;
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant WavePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
