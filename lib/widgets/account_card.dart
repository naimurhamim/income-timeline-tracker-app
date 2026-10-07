import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/account_provider.dart';
import '../providers/category_provider.dart';
import '../providers/entry_provider.dart';
import '../services/backup_service.dart';
import '../theme/app_colors.dart';

/// Account card shown at the top of Settings.
///
/// Guest: invites the user to sign in with Google.
/// Signed in: shows profile, sync note and a sign-out button.
class AccountCard extends StatelessWidget {
  const AccountCard({super.key});

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AccountProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: isDark ? AppColors.headerGradientDark : AppColors.headerGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryTeal.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        child: account.isSignedIn
            ? _SignedInView(account: account)
            : _GuestView(account: account),
      ),
    );
  }
}

class _GuestView extends StatelessWidget {
  const _GuestView({required this.account});

  final AccountProvider account;

  @override
  Widget build(BuildContext context) {
    final syncing = account.status == AccountStatus.syncing;
    final busy = account.isBusy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.cloud_upload_rounded,
                  color: AppColors.accentLime),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Back up your data',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Sign in with Google to keep your data safe and sync across devices.',
                    style: TextStyle(color: Colors.white70, fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (account.localEntryCount > 0 && !busy) ...[
          const SizedBox(height: 12),
          Text(
            '${account.localEntryCount} ${account.localEntryCount == 1 ? 'entry' : 'entries'} on this device will be uploaded to your account.',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
        if (syncing) ...[
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: account.syncProgress > 0 ? account.syncProgress : null,
              minHeight: 6,
              backgroundColor: Colors.white24,
              color: AppColors.accentLime,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Uploading your data… Please keep the app open.',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
        if (account.errorMessage != null && !busy) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    account.errorMessage!,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            key: const Key('google_sign_in_button'),
            onPressed: busy ? null : () => _signIn(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF1F1F1F),
              disabledBackgroundColor: Colors.white70,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.primaryTeal,
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'G',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF4285F4),
                        ),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Sign in with Google',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> _signIn(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await account.signIn();
    if (ok) {
      messenger.showSnackBar(
        SnackBar(content: Text('Signed in as ${account.email}')),
      );
    }
  }
}

class _SignedInView extends StatelessWidget {
  const _SignedInView({required this.account});

  final AccountProvider account;

  @override
  Widget build(BuildContext context) {
    final photo = account.photoUrl;
    final initial = account.displayName.isNotEmpty
        ? account.displayName[0].toUpperCase()
        : '?';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: AppColors.accentLime,
              backgroundImage: photo != null ? NetworkImage(photo) : null,
              child: photo == null
                  ? Text(
                      initial,
                      style: const TextStyle(
                        color: AppColors.primaryTeal,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    account.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_done_rounded,
                  color: AppColors.accentLime, size: 16),
              SizedBox(width: 6),
              Text(
                'Cloud sync on · works offline too',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            key: const Key('sign_out_button'),
            onPressed: () => _confirmSignOut(context),
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Sign out'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white54),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final unsynced = await account.hasUnsyncedChanges();
    if (!context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign out?'),
        content: Text(
          unsynced
              ? 'Some changes have not synced yet. Signing out now will lose them. '
                  'Connect to the internet and try again to keep them.'
              : 'Your data stays safe in your Google account and will come back '
                  'when you sign in again. It will be removed from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: unsynced ? AppColors.error : null,
            ),
            child: Text(unsynced ? 'Sign out anyway' : 'Sign out'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await account.signOut();
    messenger.showSnackBar(const SnackBar(content: Text('Signed out')));
  }
}

/// Export / import tiles used in the Settings "Data" section.
class DataBackupTiles extends StatelessWidget {
  const DataBackupTiles({super.key, required this.iconColor});

  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trailing = Icon(
      Icons.arrow_forward_ios_rounded,
      size: 14,
      color: theme.textTheme.bodySmall?.color,
    );

    return Column(
      children: [
        ListTile(
          key: const Key('export_data_tile'),
          leading: Icon(Icons.file_upload_outlined, color: iconColor),
          title: const Text('Export Data'),
          subtitle: const Text('Save a backup file (JSON)'),
          trailing: trailing,
          onTap: () => _export(context),
        ),
        const Divider(height: 1),
        ListTile(
          key: const Key('import_data_tile'),
          leading: Icon(Icons.file_download_outlined, color: iconColor),
          title: const Text('Import Data'),
          subtitle: const Text('Restore from a backup file'),
          trailing: trailing,
          onTap: () => _import(context),
        ),
      ],
    );
  }

  Future<void> _export(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await BackupService.instance.exportToJson();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  Future<void> _import(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final entries = context.read<EntryProvider>();
    final categories = context.read<CategoryProvider>();
    try {
      final result = await BackupService.instance.importFromJson();
      if (result.entries == 0 && result.categories == 0 && result.skipped == 0) {
        return;
      }
      await categories.loadCategories();
      await entries.loadAll();
      final skippedText = result.skipped > 0
          ? ' (${result.skipped} duplicates skipped)'
          : '';
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Imported ${result.entries} entries and ${result.categories} categories$skippedText',
          ),
        ),
      );
    } on FormatException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Import failed: $e')));
    }
  }
}
