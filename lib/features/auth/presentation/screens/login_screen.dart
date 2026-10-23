import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/core/error/user_message.dart';
import 'package:mtc_app/core/shop/shop.dart';
import 'package:mtc_app/core/utils/validators.dart';

import '../controllers/auth_controller.dart';
import '../providers/auth_providers.dart';

/// L'écran de connexion, repris de celui du kit FlutterShop
/// (`E-commerce-Complete-Flutter-UI/lib/screens/auth/views/login_screen.dart`) :
/// la photo du kit en tête, « Bon retour ! », les deux champs à icône,
/// « Mot de passe oublié ? », puis le bouton et l'inscription.
///
/// Tous les rôles passent par lui — on ne sait pas encore qui se connecte.
/// Il prend le thème du kit par `ShopScope` (`app_router.dart`), comme la
/// récupération du mot de passe qu'il ouvre.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(messagePourUtilisateur(error))));
    }
  }

  void _fillDemo(String usernameOrPhone) {
    _usernameController.text = usernameOrPhone;
    _passwordController.text = 'password123';
  }

  @override
  Widget build(BuildContext context) {
    final enCours = ref.watch(authControllerProvider).isLoading;
    final theme = Theme.of(context);
    final hauteur = MediaQuery.sizeOf(context).height;
    final sombre = theme.brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // La barre d'état sur la toile, une fois la photo défilée : icônes
      // claires en sombre, foncées en clair.
      value: sombre ? _iconesClaires : _iconesFoncees,
      child: Scaffold(
        // Pas de `SafeArea`, comme dans le kit : la photo passe sous la
        // barre d'état.
        body: SingleChildScrollView(
          child: Column(
            children: [
              const _PhotoDeConnexion(),
              Padding(
                padding: const EdgeInsets.all(ShopSizes.padding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bon retour !', style: theme.textTheme.headlineSmall),
                    const SizedBox(height: ShopSizes.padding / 2),
                    const Text(
                      'Connectez-vous avec l\'identifiant et le mot de passe '
                      'choisis à votre inscription.',
                    ),
                    const SizedBox(height: ShopSizes.padding),
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _usernameController,
                            validator: Validators.usernameOrPhone,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              hintText: "Nom d'utilisateur ou téléphone",
                              prefixIcon: ShopFieldIcon(ShopIcons.profile),
                            ),
                          ),
                          const SizedBox(height: ShopSizes.padding),
                          TextFormField(
                            controller: _passwordController,
                            validator: Validators.password,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            decoration: InputDecoration(
                              hintText: 'Mot de passe',
                              prefixIcon: const ShopFieldIcon(ShopIcons.lock),
                              // Absent du kit, mais sur un clavier de
                              // téléphone, un mot de passe qu'on ne peut pas
                              // relire se tape trois fois.
                              suffixIcon: IconButton(
                                tooltip: _obscurePassword
                                    ? 'Afficher le mot de passe'
                                    : 'Masquer le mot de passe',
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                                icon: ShopIcon(
                                  ShopIcons.show,
                                  size: 20,
                                  color: _obscurePassword
                                      ? theme.iconTheme.color?.withValues(
                                          alpha: 0.3,
                                        )
                                      : ShopColors.primary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Align(
                      child: TextButton(
                        // L'identifiant déjà tapé suit : on n'a pas à le
                        // redire.
                        onPressed: () => context.push(
                          AppRoutes.forgotPassword,
                          extra: _usernameController.text.trim(),
                        ),
                        child: const Text('Mot de passe oublié ?'),
                      ),
                    ),
                    SizedBox(
                      height: hauteur > 700 ? hauteur * 0.1 : ShopSizes.padding,
                    ),
                    ElevatedButton(
                      onPressed: enCours ? null : _submit,
                      child: enCours
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Se connecter'),
                    ),
                    // Un `Wrap` plutôt que la `Row` du kit : sur un petit
                    // écran ou en grands caractères, le lien passe à la
                    // ligne au lieu de déborder.
                    Center(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text('Pas encore de compte ?'),
                          TextButton(
                            onPressed: () => context.push(AppRoutes.signUpRole),
                            child: const Text('Créer un compte'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: ShopSizes.padding),
                    _DemoAccounts(onSelect: _fillDemo),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Les icônes de la barre d'état, sans toucher au reste (barre de
/// navigation d'Android comprise) : `SystemUiOverlayStyle.dark` la
/// peindrait en noir.
const _iconesFoncees = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
);
const _iconesClaires = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
);

/// La photo du kit et sa vague. Chaque version a la vague de la toile de
/// son thème (blanc en clair, `ShopColors.black` en sombre) : jamais l'une
/// pour l'autre, la vague resterait visible.
class _PhotoDeConnexion extends StatelessWidget {
  const _PhotoDeConnexion();

  @override
  Widget build(BuildContext context) {
    final sombre = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Le fond rose de la photo, dans les deux modes : icônes foncées.
      value: _iconesFoncees,
      // Le format du fichier (750 × 598), tenu avant son décodage : le
      // formulaire ne saute pas quand la photo arrive.
      child: AspectRatio(
        aspectRatio: 750 / 598,
        child: Image.asset(
          'assets/shop/images/login_${sombre ? 'dark' : 'light'}.png',
          fit: BoxFit.cover,
          excludeFromSemantics: true,
        ),
      ),
    );
  }
}

/// Les comptes de la base de démonstration : un toucher remplit les deux
/// champs.
class _DemoAccounts extends StatefulWidget {
  const _DemoAccounts({required this.onSelect});

  final void Function(String usernameOrPhone) onSelect;

  @override
  State<_DemoAccounts> createState() => _DemoAccountsState();
}

class _DemoAccountsState extends State<_DemoAccounts> {
  static const _comptes = [
    ('Client — Awa Traoré', 'client1'),
    ('Client — Moussa Diarra', 'client2'),
    ('Fournisseur tiers (vérifié)', 'fournisseur1'),
    ('Fournisseur tiers (en attente)', 'fournisseur2'),
    ('MTC — Agent', 'agent1'),
    ('MTC — Admin', 'admin1'),
  ];

  bool _ouvert = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      shape: const Border(),
      collapsedShape: const Border(),
      title: const Text('Comptes de démonstration'),
      // Le chevron du kit, qui pivote comme celui de Material.
      trailing: AnimatedRotation(
        turns: _ouvert ? 0.5 : 0,
        duration: ShopSizes.duration,
        child: ShopIcon(
          ShopIcons.miniDown,
          color: theme.iconTheme.color?.withValues(alpha: 0.4),
        ),
      ),
      onExpansionChanged: (ouvert) => setState(() => _ouvert = ouvert),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      childrenPadding: const EdgeInsets.only(bottom: ShopSizes.padding),
      children: [
        for (final (libelle, identifiant) in _comptes)
          ChevronListTile(
            title: libelle,
            trailingText: identifiant,
            contentPadding: EdgeInsets.zero,
            onTap: () => widget.onSelect(identifiant),
          ),
        const SizedBox(height: ShopSizes.padding / 2),
        Text('Mot de passe : password123', style: theme.textTheme.bodySmall),
      ],
    );
  }
}
