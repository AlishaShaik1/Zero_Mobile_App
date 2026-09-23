import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/zero_theme.dart';
import '../services/auth_service.dart';
import 'auth_screen.dart';
import 'splash_screen.dart'; // for SetupScreen navigation

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _thinkmodeEnabled = false;
  String _thinkmodeEffort = 'Low';
  bool _bargeInEnabled = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nameController.text = prefs.getString('user_name') ?? 'User';
      _thinkmodeEnabled = prefs.getBool('thinkmode_enabled') ?? false;
      _thinkmodeEffort = prefs.getString('thinkmode_effort') ?? 'Low';
      _bargeInEnabled = prefs.getBool('barge_in_enabled') ?? true;
      _emailController.text = prefs.getString('bridge_email') ?? '';
      _passwordController.text = prefs.getString('bridge_password') ?? '';
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    HapticFeedback.mediumImpact();
    final prefs = await SharedPreferences.getInstance();
    
    final name = _nameController.text.trim();
    if (name.isNotEmpty) {
      await prefs.setString('user_name', name);
    }

    await prefs.setBool('thinkmode_enabled', _thinkmodeEnabled);
    await prefs.setString('thinkmode_effort', _thinkmodeEffort);
    await prefs.setBool('barge_in_enabled', _bargeInEnabled);

    final email = _emailController.text.trim();
    if (email.isNotEmpty) {
      await prefs.setString('bridge_email', email);
    } else {
      await prefs.remove('bridge_email');
    }

    final password = _passwordController.text.trim();
    if (password.isNotEmpty) {
      await prefs.setString('bridge_password', password);
    } else {
      await prefs.remove('bridge_password');
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Settings saved successfully', style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          backgroundColor: ZeroTheme.ink,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  Future<void> _resetSetup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('setup_done', false);
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SplashScreen()),
        (route) => false,
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 12.0, top: 24.0),
      child: Text(
        title,
        style: const TextStyle(
          color: ZeroTheme.muted,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool obscureText = false, IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        style: const TextStyle(color: ZeroTheme.ink, fontSize: 16, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: ZeroTheme.muted),
          prefixIcon: icon != null ? Icon(icon, color: ZeroTheme.muted, size: 20) : null,
          fillColor: ZeroTheme.background,
          filled: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: ZeroTheme.ink.withValues(alpha: 0.05)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: ZeroTheme.accent, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(IconData icon, {Color color = ZeroTheme.accent}) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: ZeroTheme.cream,
        body: Center(child: CircularProgressIndicator(color: ZeroTheme.accent)),
      );
    }

    return Scaffold(
      backgroundColor: ZeroTheme.cream,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            backgroundColor: ZeroTheme.cream,
            surfaceTintColor: Colors.transparent,
            title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('PROFILE'),
                  Container(
                    decoration: ZeroTheme.hardCard(radius: 20),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        _buildTextField('Your Name', _nameController, icon: Icons.person_outline),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                  
                  _buildSectionHeader('AGENTIC AI'),
                  Container(
                    decoration: ZeroTheme.hardCard(radius: 20),
                    child: Column(
                      children: [
                        SwitchListTile(
                          secondary: _buildIcon(Icons.psychology),
                          title: const Text('Enable Thinkmode', style: TextStyle(color: ZeroTheme.ink, fontWeight: FontWeight.w600)),
                          subtitle: const Text('Allows AI to think step-by-step before answering', style: TextStyle(color: ZeroTheme.muted, fontSize: 13, height: 1.3)),
                          value: _thinkmodeEnabled,
                          activeThumbColor: ZeroTheme.white,
                          activeTrackColor: ZeroTheme.accent,
                          onChanged: (val) {
                            HapticFeedback.lightImpact();
                            setState(() => _thinkmodeEnabled = val);
                          },
                        ),
                        Divider(color: ZeroTheme.ink.withValues(alpha: 0.05), height: 1, indent: 64),
                        ListTile(
                          leading: _buildIcon(Icons.speed, color: ZeroTheme.muted),
                          title: const Text('Thinkmode Effort', style: TextStyle(color: ZeroTheme.ink, fontWeight: FontWeight.w600)),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: ZeroTheme.background,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: ZeroTheme.ink.withValues(alpha: 0.05)),
                            ),
                            child: DropdownButton<String>(
                              value: _thinkmodeEffort,
                              underline: const SizedBox(),
                              icon: const Icon(Icons.expand_more, color: ZeroTheme.muted, size: 20),
                              dropdownColor: Colors.white,
                              items: const [
                                DropdownMenuItem(value: 'Low', child: Text('Low', style: TextStyle(color: ZeroTheme.ink, fontWeight: FontWeight.w500))),
                                DropdownMenuItem(value: 'Max', child: Text('Max', style: TextStyle(color: ZeroTheme.ink, fontWeight: FontWeight.w500))),
                              ],
                              onChanged: _thinkmodeEnabled ? (val) {
                                if (val != null) setState(() => _thinkmodeEffort = val);
                              } : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  _buildSectionHeader('VOICE AGENT'),
                  Container(
                    decoration: ZeroTheme.hardCard(radius: 20),
                    child: SwitchListTile(
                      secondary: _buildIcon(Icons.record_voice_over),
                      title: const Text('Live Interruption (Barge-in)', style: TextStyle(color: ZeroTheme.ink, fontWeight: FontWeight.w600)),
                      subtitle: const Text('Allow interrupting the AI while it is speaking', style: TextStyle(color: ZeroTheme.muted, fontSize: 13, height: 1.3)),
                      value: _bargeInEnabled,
                      activeThumbColor: ZeroTheme.white,
                      activeTrackColor: ZeroTheme.accent,
                      onChanged: (val) {
                        HapticFeedback.lightImpact();
                        setState(() => _bargeInEnabled = val);
                      },
                    ),
                  ),

                  _buildSectionHeader('COMPUTER BRIDGE'),
                  Container(
                    decoration: ZeroTheme.hardCard(radius: 20),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Row(
                            children: [
                              _buildIcon(Icons.computer, color: Colors.blueAccent),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: Text(
                                  'Connect your PC to allow the AI agent to control it directly via the bridge protocol.',
                                  style: TextStyle(color: ZeroTheme.muted, fontSize: 13, height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildTextField('Bridge Email', _emailController, icon: Icons.email_outlined),
                        _buildTextField('Bridge Password', _passwordController, obscureText: true, icon: Icons.lock_outline),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),

                  _buildSectionHeader('SYSTEM & ACCOUNT'),
                  Container(
                    decoration: ZeroTheme.hardCard(radius: 20),
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          leading: const CircleAvatar(
                            backgroundColor: ZeroTheme.cream,
                            child: Icon(Icons.person, color: ZeroTheme.accent),
                          ),
                          title: Text(
                            AuthService().userName,
                            style: const TextStyle(
                              color: ZeroTheme.ink,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            AuthService().currentUser?.email ?? 'Guest Session',
                            style: const TextStyle(
                              color: ZeroTheme.muted,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Divider(color: ZeroTheme.ink.withValues(alpha: 0.05), height: 1),
                        ListTile(
                          leading: _buildIcon(Icons.restore, color: Colors.orange),
                          title: const Text('Reset Setup', style: TextStyle(color: ZeroTheme.ink, fontWeight: FontWeight.w600)),
                          subtitle: const Text('Redo the welcome onboarding', style: TextStyle(color: ZeroTheme.muted, fontSize: 13)),
                          trailing: const Icon(Icons.chevron_right, color: ZeroTheme.muted),
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                backgroundColor: Colors.white,
                                title: const Text('Reset Setup?', style: TextStyle(color: ZeroTheme.ink, fontWeight: FontWeight.bold)),
                                content: const Text('This will take you back to the welcome screen. Are you sure?', style: TextStyle(color: ZeroTheme.muted)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(),
                                    child: const Text('Cancel', style: TextStyle(color: ZeroTheme.muted, fontWeight: FontWeight.bold)),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                      _resetSetup();
                                    },
                                    child: const Text('Reset', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        Divider(color: ZeroTheme.ink.withValues(alpha: 0.05), height: 1),
                        ListTile(
                          leading: _buildIcon(Icons.logout, color: Colors.redAccent),
                          title: const Text('Sign Out', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
                          onTap: () async {
                            HapticFeedback.mediumImpact();
                            await AuthService().signOut();
                            if (!context.mounted) return;
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (context) => const AuthScreen(),
                              ),
                              (route) => false,
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  // Bottom padding for scrolling over the FAB
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: FloatingActionButton.extended(
          onPressed: _saveSettings,
          backgroundColor: ZeroTheme.ink,
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          label: const Row(
            children: [
              Icon(Icons.save, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'Save Settings',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
