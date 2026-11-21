import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/account_provider.dart';
import '../providers/currency_provider.dart';
import '../services/backup_service.dart';
import '../theme/glass_tokens.dart';
import 'glass_surface.dart';

/// Account & Data card shown in Settings for private Google Drive auto-backup
/// and offline JSON Export / Import.
class AccountCard extends StatelessWidget {
  const AccountCard({super.key});

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AccountProvider>();
    final g = context.glass;
    final textTheme = Theme.of(context).textTheme;

    return GlassContainer(
      borderRadius: AppRadius.md,
      blur: 0,
      elevated: account.isSignedIn,
      borderColor: account.isSignedIn ? g.primary : g.glassBorder,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: account.isSignedIn ? g.primarySoft : g.surfaceSubtle,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(
                  account.isSignedIn
                      ? Icons.cloud_done_outlined
                      : Icons.cloud_outlined,
                  color: account.isSignedIn ? g.primary : g.textSecondary,
                  size: AppIconSize.lg,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Private Google Drive',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      account.isSignedIn
                          ? 'Auto-syncs to your own Drive appDataFolder on every change'
                          : 'Back up privately to your own Google Drive (only you have access)',
                      style: textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (account.isSignedIn) ...[
                const SizedBox(width: AppSpacing.sm),
                _SyncStatusBadge(isSyncing: account.isSyncing, g: g),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (!account.isAvailable)
            Text(
              'Google Drive auto-sync activates on Android & iOS. Use JSON Export/Import below anytime.',
              style: textTheme.bodySmall,
            )
          else if (!account.isSignedIn)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('google_sign_in_button'),
                onPressed:
                    account.isBusy ? null : () => _signIn(context, account),
                icon: account.isBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.login_rounded, size: 18),
                label: Text(
                  account.isBusy ? 'Connecting...' : 'Sign in with Google',
                ),
              ),
            )
          else ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: g.surfaceSubtle,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: g.primary,
                    backgroundImage: (account.photoUrl != null &&
                            account.photoUrl!.isNotEmpty)
                        ? NetworkImage(account.photoUrl!)
                        : null,
                    child: (account.photoUrl == null ||
                            account.photoUrl!.isEmpty)
                        ? Text(
                            _initial(account.displayName, account.email),
                            style: textTheme.labelLarge?.copyWith(
                              color: g.onPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          account.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          account.email.isNotEmpty
                              ? account.email
                              : 'Connected',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall,
                        ),
                        if (account.lastSyncedAt != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Last backup: ${DateFormat('d MMM, h:mm a').format(account.lastSyncedAt!)}',
                            style: textTheme.labelSmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (account.migrationNotice != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: g.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: g.glassBorder),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      size: 16,
                      color: g.primary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        account.migrationNotice!,
                        style: textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                FilledButton.icon(
                  onPressed: account.isBusy
                      ? null
                      : () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final ok = await account.backupNow();
                          if (ok) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Google Drive backup updated.'),
                              ),
                            );
                          }
                        },
                  icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                  label: const Text('Backup Now'),
                ),
                OutlinedButton.icon(
                  onPressed: account.isBusy
                      ? null
                      : () => _confirmRestore(context, account),
                  icon: const Icon(Icons.cloud_download_outlined, size: 18),
                  label: const Text('Restore'),
                ),
                TextButton.icon(
                  key: const Key('sign_out_button'),
                  onPressed: account.isBusy
                      ? null
                      : () => _confirmSignOut(context, account),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('Sign Out'),
                ),
              ],
            ),
          ],
          const Divider(height: AppSpacing.xl),
          const DataBackupTiles(),
          if (account.errorMessage != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: AppIconSize.sm,
                  color: g.danger,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    account.errorMessage!,
                    style: textTheme.bodySmall?.copyWith(color: g.danger),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _initial(String name, String email) {
    final src = name.trim().isNotEmpty
        ? name.trim()
        : (email.trim().isNotEmpty ? email.trim() : 'M');
    return src.substring(0, 1).toUpperCase();
  }

  Future<void> _signIn(BuildContext context, AccountProvider account) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await account.signIn();
    if (ok) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            account.email.isNotEmpty
                ? 'Signed in as ${account.email} · Private Drive connected'
                : 'Connected to your private Google Drive.',
          ),
        ),
      );
    }
  }

  Future<void> _confirmRestore(
    BuildContext context,
    AccountProvider account,
  ) async {
    final g = context.glass;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: g.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: g.glassBorder),
        ),
        title: const Text('Restore from Google Drive?'),
        content: const Text(
          'Replace current on-device entries, investments, categories, and currency with the snapshot in your private Google Drive?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final ok = await account.restoreFromDrive();
      if (ok) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Restored from Google Drive.')),
        );
      }
    }
  }

  Future<void> _confirmSignOut(
    BuildContext context,
    AccountProvider account,
  ) async {
    final g = context.glass;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: g.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: g.glassBorder),
        ),
        title: const Text('Sign out of Google?'),
        content: const Text(
          'Your data remains safely stored on this device and in your private Google Drive. Auto-backup will pause until you sign in again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await account.signOut();
      messenger.showSnackBar(const SnackBar(content: Text('Signed out')));
    }
  }
}

class _SyncStatusBadge extends StatelessWidget {
  const _SyncStatusBadge({required this.isSyncing, required this.g});

  final bool isSyncing;
  final GlassTokens g;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: g.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: g.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isSyncing)
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: g.primary,
              ),
            )
          else
            Icon(Icons.check_rounded, size: 14, color: g.success),
          const SizedBox(width: 5),
          Text(
            isSyncing ? 'Syncing...' : 'Synced',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: isSyncing ? g.primary : g.success,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

/// Offline JSON Export & Merge / Replace Import controls.
class DataBackupTiles extends StatelessWidget {
  const DataBackupTiles({super.key});

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AccountProvider>();
    final g = context.glass;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Local Data Export & Import',
          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(
          'Save an offline JSON copy of your entries, investments, and categories or restore from any backup file.',
          style: textTheme.bodySmall?.copyWith(color: g.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            OutlinedButton.icon(
              key: const Key('export_data_tile'),
              onPressed: account.isBusy ? null : () => _export(context),
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Export JSON'),
            ),
            OutlinedButton.icon(
              key: const Key('import_data_tile'),
              onPressed: account.isBusy ? null : () => _import(context),
              icon: const Icon(Icons.upload_file_outlined, size: 18),
              label: const Text('Import JSON'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _export(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final currency = context.read<CurrencyProvider>();
    try {
      await BackupService.instance.exportToJson(currencyCode: currency.code);
      messenger.showSnackBar(
        const SnackBar(content: Text('Backup JSON ready.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  Future<void> _import(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final currency = context.read<CurrencyProvider>();
    final account = context.read<AccountProvider>();
    final g = context.glass;

    try {
      final parsed = await BackupService.instance.pickBackupFile();
      if (parsed == null || !context.mounted) return;

      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: g.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            side: BorderSide(color: g.glassBorder),
          ),
          title: const Text('Import Backup File'),
          content: Text(
            'Found ${parsed.entries.length} entries, ${parsed.investments.length} investments, and ${parsed.categories.length} categories.\n\n'
            'Merge adds missing items without duplicates. Replace overwrites on-device data with this file.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx, 'replace'),
              child: const Text('Replace'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'merge'),
              child: const Text('Merge'),
            ),
          ],
        ),
      );

      if (choice == null || !context.mounted) return;

      final result = await BackupService.instance.applyBackup(
        parsed,
        merge: choice == 'merge',
        currencyProvider: currency,
      );
      await account.reloadAfterImport();

      final skippedText = result.skipped > 0
          ? ' (${result.skipped} duplicates skipped)'
          : '';
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            choice == 'merge'
                ? 'Merged ${result.entries} entries, ${result.investments} investments & ${result.categories} categories$skippedText'
                : 'Restored ${result.entries} entries & ${result.investments} investments from file.',
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
