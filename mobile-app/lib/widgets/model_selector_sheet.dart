import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/zero_theme.dart';

class ModelSelectorSheet extends StatefulWidget {
  const ModelSelectorSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ModelSelectorSheet(),
    );
  }

  @override
  State<ModelSelectorSheet> createState() => _ModelSelectorSheetState();
}

class _ModelSelectorSheetState extends State<ModelSelectorSheet> {
  String _effort = 'Low';

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      setState(() {
        _effort = prefs.getString('thinkmode_effort') ?? 'Low';
      });
    });
  }

  void _setEffort(String val) {
    setState(() => _effort = val);
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setString('thinkmode_effort', val),
    );
  }

  void _showPaywall(BuildContext context, String modelName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ZeroTheme.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: ZeroTheme.ink, width: 2),
        ),
        title: const Text('Upgrade to PRO', style: ZeroTheme.heading),
        content: Text(
          '$modelName is available on the PRO plan.',
          style: ZeroTheme.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: ZeroTheme.body.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(
    BuildContext context,
    String name,
    bool isPro, {
    bool isSelected = false,
  }) {
    return InkWell(
      onTap: () {
        if (isPro) {
          _showPaywall(context, name);
        } else {
          Navigator.pop(context, name);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: ZeroTheme.body.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isPro ? ZeroTheme.muted : ZeroTheme.ink,
                ),
              ),
            ),
            if (isPro)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: ZeroTheme.accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'PRO',
                  style: ZeroTheme.mono.copyWith(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (isSelected) ...[
              const SizedBox(width: 12),
              const Icon(Icons.check, color: ZeroTheme.ink, size: 20),
            ] else
              SizedBox(width: isPro ? 0 : 32),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: ZeroTheme.white,
        border: Border(
          top: BorderSide(color: ZeroTheme.ink, width: 2),
          left: BorderSide(color: ZeroTheme.ink, width: 2),
          right: BorderSide(color: ZeroTheme.ink, width: 2),
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: ZeroTheme.ink),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  const Text('Select model', style: ZeroTheme.heading),
                ],
              ),
            ),
            const Divider(color: Color(0xFFE5E7EB), height: 1, thickness: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Thinkmode Effort', style: ZeroTheme.heading),
                  ToggleButtons(
                    isSelected: [_effort == 'Low', _effort == 'High'],
                    onPressed: (index) =>
                        _setEffort(index == 0 ? 'Low' : 'High'),
                    borderRadius: BorderRadius.circular(8),
                    fillColor: ZeroTheme.ink,
                    selectedColor: ZeroTheme.white,
                    color: ZeroTheme.ink,
                    borderColor: ZeroTheme.ink,
                    selectedBorderColor: ZeroTheme.ink,
                    children: const [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Low',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'High',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFFE5E7EB), height: 1, thickness: 1),
            _buildRow(context, 'Titan-Small (Qwen 3.5)', false, isSelected: true),
            _buildRow(context, 'Grok 4.5', true),
            _buildRow(context, 'GPT 5.6 Sol', true),
            _buildRow(context, 'Opus 4.8', true),
            _buildRow(context, 'Fable 5', true),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
