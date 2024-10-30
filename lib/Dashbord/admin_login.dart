import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:show_talent/Dashbord/admin_dashboard_screen.dart';
import '../controller/user_controller.dart'; 
import 'admin_signup.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  _AdminLoginScreenState createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  final UserController userController = Get.find<UserController>();

  Future<void> _loginAdmin() async {
    try {
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );

      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      if (!userDoc.exists) {
        Get.snackbar('Erreur', 'Utilisateur non trouvé dans Firestore');
        await FirebaseAuth.instance.signOut();
        return;
      }

      var userData = userDoc.data() as Map<String, dynamic>;

      if (userData['estBloque'] == true) {
        Get.snackbar('Accès refusé', 'Votre compte est bloqué.');
        await FirebaseAuth.instance.signOut();
        return;
      }

      if (userData['role'] == 'admin') {
        userController.setUserFromFirestore(userData);
        Get.offAll(() => AdminDashboardScreen());
      } else {
        Get.snackbar('Accès refusé', 'Vous n\'êtes pas un administrateur.');
        FirebaseAuth.instance.signOut();
      }
    } catch (e) {
      Get.snackbar('Erreur de connexion', e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(''),
        centerTitle: true,
        backgroundColor: const Color(0xFF214D4F),
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Affichage du logo et du nom
              Image.asset(
                'assets/logo.png',
                width: 100, // Ajustez la largeur selon vos besoins
                height: 100, 
              ),
              const SizedBox(height: 30),
              const Text(
                'Connexion Admin',
                style: TextStyle(
                  fontSize: 26, 
                  fontWeight: FontWeight.bold, 
                  color: Color(0xFF214D4F),
                ),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Adresse e-mail',
                  prefixIcon: const Icon(Icons.email),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Mot de passe',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _loginAdmin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF214D4F),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 16.0,
                    horizontal: 24.0,
                  ),
                ),
                child: const Text(
                  'Connexion',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
              const SizedBox(height: 60),
              TextButton(
                onPressed: () {
                  Get.to(() => const AdminSignupScreen());
                },
                child: const Text(
                  'Créer admin',
                  style: TextStyle(color: Color.fromARGB(255, 230, 238, 250), fontSize: 16),
                ),
              ),
            ],
          ), 
        ),
      ),
    );
  }
}