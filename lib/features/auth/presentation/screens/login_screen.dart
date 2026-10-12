import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/theme/app_colors.dart';
import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/utils/validators.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';

import '../controllers/auth_controller.dart';
import '../providers/auth_providers.dart';
import '../widgets/watching_cat_avatar.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _obscurePassword = true;
  bool _isPasswordFocused = false;
  bool _isUsernameFocused = false;
  bool _loginFailed = false;
  double _gazeOffset = 0;

  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  )..forward();
  late final Animation<double> _fade = CurvedAnimation(
    parent: _entrance,
    curve: Curves.easeOut,
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.06),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    _passwordFocus.addListener(() {
      setState(() {
        _isPasswordFocused = _passwordFocus.hasFocus;
        if (_isPasswordFocused) _loginFailed = false;
      });
    });
    _usernameFocus.addListener(() {
      setState(() {
        _isUsernameFocused = _usernameFocus.hasFocus;
        if (_isUsernameFocused) _loginFailed = false;
      });
    });
    _usernameController.addListener(() {
      // The cat's gaze "follows" the length of the typed text, roughly
      // like a cursor sweeping left to right.
      final progress = (_usernameController.text.length / 24).clamp(0.0, 1.0);
      setState(() {
        _gazeOffset = (progress * 2) - 1;
        _loginFailed = false;
      });
    });
    _passwordController.addListener(() {
      if (_loginFailed) setState(() => _loginFailed = false);
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    _entrance.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    // Read by `route_guards.dart` as soon as `currentUserProvider` resolves
    // below, so it must be set before `login()` — not after it returns —
    // to win the race against the router's own refresh.
    ref.read(justLoggedInProvider.notifier).state = true;
    final success = await ref
        .read(authControllerProvider.notifier)
        .login(
          usernameOrPhone: _usernameController.text.trim(),
          password: _passwordController.text,
        );
    if (!success && mounted) {
      ref.read(justLoggedInProvider.notifier).state = false;
      final error = ref.read(authControllerProvider).error;
      setState(() => _loginFailed = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error?.toString() ?? 'Une erreur est survenue')),
      );
    }
  }

  void _fillDemo(String usernameOrPhone) {
    _usernameController.text = usernameOrPhone;
    _passwordController.text = 'password123';
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppColors.loginCanvasDark
          : AppColors.loginCanvasLight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.lg),
                    Center(
                      child: WatchingCatAvatar(
                        // Eyes stay shut both while the password field has
                        // focus and whenever the password is left visible
                        // on screen (the cat won't peek at it either way).
                        isPasswordFocused: _isPasswordFocused || !_obscurePassword,
                        gazeOffset: _gazeOffset,
                        isTyping: _isUsernameFocused,
                        hasError: _loginFailed,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Text(
                      'MTC',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'Mali Trade Connect',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Connectez-vous pour continuer',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    MtcTextField(
                      label: "Nom d'utilisateur ou téléphone",
                      controller: _usernameController,
                      focusNode: _usernameFocus,
                      prefixIcon: Icons.person_outline_rounded,
                      validator: Validators.usernameOrPhone,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    MtcTextField(
                      label: 'Mot de passe',
                      controller: _passwordController,
                      focusNode: _passwordFocus,
                      prefixIcon: Icons.lock_outline_rounded,
                      obscureText: _obscurePassword,
                      validator: Validators.password,
                      textInputAction: TextInputAction.done,
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                        child: Text(_obscurePassword ? 'Afficher' : 'Masquer'),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    MtcPrimaryButton(
                      label: 'Se connecter',
                      isLoading: authState.isLoading,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Center(
                      child: TextButton(
                        onPressed: () => context.push(AppRoutes.signUpRole),
                        child: const Text('Créer un compte'),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _DemoAccounts(onSelect: _fillDemo),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DemoAccounts extends StatelessWidget {
  const _DemoAccounts({required this.onSelect});

  final void Function(String usernameOrPhone) onSelect;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: const Text('Comptes de démonstration'),
      childrenPadding: const EdgeInsets.only(bottom: AppSpacing.md),
      children: [
        _DemoAccountTile(
          label: 'Client — Awa Traoré',
          username: 'client1',
          onSelect: onSelect,
        ),
        _DemoAccountTile(
          label: 'Client — Moussa Diarra',
          username: 'client2',
          onSelect: onSelect,
        ),
        _DemoAccountTile(
          label: 'Fournisseur tiers (vérifié)',
          username: 'fournisseur1',
          onSelect: onSelect,
        ),
        _DemoAccountTile(
          label: 'Fournisseur tiers (en attente)',
          username: 'fournisseur2',
          onSelect: onSelect,
        ),
        _DemoAccountTile(
          label: 'MTC — Agent',
          username: 'agent1',
          onSelect: onSelect,
        ),
        _DemoAccountTile(
          label: 'MTC — Admin',
          username: 'admin1',
          onSelect: onSelect,
        ),
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text(
            'Mot de passe : password123',
            style: TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _DemoAccountTile extends StatelessWidget {
  const _DemoAccountTile({
    required this.label,
    required this.username,
    required this.onSelect,
  });

  final String label;
  final String username;
  final void Function(String usernameOrPhone) onSelect;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(username),
      trailing: const Icon(Icons.chevron_right_rounded, size: 18),
      onTap: () => onSelect(username),
    );
  }
}
