import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../billing/subscription.dart';
import '../controllers/auth_controller.dart';
import '../l10n/gen/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

/// Asks for the typed confirmation, then deletes the account and all of its
/// data on the server. Settings uses it, and so does the health-data consent
/// screen: withdrawing that consent means deleting the data.
Future<void> confirmAndDeleteAccount(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => const DeleteAccountDialog(),
  );
  if (confirmed != true || !context.mounted) return;

  try {
    await context.read<AuthController>().deleteAccount();
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$e')),
    );
  }
}

/// Requires typing DELETE before the button enables — a deliberate speed
/// bump for an irreversible action, not just a yes/no tap.
class DeleteAccountDialog extends StatefulWidget {
  const DeleteAccountDialog({super.key});

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  final _controller = TextEditingController();
  bool _confirmed = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A store subscription outlives the account (audit D-9): say so while
    // the athlete can still cancel it.
    final user = context.read<AuthController>().user;
    final subscribed = user != null &&
        (user.plan == Plan.pro || user.planWillRenew || user.isPro);
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Delete your account?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This permanently erases your account, weight history, training '
            'sessions, and nutrition data. This cannot be undone.',
            style: AppType.subhead(color: AppColors.textSecondary),
          ),
          if (subscribed) ...[
            const SizedBox(height: Insets.md),
            Text(
              L.of(context).deleteAccountSubscriptionWarning,
              key: const ValueKey('delete-subscription-warning'),
              style: AppType.subhead(
                weight: FontWeight.w700,
                color: AppColors.warning,
              ),
            ),
          ],
          const SizedBox(height: Insets.md),
          Text(
            'Type DELETE to confirm.',
            style: AppType.subhead(weight: FontWeight.w700),
          ),
          const SizedBox(height: Insets.sm),
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            onChanged: (v) => setState(() => _confirmed = v.trim() == 'DELETE'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _confirmed ? () => Navigator.of(context).pop(true) : null,
          style: TextButton.styleFrom(foregroundColor: AppColors.negative),
          child: const Text('Delete forever'),
        ),
      ],
    );
  }
}
