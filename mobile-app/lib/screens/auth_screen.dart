import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/zero_theme.dart';
import '../widgets/mascot/zero_mascot.dart';
import 'chat_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  bool _isSignUp = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  String? _successMessage;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  EmotionState _mascotState = EmotionState.idle;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _switchTab(bool isSignUp) {
    if (_isSignUp == isSignUp) return;
    setState(() {
      _isSignUp = isSignUp;
      _errorMessage = null;
      _successMessage = null;
      _mascotState = EmotionState.idle;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      setState(() => _mascotState = EmotionState.thinking);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
      _mascotState = EmotionState.thinking;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();

    try {
      if (_isSignUp) {
        final res = await AuthService().signUpWithEmail(
          email: email,
          password: password,
          fullName: name,
        );

        if (!mounted) return;

        if (res.session != null || AuthService().isLoggedIn) {
          setState(() => _mascotState = EmotionState.happy);
          _navigateToChat();
        } else {
          // Email confirmation might be required depending on Supabase settings
          setState(() {
            _isLoading = false;
            _mascotState = EmotionState.happy;
            _successMessage =
                'Account created successfully! Please check your email to verify if required, or log in.';
            _isSignUp = false;
          });
        }
      } else {
        await AuthService().signInWithEmail(email: email, password: password);

        if (!mounted) return;
        setState(() => _mascotState = EmotionState.happy);
        _navigateToChat();
      }
    } catch (e) {
      if (!mounted) return;
      String errStr = e.toString();
      if (errStr.contains('Exception:')) {
        errStr = errStr.replaceAll('Exception:', '').trim();
      } else if (errStr.contains('AuthException')) {
        errStr = errStr.split('(').last.replaceAll(')', '').trim();
      }

      setState(() {
        _isLoading = false;
        _errorMessage = errStr;
        _mascotState = EmotionState.sad;
      });
    }
  }

  void _navigateToChat() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const ChatScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _errorMessage = 'Please enter a valid email address first.';
      });
      return;
    }

    try {
      await AuthService().resetPassword(email);
      setState(() {
        _successMessage = 'Password reset instructions sent to $email';
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              ZeroTheme.cream,
              Colors.white,
              ZeroTheme.accent.withValues(alpha: 0.08),
              Colors.white,
            ],
            stops: const [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 16.0,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ─── BRANDING / MASCOT HEADER CARD ───
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 28,
                        horizontal: 20,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: ZeroTheme.ink.withValues(alpha: 0.03),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          SizedBox(
                            height: 110,
                            width: 110,
                            child: ZeroMascot(state: _mascotState, size: 110),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Zero Air',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: ZeroTheme.ink,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isSignUp
                                ? 'Create your account to continue'
                                : 'Sign in to access your AI companion',
                            style: ZeroTheme.bodyMuted.copyWith(fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ─── SEGMENTED SWITCHER (LOGIN vs SIGN UP) ───
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: ZeroTheme.ink.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(32),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _switchTab(false),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: !_isSignUp
                                      ? ZeroTheme.accent
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(26),
                                ),
                                child: Text(
                                  'Log In',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: !_isSignUp
                                        ? Colors.white
                                        : ZeroTheme.muted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _switchTab(true),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: _isSignUp
                                      ? ZeroTheme.accent
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(26),
                                ),
                                child: Text(
                                  'Sign Up',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: _isSignUp
                                        ? Colors.white
                                        : ZeroTheme.muted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ─── AUTH FORM ───
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: ZeroTheme.ink.withValues(alpha: 0.03),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_errorMessage != null) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.red.shade200,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      color: Colors.red.shade700,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: TextStyle(
                                          color: Colors.red.shade900,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            if (_successMessage != null) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.green.shade200,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle_outline,
                                      color: Colors.green.shade700,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _successMessage!,
                                        style: TextStyle(
                                          color: Colors.green.shade900,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Full Name (Sign Up only)
                            if (_isSignUp) ...[
                              Text(
                                'Full Name',
                                style: ZeroTheme.heading.copyWith(fontSize: 13),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _nameController,
                                textInputAction: TextInputAction.next,
                                onTap: () => setState(
                                  () => _mascotState = EmotionState.curious,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Enter your name',
                                  prefixIcon: const Icon(
                                    Icons.person_outline,
                                    size: 20,
                                    color: ZeroTheme.accent,
                                  ),
                                  fillColor: Colors.white,
                                  filled: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    borderSide: BorderSide(
                                      color: ZeroTheme.ink.withValues(
                                        alpha: 0.06,
                                      ),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    borderSide: BorderSide(
                                      color: ZeroTheme.ink.withValues(
                                        alpha: 0.06,
                                      ),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    borderSide: const BorderSide(
                                      color: ZeroTheme.accent,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                validator: (val) {
                                  if (_isSignUp &&
                                      (val == null || val.trim().isEmpty)) {
                                    return 'Please enter your name';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Email Address
                            Text(
                              'Email Address',
                              style: ZeroTheme.heading.copyWith(fontSize: 13),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              onTap: () => setState(
                                () => _mascotState = EmotionState.curious,
                              ),
                              decoration: InputDecoration(
                                hintText: 'name@example.com',
                                prefixIcon: const Icon(
                                  Icons.email_outlined,
                                  size: 20,
                                  color: ZeroTheme.accent,
                                ),
                                fillColor: Colors.white,
                                filled: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: BorderSide(
                                    color: ZeroTheme.ink.withValues(
                                      alpha: 0.06,
                                    ),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: BorderSide(
                                    color: ZeroTheme.ink.withValues(
                                      alpha: 0.06,
                                    ),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: const BorderSide(
                                    color: ZeroTheme.accent,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              validator: (val) {
                                if (val == null ||
                                    val.trim().isEmpty ||
                                    !val.contains('@')) {
                                  return 'Please enter a valid email';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 16),

                            // Password
                            Text(
                              'Password',
                              style: ZeroTheme.heading.copyWith(fontSize: 13),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              onTap: () => setState(
                                () => _mascotState = EmotionState.curious,
                              ),
                              decoration: InputDecoration(
                                hintText: '••••••••',
                                prefixIcon: const Icon(
                                  Icons.lock_outline,
                                  size: 20,
                                  color: ZeroTheme.accent,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    size: 20,
                                    color: ZeroTheme.muted,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                                fillColor: Colors.white,
                                filled: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: BorderSide(
                                    color: ZeroTheme.ink.withValues(
                                      alpha: 0.06,
                                    ),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: BorderSide(
                                    color: ZeroTheme.ink.withValues(
                                      alpha: 0.06,
                                    ),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: const BorderSide(
                                    color: ZeroTheme.accent,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              validator: (val) {
                                if (val == null || val.isEmpty) {
                                  return 'Please enter your password';
                                }
                                if (_isSignUp && val.length < 6) {
                                  return 'Password must be at least 6 characters';
                                }
                                return null;
                              },
                            ),

                            if (!_isSignUp) ...[
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _handleForgotPassword,
                                  child: const Text(
                                    'Forgot Password?',
                                    style: TextStyle(
                                      color: ZeroTheme.accent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ] else
                              const SizedBox(height: 24),

                            // Submit Button
                            Container(
                              width: double.infinity,
                              height: 54,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(26),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF06B6D4),
                                    Color(0xFF0284C7),
                                  ],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: ZeroTheme.accent.withValues(
                                      alpha: 0.35,
                                    ),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _submit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  shadowColor: Colors.transparent,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(26),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 22,
                                        width: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          valueColor: AlwaysStoppedAnimation(
                                            Colors.white,
                                          ),
                                        ),
                                      )
                                    : Text(
                                        _isSignUp
                                            ? 'Create Account'
                                            : 'Sign In',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ─── ANONYMOUS / GUEST OPTION ───
                    Center(
                      child: TextButton(
                        onPressed: () async {
                          try {
                            await AuthService().signInAnonymously();
                            _navigateToChat();
                          } catch (_) {
                            _navigateToChat();
                          }
                        },
                        child: const Text(
                          'Continue as Guest',
                          style: TextStyle(
                            color: ZeroTheme.muted,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
