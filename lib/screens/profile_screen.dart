// lib/screens/profile_screen.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';

import '../services/auth_service.dart';
import '../services/locale_controller.dart';
import '../theme/tea_theme.dart';
import '../widgets/factory_rate_sheet.dart';
import 'privacy_policy_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = FirebaseAuth.instance;
  late User _user;
  late String _username;
  String? _avatarUrl;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _user = _auth.currentUser!;
    _username = _user.displayName ?? 'Farmer';
    _avatarUrl =
        'https://api.dicebear.com/6.x/bottts/png?seed=${_user.uid}&size=200';
  }

  String get _email => _user.email ?? '—';

  String get _memberSince {
    final t = _user.metadata.creationTime;
    return t == null ? '—' : DateFormat('MMM yyyy').format(t);
  }

  // ── Actions ──────────────────────────────────────────────────────────────
  Future<void> _changeUsername() async {
    final l = AppLocalizations.of(context);
    final formKey = GlobalKey<FormState>();
    final ctrl = TextEditingController(text: _username);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(l.changeUsername),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: ctrl,
            maxLength: 7,
            decoration: InputDecoration(
              labelText: l.newUsername,
              hintText: 'Max 7 letters',
            ),
            validator: (v) {
              final s = v?.trim() ?? '';
              if (s.isEmpty) return l.required;
              if (s == _username) return 'Pick a different name';
              if (s.length > 7) return 'No more than 7 letters';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.commonCancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: TeaTheme.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              setState(() => _busy = true);
              final newName = ctrl.text.trim();
              await _user.updateDisplayName(newName);
              await _user.reload();
              _user = _auth.currentUser!;
              if (!mounted) return;
              setState(() {
                _username = newName;
                _busy = false;
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l.usernameUpdated),
                  backgroundColor: TeaTheme.deep,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l.commonSave),
          ),
        ],
      ),
    );
  }

  Future<void> _openRateCard() async {
    final l = AppLocalizations.of(context);
    final saved = await showFactoryRateSheet(context);
    if (saved && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.rateUpdated),
          backgroundColor: TeaTheme.deep,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openLanguagePicker() async {
    final l = AppLocalizations.of(context);
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: TeaTheme.bgTop,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Icon(Icons.translate_rounded,
                        color: TeaTheme.primary, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      l.selectLanguage,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: TeaTheme.deep,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ...LocaleController.supported.entries.map((e) {
                final selected = LocaleController.currentCode == e.key;
                return ListTile(
                  onTap: () async {
                    await LocaleController.setLocale(e.key);
                    if (context.mounted) Navigator.pop(context);
                  },
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: selected
                        ? TeaTheme.primary
                        : TeaTheme.surface,
                    child: Text(
                      e.key.toUpperCase(),
                      style: TextStyle(
                        color: selected ? Colors.white : TeaTheme.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  title: Text(
                    e.value,
                    style: TextStyle(
                      fontWeight:
                          selected ? FontWeight.w800 : FontWeight.w600,
                      color: TeaTheme.deep,
                    ),
                  ),
                  trailing: selected
                      ? const Icon(Icons.check_circle_rounded,
                          color: TeaTheme.primary)
                      : null,
                );
              }),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _openAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'TeaOptima',
      applicationVersion: 'v1.0.0',
      applicationIcon: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: TeaTheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.eco_rounded, color: TeaTheme.primary),
      ),
      children: const [
        SizedBox(height: 12),
        Text(
          'AI-powered tea leaf quality grading and degradation forecasting '
          'for Sri Lankan tea estates. Capture a leaf, get a 15-day quality '
          'forecast, harvest urgency, and economic impact insights.',
          style: TextStyle(height: 1.4),
        ),
      ],
    );
  }

  Future<void> _signOut() async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(l.signOut),
        content: Text(l.signOutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.commonCancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD9534F),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.signOut),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await AuthService.signOut(); // signs out Firebase + Google
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  // ── UI ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: TeaTheme.bgTop,
      extendBody: true,
      body: Container(
        decoration: TeaTheme.screenGradient(),
        child: SingleChildScrollView(
          child: Column(
            children: [
              _header(),
              const SizedBox(height: 58), // room for overlapping avatar
              Text(
                _username,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: TeaTheme.deep,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _email,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: TeaTheme.surface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_rounded,
                        size: 13, color: TeaTheme.primary),
                    const SizedBox(width: 5),
                    Text(
                      l.teaGrowerSince(_memberSince),
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: TeaTheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    _sectionLabel(l.sectionAccount),
                    _card([
                      _tile(
                        icon: Icons.person_rounded,
                        accent: TeaTheme.primary,
                        title: l.labelUsername,
                        subtitle: _username,
                        trailing: const Icon(Icons.edit_rounded,
                            size: 18, color: TeaTheme.primary),
                        onTap: _changeUsername,
                      ),
                      _divider(),
                      _tile(
                        icon: Icons.email_rounded,
                        accent: TeaTheme.mid,
                        title: l.labelEmail,
                        subtitle: _email,
                      ),
                    ]),
                    const SizedBox(height: 18),
                    _sectionLabel(l.sectionPreferences),
                    _card([
                      _tile(
                        icon: Icons.payments_rounded,
                        accent: TeaTheme.gold,
                        title: l.factoryRateCard,
                        subtitle: l.factoryRateCardSub,
                        trailing: Icon(Icons.chevron_right_rounded,
                            color: Colors.grey.shade400),
                        onTap: _openRateCard,
                      ),
                      _divider(),
                      _tile(
                        icon: Icons.translate_rounded,
                        accent: const Color(0xFF6366F1),
                        title: l.appLanguage,
                        subtitle: LocaleController.currentName,
                        trailing: Icon(Icons.chevron_right_rounded,
                            color: Colors.grey.shade400),
                        onTap: _openLanguagePicker,
                      ),
                    ]),
                    const SizedBox(height: 18),
                    _sectionLabel(l.sectionAboutLegal),
                    _card([
                      _tile(
                        icon: Icons.privacy_tip_rounded,
                        accent: const Color(0xFF3B82F6),
                        title: l.privacyPolicy,
                        subtitle: l.privacyPolicySub,
                        trailing: Icon(Icons.chevron_right_rounded,
                            color: Colors.grey.shade400),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PrivacyPolicyScreen(),
                          ),
                        ),
                      ),
                      _divider(),
                      _tile(
                        icon: Icons.info_rounded,
                        accent: TeaTheme.mid,
                        title: l.aboutTeaOptima,
                        subtitle: l.versionLabel('1.0.0'),
                        trailing: Icon(Icons.chevron_right_rounded,
                            color: Colors.grey.shade400),
                        onTap: _openAbout,
                      ),
                    ]),
                    const SizedBox(height: 24),
                    _signOutButton(l),
                    const SizedBox(height: 16),
                    Text(
                      l.profileFooter,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 90),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header with overlapping avatar ────────────────────────────────────────
  Widget _header() {
    return SizedBox(
      height: 170,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // cover image with tea-green scrim
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(32)),
            child: SizedBox(
              height: 170,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // estate cover photo
                  Image.asset(
                    'assets/onboard8.jpg',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [TeaTheme.deep, TeaTheme.primary, TeaTheme.mid],
                        ),
                      ),
                    ),
                  ),
                  // tea-green tint keeps it on-theme + legible
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          TeaTheme.deep.withOpacity(0.82),
                          TeaTheme.primary.withOpacity(0.48),
                          TeaTheme.mid.withOpacity(0.62),
                        ],
                      ),
                    ),
                  ),
                  // gentle bottom darkening so the white avatar ring pops
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x00000000), Color(0x40000000)],
                      ),
                    ),
                  ),
                  Positioned(
                    right: -20,
                    top: -20,
                    child: Icon(Icons.eco_rounded,
                        size: 150, color: Colors.white.withOpacity(0.10)),
                  ),
                  SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.30)),
                            ),
                            child: const Text(
                              'MY PROFILE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // avatar overlapping bottom
          Positioned(
            bottom: -50,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: TeaTheme.bgTop,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: TeaTheme.primary.withOpacity(0.25),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor: Colors.white,
                  backgroundImage: _avatarUrl != null
                      ? NetworkImage(_avatarUrl!)
                      : const AssetImage('assets/login_bg.png')
                          as ImageProvider,
                  onBackgroundImageError: (_, __) {
                    if (mounted) setState(() => _avatarUrl = null);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Building blocks ───────────────────────────────────────────────────────
  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
            color: TeaTheme.deep.withOpacity(0.7),
          ),
        ),
      ),
    );
  }

  Widget _card(List<Widget> children) {
    return Container(
      decoration: TeaTheme.card(),
      child: Column(children: children),
    );
  }

  Widget _divider() => const Padding(
        padding: EdgeInsets.only(left: 60),
        child: Divider(height: 1, color: TeaTheme.border),
      );

  Widget _tile({
    required IconData icon,
    required Color accent,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: accent, size: 19),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: TeaTheme.deep,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing,
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _signOutButton(AppLocalizations l) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _signOut,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color: const Color(0xFFD9534F).withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFD9534F).withOpacity(0.25)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.logout_rounded,
                  color: Color(0xFFD9534F), size: 19),
              const SizedBox(width: 8),
              Text(
                l.signOut,
                style: const TextStyle(
                  color: Color(0xFFD9534F),
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
