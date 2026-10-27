import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/core/error/user_message.dart';
import 'package:mtc_app/core/shop/shop.dart';
import 'package:mtc_app/core/utils/validators.dart';

import '../controllers/auth_controller.dart';
import '../providers/auth_providers.dart';

/// L'écran de connexion, d'après les maquettes « Connexion » de la charte
/// MTC : le bandeau au logo, « Bon retour ! », les deux champs, « Se
/// souvenir de moi » et « Mot de passe oublié ? », puis le bouton en
/// dégradé et l'inscription.
///
/// Tous les rôles passent par lui — on ne sait pas encore qui se connecte.
/// Il prend le thème du côté client par `ShopScope` (`app_router.dart`).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  /// Où « Se souvenir de moi » garde l'identifiant, sur ce téléphone
  /// seulement. Jamais le mot de passe.
  static const cleIdentifiantRetenu = 'connexion.identifiant_retenu';

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _seSouvenir = false;

  @override
  void initState() {
    super.initState();
    final retenu = ref
        .read(sharedPreferencesProvider)
        .getString(LoginScreen.cleIdentifiantRetenu);
    if (retenu != null && retenu.isNotEmpty) {
      _usernameController.text = retenu;
      _seSouvenir = true;
    }
    // La coche de l'identifiant suit la saisie.
    _usernameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final identifiant = _usernameController.text.trim();
    // Read by `route_guards.dart` as soon as `currentUserProvider` resolves
    // below, so it must be set before `login()` — not after it returns —
    // to win the race against the router's own refresh.
    ref.read(justLoggedInProvider.notifier).state = true;
    final preferences = ref.read(sharedPreferencesProvider);
    final success = await ref
        .read(authControllerProvider.notifier)
        .login(
          usernameOrPhone: identifiant,
          password: _passwordController.text,
        );
    if (success) {
      // Retenu seulement une fois la connexion réussie : un identifiant mal
      // tapé ne doit pas revenir la fois suivante.
      if (_seSouvenir) {
        await preferences.setString(
          LoginScreen.cleIdentifiantRetenu,
          identifiant,
        );
      } else {
        await preferences.remove(LoginScreen.cleIdentifiantRetenu);
      }
      return;
    }
    if (!mounted) return;
    ref.read(justLoggedInProvider.notifier).state = false;
    final error = ref.read(authControllerProvider).error;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(messagePourUtilisateur(error))));
  }

  void _fillDemo(String usernameOrPhone) {
    _usernameController.text = usernameOrPhone;
    _passwordController.text = 'password123';
  }

  @override
  Widget build(BuildContext context) {
    final enCours = ref.watch(authControllerProvider).isLoading;
    final theme = Theme.of(context);
    final sombre = theme.brightness == Brightness.dark;
    final lien = sombre ? ShopColors.primaryLight : ShopColors.primary;
    final identifiantSaisi = _usernameController.text.trim().isNotEmpty;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // La barre d'état sur la toile, une fois le bandeau défilé.
      value: sombre ? _iconesClaires : _iconesFoncees,
      child: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MtcBrandBand(
                bandeau: MtcBandeau.connexion,
                // Venu de l'accueil, on peut y revenir ; après une
                // déconnexion, il n'y a rien derrière.
                onBack: Navigator.canPop(context)
                    ? () => Navigator.pop(context)
                    : null,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 17),
                    Text(
                      'Bon retour !',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 31,
                        fontWeight: FontWeight.w800,
                        // La hauteur de ligne de la police, explicite : sans
                        // elle, le texte hérite du 1,4 du thème.
                        height: 1.26,
                        letterSpacing: -1,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Connectez-vous avec l\'identifiant et le\n'
                      'mot de passe choisis à votre inscription.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 27),
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          _ChampCharte(
                            controller: _usernameController,
                            hint: "Nom d'utilisateur ou téléphone",
                            icon: ShopIcons.profile,
                            validator: Validators.usernameOrPhone,
                            textInputAction: TextInputAction.next,
                            suffix: identifiantSaisi
                                ? const ExcludeSemantics(
                                    child: Padding(
                                      padding: EdgeInsets.only(right: 4),
                                      child: SizedBox.square(
                                        dimension: 48,
                                        child: Center(
                                          child: ShopIcon(
                                            ShopIcons.singlecheck,
                                            size: 22,
                                            color: ShopColors.primary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(height: 14),
                          _ChampCharte(
                            controller: _passwordController,
                            hint: 'Mot de passe',
                            icon: ShopIcons.lock,
                            validator: Validators.password,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            onSubmitted: enCours ? null : (_) => _submit(),
                            suffix: Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: IconButton(
                                tooltip: _obscurePassword
                                    ? 'Afficher le mot de passe'
                                    : 'Masquer le mot de passe',
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                                icon: ShopIcon(
                                  ShopIcons.show,
                                  size: 22,
                                  color: _obscurePassword
                                      ? _couleurIcone(context)
                                      : lien,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Un `Wrap` : sur un écran étroit, le lien passe sous la
                    // case au lieu de déborder.
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _SeSouvenir(
                          valeur: _seSouvenir,
                          onChanged: (v) => setState(() => _seSouvenir = v),
                        ),
                        TextButton(
                          style: _styleLien(lien, gauche: 2, droite: 2),
                          // L'identifiant déjà tapé suit : on n'a pas à le
                          // redire.
                          onPressed: () => context.push(
                            AppRoutes.forgotPassword,
                            extra: _usernameController.text.trim(),
                          ),
                          child: const Text('Mot de passe oublié ?'),
                        ),
                      ],
                    ),
                    // Avec les 12 pt du bas de la ligne : 22 pt sous la case,
                    // comme sur la maquette.
                    const SizedBox(height: 10),
                    GradientButton(
                      label: 'Se connecter',
                      isLoading: enCours,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Pas encore de compte ?',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          TextButton(
                            style: _styleLien(lien, gauche: 6),
                            onPressed: () => context.push(AppRoutes.signUpRole),
                            child: const Text('Créer un compte'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: ShopSizes.padding),
                    _DemoAccounts(onSelect: _fillDemo),
                    const SizedBox(height: ShopSizes.padding),
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

/// Les liens des maquettes : 14 pt en gras, violets, sans la marge d'un
/// bouton (la cible du toucher garde 44 pt de haut).
ButtonStyle _styleLien(Color couleur, {double gauche = 0, double droite = 0}) =>
    TextButton.styleFrom(
      foregroundColor: couleur,
      padding: EdgeInsets.only(left: gauche, right: droite),
      minimumSize: const Size(0, 44),
      textStyle: const TextStyle(
        fontFamily: ShopTheme.fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    );

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

Color _couleurIcone(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? Colors.white.withValues(alpha: 0.4)
    : ShopColors.fieldIcon;

/// Un champ des maquettes : 56 pt, coins de 16, fond « Champs » de la
/// charte. Au focus, le fond blanchit, un contour violet et son halo
/// apparaissent.
class _ChampCharte extends StatefulWidget {
  const _ChampCharte({
    required this.controller,
    required this.hint,
    required this.icon,
    this.validator,
    this.obscureText = false,
    this.textInputAction,
    this.suffix,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final String icon;
  final String? Function(String?)? validator;
  final bool obscureText;
  final TextInputAction? textInputAction;
  final Widget? suffix;
  final ValueChanged<String>? onSubmitted;

  @override
  State<_ChampCharte> createState() => _ChampCharteState();
}

class _ChampCharteState extends State<_ChampCharte> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sombre = theme.brightness == Brightness.dark;
    const bordure = _BordureAvecHalo(
      borderRadius: BorderRadius.all(Radius.circular(16)),
      borderSide: BorderSide.none,
    );
    final texte = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w500,
      height: 1.26,
      color: theme.colorScheme.onSurface,
    );
    return TextFormField(
      controller: widget.controller,
      focusNode: _focus,
      validator: widget.validator,
      obscureText: widget.obscureText,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onSubmitted,
      style: texte,
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: texte.copyWith(color: theme.colorScheme.onSurfaceVariant),
        filled: true,
        fillColor: _focus.hasFocus
            ? theme.scaffoldBackgroundColor
            : (sombre ? ShopColors.darkGrey : ShopColors.lightGrey),
        contentPadding: const EdgeInsets.symmetric(vertical: 18),
        border: bordure,
        enabledBorder: bordure,
        focusedBorder: bordure.copyWith(
          borderSide: const BorderSide(color: ShopColors.primary, width: 1.5),
        ),
        errorBorder: bordure.copyWith(
          borderSide: const BorderSide(color: ShopColors.error, width: 1.5),
        ),
        focusedErrorBorder: bordure.copyWith(
          borderSide: const BorderSide(color: ShopColors.error, width: 1.5),
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 16, right: 13),
          // Violette quand le champ a le focus, comme sur la maquette.
          child: ShopIcon(
            widget.icon,
            size: 22,
            color: _focus.hasFocus
                ? (sombre ? ShopColors.primaryLight : ShopColors.primary)
                : _couleurIcone(context),
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 51),
        suffixIcon: widget.suffix,
      ),
    );
  }
}

/// Le contour d'un champ, avec le halo des maquettes autour quand il a une
/// couleur (au focus, ou en erreur) : 3,5 pt de la même couleur à 15 %, à
/// l'extérieur du contour.
class _BordureAvecHalo extends OutlineInputBorder {
  const _BordureAvecHalo({super.borderSide, super.borderRadius});

  @override
  _BordureAvecHalo copyWith({
    BorderSide? borderSide,
    BorderRadius? borderRadius,
    double? gapPadding,
  }) => _BordureAvecHalo(
    borderSide: borderSide ?? this.borderSide,
    borderRadius: borderRadius ?? this.borderRadius,
  );

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    double? gapStart,
    double gapExtent = 0.0,
    double gapPercentage = 0.0,
    TextDirection? textDirection,
  }) {
    if (borderSide.style != BorderStyle.none) {
      canvas.drawRRect(
        borderRadius.toRRect(rect).inflate(1.75),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..color = borderSide.color.withValues(alpha: 0.15),
      );
    }
    super.paint(
      canvas,
      rect,
      gapStart: gapStart,
      gapExtent: gapExtent,
      gapPercentage: gapPercentage,
      textDirection: textDirection,
    );
  }
}

/// « Se souvenir de moi » : un rond violet, plein une fois coché.
class _SeSouvenir extends StatelessWidget {
  const _SeSouvenir({required this.valeur, required this.onChanged});

  final bool valeur;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final couleur = theme.brightness == Brightness.dark
        ? ShopColors.primaryLight
        : ShopColors.primary;
    return MergeSemantics(
      child: Semantics(
        checked: valeur,
        child: InkWell(
          onTap: () => onChanged(!valeur),
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: ShopSizes.duration,
                  width: 20,
                  height: 20,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: couleur, width: 2),
                  ),
                  child: AnimatedScale(
                    duration: ShopSizes.duration,
                    scale: valeur ? 1 : 0,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: couleur,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                // Souple : en grands caractères, le libellé passe à la ligne
                // au lieu de déborder.
                Flexible(
                  child: Text(
                    'Se souvenir de moi',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
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
