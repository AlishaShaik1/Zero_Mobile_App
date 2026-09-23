import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme/zero_theme.dart';

/// ── PERMISSIONS SERVICE ──────────────────────────────────────────────────────
/// Requests ALL runtime permissions at startup and opens system settings dialogs
/// for special permissions (WRITE_SETTINGS, DND, Accessibility).
/// No BuildContext used across async gaps.

class PermissionsService {
  static const MethodChannel _channel = MethodChannel(
    'com.example.zero_air/tools',
  );

  /// Call from SplashScreen BEFORE navigating. Pass [context] synchronously.
  static Future<void> requestAllAtStartup(BuildContext context) async {
    if (!Platform.isAndroid) return;

    // Capture navigator before any await so we never use context across an async gap
    final NavigatorState nav = Navigator.of(context);

    // ── Phase 1: Standard runtime permissions ───────────────────────────────
    await [
      Permission.phone, // CALL_PHONE — direct calls
      Permission.sms, // SEND_SMS — silent send
      Permission.contacts, // READ_CONTACTS
      Permission.camera, // CAMERA / torch
      Permission.storage, // Storage < Android 13
      Permission.photos, // READ_MEDIA_IMAGES >= Android 13
      Permission.audio, // READ_MEDIA_AUDIO >= Android 13
      Permission.notification, // POST_NOTIFICATIONS >= Android 13
      Permission.calendarFullAccess, // READ/WRITE_CALENDAR (non-deprecated)
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.microphone,
      Permission.location,
      Permission.accessNotificationPolicy, // DND
    ].request();

    // ── Phase 2: Special permissions via Settings screens ───────────────────
    // nav.overlay is always mounted as long as the app is running
    final overlay = nav.overlay;
    if (overlay == null) return;

    // Each helper captures context locally & checks mounted before showing dialog
    if (overlay.mounted) await _requestWriteSettings(overlay.context);
    if (overlay.mounted) await _requestDndIfNeeded(overlay.context);
    if (overlay.mounted) await _requestAccessibilityIfNeeded(overlay.context);
  }

  // ── WRITE_SETTINGS (screen brightness) ─────────────────────────────────────
  static Future<void> _requestWriteSettings(BuildContext ctx) async {
    final bool? canWrite = await _channel.invokeMethod<bool>(
      'check_write_settings',
    );
    if (canWrite == true) return;
    if (!ctx.mounted) return;

    await showDialog<void>(
      context: ctx,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => _PermDialog(
        title: 'Modify System Settings',
        body:
            'Zero needs permission to adjust screen brightness.\n\n'
            'Tap Allow → enable "Modify system settings" for Zero Air.',
        icon: Icons.brightness_auto_rounded,
        onAllow: () => _channel.invokeMethod<void>('open_write_settings'),
      ),
    );
  }

  // ── DND / Notification Policy ────────────────────────────────────────────────
  static Future<void> _requestDndIfNeeded(BuildContext ctx) async {
    final status = await Permission.accessNotificationPolicy.status;
    if (status.isGranted) return;
    if (!ctx.mounted) return;

    await showDialog<void>(
      context: ctx,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => _PermDialog(
        title: 'Do Not Disturb Access',
        body:
            'Zero needs DND access to manage notification policy.\n\n'
            'Tap Allow → find Zero Air → enable it.',
        icon: Icons.notifications_off_rounded,
        onAllow: () => _channel.invokeMethod<void>('open_dnd_settings'),
      ),
    );
  }

  // ── Accessibility Service (UI Automator / Browser Agent) ─────────────────────
  static Future<void> _requestAccessibilityIfNeeded(BuildContext ctx) async {
    final bool? enabled = await _channel.invokeMethod<bool>(
      'check_accessibility_enabled',
    );
    if (enabled == true) return;
    if (!ctx.mounted) return;

    await showDialog<void>(
      context: ctx,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => _PermDialog(
        title: 'Accessibility Access',
        body:
            'Zero needs Accessibility Service to automate apps on your behalf.\n\n'
            'Tap Enable → find "Zero Air" → turn it ON.',
        allowLabel: 'Enable',
        icon: Icons.accessibility_new_rounded,
        onAllow: () =>
            _channel.invokeMethod<void>('open_accessibility_settings'),
      ),
    );
  }
}

/// Reusable permission dialog — Zero-branded, premium design.
/// Icon is contextual (passed in), card is white with cyan accent.
class _PermDialog extends StatelessWidget {
  final String title;
  final String body;
  final String allowLabel;
  final Future<void> Function() onAllow;
  final IconData icon;

  const _PermDialog({
    required this.title,
    required this.body,
    required this.onAllow,
    this.allowLabel = 'Allow',
    this.icon = Icons.security_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 40,
              spreadRadius: 0,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon badge
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: ZeroTheme.accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: ZeroTheme.accent,
                size: 26,
              ),
            ),
            const SizedBox(height: 20),
            // Title
            Text(
              title,
              style: const TextStyle(
                color: ZeroTheme.ink,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                fontFamily: 'Inter',
                letterSpacing: -0.4,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            // Body
            Text(
              body,
              style: TextStyle(
                color: ZeroTheme.ink.withValues(alpha: 0.55),
                fontSize: 14,
                fontFamily: 'Inter',
                height: 1.55,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 28),
            // Buttons
            Row(
              children: [
                // Skip button
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: ZeroTheme.ink.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        'Skip',
                        style: TextStyle(
                          color: ZeroTheme.ink.withValues(alpha: 0.55),
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Allow button
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      onAllow();
                    },
                    child: Container(
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            ZeroTheme.accent,
                            ZeroTheme.accent.withValues(alpha: 0.80),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: ZeroTheme.accent.withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Text(
                        allowLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
