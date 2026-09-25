import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

class UpdateService {
  static const String _repoOwner = 'naimurhamim';
  static const String _repoName = 'income-timeline-tracker-app';
  static const String _apiUrl =
      'https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest';
  static const String _releasesUrl =
      'https://github.com/$_repoOwner/$_repoName/releases/latest';

  /// Check for updates and show appropriate dialog
  static Future<void> checkForUpdate(BuildContext context) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = isDark ? const Color(0xFFB8E648) : const Color(0xFF1B3A4B);

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: accentColor),
              const SizedBox(height: 16),
              Text('Checking for updates...', style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final response = await http
          .get(Uri.parse(_apiUrl), headers: {'Accept': 'application/vnd.github.v3+json'})
          .timeout(const Duration(seconds: 10));

      if (!context.mounted) return;
      Navigator.pop(context); // dismiss loading

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final latestTag = (data['tag_name'] as String).replaceFirst('v', '');
        final releaseNotes = data['body'] as String? ?? '';

        if (_isNewerVersion(currentVersion, latestTag)) {
          _showUpdateDialog(context, currentVersion, latestTag, releaseNotes);
        } else {
          _showUpToDateDialog(context, currentVersion);
        }
      } else {
        _showErrorDialog(context, 'Could not fetch update info. Please try again later.');
      }
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context); // dismiss loading
      _showErrorDialog(
        context,
        'No internet connection or server is unreachable. Please check your connection and try again.',
      );
    }
  }

  /// Compare version strings (e.g., "1.0.0" vs "1.1.0")
  static bool _isNewerVersion(String current, String latest) {
    final currentParts = current.split('.').map(int.parse).toList();
    final latestParts = latest.split('.').map(int.parse).toList();

    for (int i = 0; i < 3; i++) {
      final c = i < currentParts.length ? currentParts[i] : 0;
      final l = i < latestParts.length ? latestParts[i] : 0;
      if (l > c) return true;
      if (l < c) return false;
    }
    return false;
  }

  static void _showUpdateDialog(
    BuildContext context,
    String currentVersion,
    String latestVersion,
    String releaseNotes,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = isDark ? const Color(0xFFB8E648) : const Color(0xFF1B3A4B);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.system_update_rounded, color: accentColor),
            const SizedBox(width: 10),
            const Expanded(child: Text('Update Available')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Current: v$currentVersion',
                      style: theme.textTheme.bodySmall),
                  const Icon(Icons.arrow_forward_rounded, size: 16),
                  Text('Latest: v$latestVersion',
                      style: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.w700,
                      )),
                ],
              ),
            ),
            if (releaseNotes.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('What\'s new:', style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 150),
                child: SingleChildScrollView(
                  child: Text(
                    releaseNotes,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Later'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              launchUrl(Uri.parse(_releasesUrl), mode: LaunchMode.externalApplication);
            },
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Download'),
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: isDark ? Colors.black : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  static void _showUpToDateDialog(BuildContext context, String currentVersion) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2ECC71).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF2ECC71), size: 48),
            ),
            const SizedBox(height: 16),
            Text('You\'re up to date!',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('Version $currentVersion is the latest.',
                style: theme.textTheme.bodySmall),
          ],
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ),
        ],
      ),
    );
  }

  static void _showErrorDialog(BuildContext context, String message) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B6B).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.wifi_off_rounded,
                  color: Color(0xFFFF6B6B), size: 48),
            ),
            const SizedBox(height: 16),
            Text('Connection Error',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(message,
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center),
          ],
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ),
        ],
      ),
    );
  }
}
