import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/glass_tokens.dart';

/// Checks GitHub Releases for newer builds of Money Tracker and renders clean release notes.
class UpdateService {
  static const String _repoOwner = 'naimurhamim';
  static const String _repoName = 'income-timeline-tracker-app';
  static const String _apiUrl =
      'https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest';
  static const String _releasesUrl =
      'https://github.com/$_repoOwner/$_repoName/releases/latest';

  /// Check for updates and show appropriate dialog
  static Future<void> checkForUpdate(
    BuildContext context, {
    http.Client? client,
  }) async {
    final g = context.glass;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: g.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: g.glassBorder),
        ),
        content: Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: g.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            const Expanded(child: Text('Checking for updates...')),
          ],
        ),
      ),
    );

    final ownedClient = client == null;
    final httpClient = client ?? http.Client();
    final currentVersion = await getCurrentVersion();

    try {
      final response = await httpClient
          .get(
            Uri.parse(_apiUrl),
            headers: const {'Accept': 'application/vnd.github.v3+json'},
          )
          .timeout(const Duration(seconds: 12));

      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final rawTag = (data['tag_name'] ?? '0.0.0').toString();
        final latestTag = rawTag.replaceFirst(RegExp(r'^[vV]'), '');
        final releaseNotes = (data['body'] ?? '').toString();
        final releasePageUrl = (data['html_url'] ?? _releasesUrl).toString();

        var downloadUrl = releasePageUrl;
        final assets = data['assets'];
        if (assets is List) {
          for (final asset in assets) {
            if (asset is Map<String, dynamic>) {
              final url = asset['browser_download_url']?.toString() ?? '';
              if (url.toLowerCase().endsWith('.apk')) {
                downloadUrl = url;
                break;
              }
            }
          }
        }

        if (isNewerVersion(latestTag, currentVersion)) {
          _showUpdateDialog(
            context,
            currentVersion,
            latestTag,
            releaseNotes,
            downloadUrl,
          );
        } else {
          _showUpToDateDialog(context, currentVersion);
        }
      } else {
        _showErrorDialog(
          context,
          'Could not fetch update info (HTTP ${response.statusCode}). Please try again later.',
        );
      }
    } catch (_) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      _showErrorDialog(
        context,
        'No internet connection or server is unreachable. Please check your connection and try again.',
      );
    } finally {
      if (ownedClient) {
        httpClient.close();
      }
    }
  }

  static Future<String> getCurrentVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (info.version.trim().isNotEmpty) {
        return info.version.trim();
      }
    } catch (_) {}
    return '3.0.0';
  }

  /// Compares two semantic version strings (e.g. "v3.0.0" vs "2.1.0+7").
  static bool isNewerVersion(String latestRaw, String currentRaw) {
    final latestParts = _parseVersionParts(latestRaw);
    final currentParts = _parseVersionParts(currentRaw);
    final maxLen = latestParts.length > currentParts.length
        ? latestParts.length
        : currentParts.length;

    for (var i = 0; i < maxLen; i++) {
      final l = i < latestParts.length ? latestParts[i] : 0;
      final c = i < currentParts.length ? currentParts[i] : 0;
      if (l > c) return true;
      if (l < c) return false;
    }
    return false;
  }

  static List<int> _parseVersionParts(String raw) {
    var cleaned = raw.trim();
    if (cleaned.startsWith('v') || cleaned.startsWith('V')) {
      cleaned = cleaned.substring(1);
    }
    cleaned = cleaned.split('+').first.split('-').first;
    if (cleaned.isEmpty) return const [0];
    return cleaned
        .split('.')
        .map((segment) => int.tryParse(segment.trim()) ?? 0)
        .toList();
  }

  /// Parses GitHub Markdown release notes into clean styled blocks without raw `#`, `*`, `**` symbols.
  static List<ReleaseNoteBlock> parseReleaseNotes(String markdown) {
    final blocks = <ReleaseNoteBlock>[];
    final lines = markdown.replaceAll('\r\n', '\n').split('\n');
    var inCodeFence = false;

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.startsWith('```')) {
        inCodeFence = !inCodeFence;
        continue;
      }
      if (inCodeFence) {
        if (line.isNotEmpty) {
          blocks.add(
            ReleaseNoteBlock(
              kind: ReleaseNoteKind.paragraph,
              segments: [ReleaseNoteSegment(line, code: true)],
            ),
          );
        }
        continue;
      }
      if (line.isEmpty) continue;
      if (RegExp(r'^[-*_]{3,}$').hasMatch(line)) continue;

      final headingMatch = RegExp(r'^#{1,6}\s+(.*)$').firstMatch(line);
      if (headingMatch != null) {
        final content = headingMatch.group(1)!.trim();
        if (content.isNotEmpty) {
          blocks.add(
            ReleaseNoteBlock(
              kind: ReleaseNoteKind.heading,
              segments: _parseInlineSegments(content),
            ),
          );
        }
        continue;
      }

      final bulletMatch = RegExp(r'^(?:[-*+•])\s+(.*)$').firstMatch(line);
      if (bulletMatch != null) {
        final content = bulletMatch.group(1)!.trim();
        if (content.isNotEmpty) {
          blocks.add(
            ReleaseNoteBlock(
              kind: ReleaseNoteKind.bullet,
              segments: _parseInlineSegments(content),
            ),
          );
        }
        continue;
      }

      final numberedMatch = RegExp(r'^(\d+\.)\s+(.*)$').firstMatch(line);
      if (numberedMatch != null) {
        final marker = numberedMatch.group(1)!;
        final content = numberedMatch.group(2)!.trim();
        if (content.isNotEmpty) {
          blocks.add(
            ReleaseNoteBlock(
              kind: ReleaseNoteKind.numbered,
              marker: marker,
              segments: _parseInlineSegments(content),
            ),
          );
        }
        continue;
      }

      blocks.add(
        ReleaseNoteBlock(
          kind: ReleaseNoteKind.paragraph,
          segments: _parseInlineSegments(line),
        ),
      );
    }

    return blocks;
  }

  static List<ReleaseNoteSegment> _parseInlineSegments(String input) {
    final withLinksCleaned = input.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\(([^)]+)\)'),
      (m) => m.group(1) ?? '',
    );

    final segments = <ReleaseNoteSegment>[];
    final tokenRegex = RegExp(
      r'(\*\*(.+?)\*\*|__(.+?)__|`([^`]+)`|\*([^*]+?)\*)',
    );
    var cursor = 0;

    for (final match in tokenRegex.allMatches(withLinksCleaned)) {
      if (match.start > cursor) {
        segments.add(
          ReleaseNoteSegment(withLinksCleaned.substring(cursor, match.start)),
        );
      }
      if (match.group(2) != null) {
        segments.add(ReleaseNoteSegment(match.group(2)!, bold: true));
      } else if (match.group(3) != null) {
        segments.add(ReleaseNoteSegment(match.group(3)!, bold: true));
      } else if (match.group(4) != null) {
        segments.add(ReleaseNoteSegment(match.group(4)!, code: true));
      } else if (match.group(5) != null) {
        segments.add(ReleaseNoteSegment(match.group(5)!, italic: true));
      }
      cursor = match.end;
    }

    if (cursor < withLinksCleaned.length) {
      segments.add(ReleaseNoteSegment(withLinksCleaned.substring(cursor)));
    }

    return segments.isEmpty
        ? [ReleaseNoteSegment(withLinksCleaned)]
        : segments;
  }

  static void _showUpdateDialog(
    BuildContext context,
    String currentVersion,
    String latestVersion,
    String releaseNotes,
    String downloadUrl,
  ) {
    final g = context.glass;
    final textTheme = Theme.of(context).textTheme;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: g.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: g.glassBorder),
        ),
        title: Row(
          children: [
            Icon(Icons.system_update_rounded, color: g.primary),
            const SizedBox(width: AppSpacing.sm),
            const Expanded(child: Text('Update Available')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: g.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: g.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Current: v$currentVersion',
                      style: textTheme.bodySmall,
                    ),
                    Icon(Icons.arrow_forward_rounded,
                        size: 16, color: g.textSecondary),
                    Text(
                      'Latest: v$latestVersion',
                      style: TextStyle(
                        color: g.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (releaseNotes.trim().isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  "What's New",
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 240),
                  child: SingleChildScrollView(
                    child: _ReleaseNotesView(markdown: releaseNotes),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Later'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              final uri = Uri.tryParse(downloadUrl);
              if (uri != null) {
                launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Download'),
          ),
        ],
      ),
    );
  }

  static void _showUpToDateDialog(
      BuildContext context, String currentVersion) {
    final g = context.glass;
    final theme = Theme.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: g.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: g.glassBorder),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: g.success.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle_rounded,
                  color: g.success, size: 48),
            ),
            const SizedBox(height: 16),
            Text(
              "You're up to date!",
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Version $currentVersion is the latest.',
              style: theme.textTheme.bodySmall,
            ),
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
    final g = context.glass;
    final theme = Theme.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: g.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: g.glassBorder),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: g.danger.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.wifi_off_rounded, color: g.danger, size: 48),
            ),
            const SizedBox(height: 16),
            Text(
              'Connection Error',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
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

enum ReleaseNoteKind { heading, bullet, numbered, paragraph }

@immutable
class ReleaseNoteSegment {
  const ReleaseNoteSegment(
    this.text, {
    this.bold = false,
    this.italic = false,
    this.code = false,
  });

  final String text;
  final bool bold;
  final bool italic;
  final bool code;
}

@immutable
class ReleaseNoteBlock {
  const ReleaseNoteBlock({
    required this.kind,
    required this.segments,
    this.marker,
  });

  final ReleaseNoteKind kind;
  final List<ReleaseNoteSegment> segments;
  final String? marker;
}

class _ReleaseNotesView extends StatelessWidget {
  const _ReleaseNotesView({required this.markdown});

  final String markdown;

  @override
  Widget build(BuildContext context) {
    final blocks = UpdateService.parseReleaseNotes(markdown);
    final g = context.glass;
    final textTheme = Theme.of(context).textTheme;

    if (blocks.isEmpty) {
      return Text(
        'Improvements and bug fixes included.',
        style: textTheme.bodySmall?.copyWith(color: g.textSecondary),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < blocks.length; i++)
          _buildBlock(blocks[i], g, textTheme, isFirst: i == 0),
      ],
    );
  }

  Widget _buildBlock(
    ReleaseNoteBlock block,
    GlassTokens g,
    TextTheme textTheme, {
    required bool isFirst,
  }) {
    final baseStyle = (block.kind == ReleaseNoteKind.heading
            ? textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: g.textPrimary,
              )
            : textTheme.bodySmall?.copyWith(
                color: g.textSecondary,
                height: 1.4,
              )) ??
        const TextStyle(fontSize: 13);

    final rich = Text.rich(
      TextSpan(
        style: baseStyle,
        children: [
          for (final seg in block.segments)
            TextSpan(
              text: seg.text,
              style: TextStyle(
                fontWeight: seg.bold ? FontWeight.w700 : null,
                fontStyle: seg.italic ? FontStyle.italic : null,
                fontFamily: seg.code ? 'monospace' : null,
                color: (seg.bold || seg.code) ? g.textPrimary : null,
                backgroundColor: seg.code ? g.surfaceSubtle : null,
              ),
            ),
        ],
      ),
    );

    if (block.kind == ReleaseNoteKind.heading) {
      return Padding(
        padding: EdgeInsets.only(top: isFirst ? 0 : AppSpacing.sm, bottom: 4),
        child: rich,
      );
    }

    if (block.kind == ReleaseNoteKind.bullet ||
        block.kind == ReleaseNoteKind.numbered) {
      final prefix =
          block.kind == ReleaseNoteKind.bullet ? '•' : (block.marker ?? '•');
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: block.kind == ReleaseNoteKind.bullet ? 14 : 22,
              child: Text(
                prefix,
                style: baseStyle.copyWith(
                  color: g.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(child: rich),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: rich,
    );
  }
}
