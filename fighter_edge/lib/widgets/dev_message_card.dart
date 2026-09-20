import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../controllers/auth_controller.dart';
import '../l10n/gen/app_localizations.dart';
import '../models/dev_message.dart';
import '../theme/app_accessibility.dart';
import '../theme/app_colors.dart';
import '../theme/app_haptics.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../widgets/premium_effects.dart';
import '../widgets/primary_button.dart';
import '../widgets/stat_card.dart';

/// Shows a note the developer left on this account — once.
///
/// Dismissal is stored on the device by message id rather than written back
/// to Firestore: the client has no business writing to its own profile
/// document, and a note that reappears after a reinstall is a far smaller
/// problem than loosening those rules.
class DevMessageCard extends StatefulWidget {
  const DevMessageCard({super.key});

  @override
  State<DevMessageCard> createState() => _DevMessageCardState();
}

class _DevMessageCardState extends State<DevMessageCard> {
  static String _key(String userId, String messageId) =>
      'fe_dev_message.$userId.$messageId';

  String? _dismissedId;
  bool _checked = false;
  String? _checkedFor;

  Future<void> _check(String userId, DevMessage message) async {
    _checkedFor = message.id;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_key(userId, message.id)) == true) {
        if (mounted) setState(() => _dismissedId = message.id);
      }
    } catch (_) {
      // Unreadable prefs just means the note shows again.
    }
    if (mounted) setState(() => _checked = true);
  }

  Future<void> _dismiss(String userId, DevMessage message) async {
    AppHaptics.tap();
    setState(() => _dismissedId = message.id);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key(userId, message.id), true);
    } catch (_) {
      // Dismissed for this session either way.
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().user;
    final message = user?.devMessage;
    if (user == null || message == null) return const SizedBox.shrink();

    if (_checkedFor != message.id) {
      _checked = false;
      _dismissedId = null;
      // A new note arrives while the screen is up: check it after this frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _check(user.id, message);
      });
    }
    // Nothing flashes on screen before the dismissal check has answered.
    if (!_checked || _dismissedId == message.id) {
      return const SizedBox.shrink();
    }

    final l = L.of(context);
    return PremiumReveal(
      child: Padding(
        padding: const EdgeInsets.only(bottom: Insets.lg),
        child: AppCard(
          accent: AppColors.premium,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.campaign_outlined,
                      size: IconSizes.inline, color: AppColors.premium),
                  const SizedBox(width: Insets.sm),
                  Expanded(
                    child: Text(
                      l.devMessageFrom(message.from),
                      style: AppType.micro(
                        weight: FontWeight.w800,
                        color: AppAccessibility.textMuted(context),
                        spacing: .8,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Insets.sm),
              Text(message.title, style: AppType.title2()),
              const SizedBox(height: Insets.xs),
              Text(
                message.body,
                style: AppType.callout(
                    color: AppAccessibility.textSecondary(context)),
              ),
              const SizedBox(height: Insets.md),
              GhostButton(
                l.devMessageGotIt,
                expand: true,
                onPressed: () => _dismiss(user.id, message),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
