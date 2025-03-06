import 'package:demo_app/service/login_service.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  final String email; // Accept email parameter
  const LoginPage({super.key, this.email = ''});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>(); // Add a form key

  bool _isLoading = false;
  bool _rememberMe = false;
  bool _passwordVisible = false;
  String? _passwordError; // To store the error message

@override
void initState() {
  super.initState();
  _loadCredentials();
  
  // Use email from constructor (provided by GoRouter)
  if (widget.email.isNotEmpty) {
    _emailController.text = widget.email;
  }
}

// Retrieve email from query parameters and set it to the email field
  void _getEmailFromQueryParams() {
    final email =
        Uri.parse(GoRouter.of(context).toString()).queryParameters['email'];
    if (email != null && email.isNotEmpty) {
      _emailController.text = email;
    }
  }

  void _loadCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('email') ?? '';
    final password = prefs.getString('password') ?? '';
    final rememberMe = prefs.getBool('rememberMe') ?? false;

    setState(() {
      _emailController.text = email;
      _passwordController.text = password;
      _rememberMe = rememberMe;
    });
  }

  void _saveCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('email', _emailController.text);
    prefs.setString('password', _passwordController.text);
    prefs.setBool('rememberMe', _rememberMe);
  }

void _login() async {
  if (_formKey.currentState?.validate() ?? false) {
    setState(() {
      _isLoading = true;
      _passwordError = null; // Reset the error message
    });

    final email = _emailController.text;
    final password = _passwordController.text;

    // Perform the login asynchronously, outside of setState()
    final response = await _authService.login(email, password);

    // After the async call, update the state synchronously inside setState()
    setState(() {
      _isLoading = false;
      if (response['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login successful!')),
        );

        // Save credentials if Remember Me is checked
        if (_rememberMe) {
          _saveCredentials();
        }

        // Update shared preferences to reflect the login status
        SharedPreferences.getInstance().then((prefs) {
          prefs.setBool('isUserLoggedIn', true); // Set the login status
        });

        // Reload the login status in the Home screen
        context.go('/'); // Use GoRouter to navigate to HomeScreen
      } else {
        // If login failed, display error message under the password field
        _passwordError = 'Incorrect email or password. Please try again.';
      }
    });
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey, // Set the form key
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Welcome to World! 👋',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Please sign-in to your account and start the adventure',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),

              // Email field with validation
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  } else if (!_isValidEmail(value)) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),

              // Password field with validation
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _passwordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _passwordVisible = !_passwordVisible;
                      });
                    },
                  ),
                ),
                obscureText: !_passwordVisible,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your password';
                  }
                  return null;
                },
              ),
              if (_passwordError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    _passwordError!,
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              const SizedBox(height: 8),

              // Remember Me & Forgot Password Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Checkbox(
                        value: _rememberMe,
                        onChanged: (value) {
                          setState(() {
                            _rememberMe = value!;
                          });
                        },
                      ),
                      const Text('Remember Me'),
                    ],
                  ),
                  TextButton(
                    onPressed: () {
                      context.go('/forgot-password');
                    },
                    child: const Text('Forgot Password?'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Login Button
              ElevatedButton(
                onPressed: _isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('SIGN IN'),
              ),
              const SizedBox(height: 16),
              Center(
                child: RichText(
                  text: TextSpan(
                    text: 'New on our platform? ',
                    style: const TextStyle(color: Colors.black, fontSize: 14),
                    children: [
                      TextSpan(
                        text: 'Create an account',
                        style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            context.go('/create-account');
                          },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Email validation method
  bool _isValidEmail(String email) {
    final emailRegex =
        RegExp(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$");
    return emailRegex.hasMatch(email);
  }
}
