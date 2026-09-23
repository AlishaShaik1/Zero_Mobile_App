import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/model_service.dart';
import '../services/search_service.dart';
import '../theme/zero_theme.dart';
import '../features/computer/device_bridge_service.dart';

class ComputerScreen extends StatefulWidget {
  final ModelService modelService;
  final SearchService searchService;
  const ComputerScreen({
    super.key,
    required this.modelService,
    required this.searchService,
  });

  @override
  State<ComputerScreen> createState() => _ComputerScreenState();
}

class _ComputerScreenState extends State<ComputerScreen>
    with WidgetsBindingObserver {
  final TextEditingController _commandController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<String> _logs = [];

  String? _bridgeEmail;
  String? _bridgePassword;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadCredentialsAndConnect();
  }

  Future<void> _loadCredentialsAndConnect() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('bridge_email');
    final password = prefs.getString('bridge_password');
    if (email != null &&
        email.isNotEmpty &&
        password != null &&
        password.isNotEmpty) {
      setState(() {
        _bridgeEmail = email;
        _bridgePassword = password;
        _isLoading = false;
      });
      _connectBridge();
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _connectBridge() async {
    if (_bridgeEmail == null || _bridgePassword == null) return;
    try {
      if (DeviceBridgeService.instance.status == BridgeStatus.offline) {
        await DeviceBridgeService.instance.connect(
          _bridgeEmail!,
          _bridgePassword!,
        );
      }
    } catch (e) {
      _addLog('❌ Connection Error: $e');
    }
  }

  Future<void> _saveCredentialsAndConnect(String email, String password) async {
    final e = email.trim();
    if (e.isEmpty || password.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bridge_email', e);
    await prefs.setString('bridge_password', password);
    setState(() {
      _bridgeEmail = e;
      _bridgePassword = password;
    });
    _connectBridge();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _connectBridge();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _commandController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _scrollController.dispose();
    DeviceBridgeService.instance.disconnect();
    super.dispose();
  }

  void _addLog(String msg) {
    if (!mounted) return;
    setState(() {
      _logs.add(
        '[${DateTime.now().toLocal().toString().split(' ')[1].split('.')[0]}] $msg',
      );
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendCommand() async {
    final text = _commandController.text.trim();
    if (text.isEmpty) return;

    _commandController.clear();
    _addLog('📤 Sent: $text');

    try {
      await DeviceBridgeService.instance.sendCommand(text);
    } catch (e) {
      _addLog('❌ Broadcast Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZeroTheme.cream,
      appBar: AppBar(
        backgroundColor: ZeroTheme.cream,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: ZeroTheme.ink),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            StreamBuilder<BridgeStatus>(
              stream: DeviceBridgeService.instance.statusStream,
              initialData: DeviceBridgeService.instance.status,
              builder: (context, snapshot) {
                final connected = snapshot.data == BridgeStatus.connected;
                return Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: connected ? Colors.green : Colors.red,
                    boxShadow: connected
                        ? [
                            BoxShadow(
                              color: Colors.green.withValues(alpha: 0.4),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
            Text(
              'COMPUTER LINK',
              style: ZeroTheme.mono.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
              ),
            ),
          ],
        ),
        actions: _bridgeEmail != null
            ? [
                IconButton(
                  icon: const Icon(Icons.logout, color: ZeroTheme.ink),
                  tooltip: 'Sign out connection',
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.remove('bridge_email');
                    await prefs.remove('bridge_password');
                    DeviceBridgeService.instance.disconnect();
                    setState(() {
                      _bridgeEmail = null;
                      _bridgePassword = null;
                      _logs.clear();
                    });
                  },
                ),
              ]
            : null,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: ZeroTheme.ink, thickness: 2),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: ZeroTheme.ink))
          : _bridgeEmail == null
          ? _buildLoginUi()
          : _buildChatInterface(),
    );
  }

  Widget _buildLoginUi() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.computer, size: 64, color: ZeroTheme.ink),
          const SizedBox(height: 24),
          Text(
            'Connect to Desktop Agent',
            textAlign: TextAlign.center,
            style: ZeroTheme.mono.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: ZeroTheme.ink,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Enter the same account credentials in the Zero Core Desktop Agent to bridge devices.',
            textAlign: TextAlign.center,
            style: ZeroTheme.bodyMuted,
          ),
          const SizedBox(height: 32),
          Container(
            decoration: ZeroTheme.hardCard(fill: ZeroTheme.white, radius: 12),
            child: TextField(
              controller: _emailController,
              style: ZeroTheme.body,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                hintText: 'Email (user@example.com)',
                hintStyle: ZeroTheme.bodyMuted,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: ZeroTheme.hardCard(fill: ZeroTheme.white, radius: 12),
            child: TextField(
              controller: _passwordController,
              style: ZeroTheme.body,
              obscureText: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _saveCredentialsAndConnect(
                _emailController.text,
                _passwordController.text,
              ),
              decoration: const InputDecoration(
                hintText: 'Password',
                hintStyle: ZeroTheme.bodyMuted,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => _saveCredentialsAndConnect(
              _emailController.text,
              _passwordController.text,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: ZeroTheme.hardCard(
                fill: ZeroTheme.accent,
                shadowColor: ZeroTheme.ink,
                radius: 12,
              ),
              alignment: Alignment.center,
              child: Text(
                'Connect Devices',
                style: ZeroTheme.mono.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  color: ZeroTheme.ink,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatInterface() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _logs.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  _logs[index],
                  style: ZeroTheme.mono.copyWith(
                    fontSize: 12,
                    color: ZeroTheme.ink,
                  ),
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ZeroTheme.white,
            border: Border(
              top: BorderSide(color: ZeroTheme.ink.withValues(alpha: 0.1)),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: ZeroTheme.hardCard(
                    fill: ZeroTheme.cream,
                    radius: 12,
                  ),
                  child: TextField(
                    controller: _commandController,
                    style: ZeroTheme.body,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendCommand(),
                    decoration: const InputDecoration(
                      hintText: 'Command desktop...',
                      hintStyle: ZeroTheme.bodyMuted,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _sendCommand,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: ZeroTheme.hardCard(
                    fill: ZeroTheme.ink,
                    radius: 12,
                    shadowColor: ZeroTheme.accent,
                  ),
                  child: const Icon(
                    Icons.send,
                    color: ZeroTheme.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
