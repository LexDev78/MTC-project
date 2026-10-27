import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/core/error/exceptions.dart';
import 'package:mtc_app/core/error/user_message.dart';
import 'package:mtc_app/core/shop/shop.dart';
import 'package:mtc_app/core/utils/validators.dart';

import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

/// Modifier son profil, d'après la maquette « Edit profile » du kit : la
/// photo, le nom, l'adresse e-mail, le téléphone et la date de naissance.
///
/// Rien ne part avant « Enregistrer », photo comprise : quitter l'écran
/// abandonne tout. Chaque champ a sa fonction en base (`0116`, `0109`,
/// `0121`) ; le premier refus s'affiche sous son champ et arrête là.
class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _formulaire = GlobalKey<FormState>();
  final _nom = TextEditingController();
  final _telephone = TextEditingController();
  final _naissance = TextEditingController();

  /// Le compte enregistré, une fois lu : les champs partent de lui, et
  /// « inchangé » se mesure par rapport à lui.
  bool _compteLu = false;

  /// Faux pendant `initState` : un `setState` n'y est pas permis.
  bool _pret = false;

  /// La photo choisie mais pas encore envoyée, et son aperçu ; ou le retrait
  /// demandé de la photo actuelle.
  XFile? _photo;
  Uint8List? _apercu;
  bool _retirerPhoto = false;

  bool _envoi = false;
  String? _erreurNom;
  String? _erreurTelephone;
  String? _erreurNaissance;
  String? _erreurPhoto;

  @override
  void initState() {
    super.initState();
    // Les champs se remplissent dès que le compte est lu — tout de suite
    // s'il l'est déjà, plus tard sinon. Une fois : ce que l'utilisateur tape
    // ne doit plus être écrasé.
    ref.listenManual(currentUserProvider, (_, suivant) {
      final user = suivant.valueOrNull;
      if (_compteLu || user == null) return;
      _compteLu = true;
      _nom.text = user.displayName;
      _telephone.text = user.phoneNumber;
      if (user case ClientUser(:final birthDate?)) {
        _naissance.text = _jjmmaaaa(birthDate);
      }
      if (_pret) setState(() {});
    }, fireImmediately: true);
    _nom.addListener(() => setState(() => _erreurNom = null));
    _telephone.addListener(() {
      if (_erreurTelephone != null) setState(() => _erreurTelephone = null);
    });
    // Aussi pour la croix d'effacement, qui suit le champ.
    _naissance.addListener(() => setState(() => _erreurNaissance = null));
    _pret = true;
  }

  @override
  void dispose() {
    _nom.dispose();
    _telephone.dispose();
    _naissance.dispose();
    super.dispose();
  }

  void _expliquer() {
    final identifiant = ref
        .read(currentUserProvider)
        .valueOrNull
        ?.usernameOrPhone;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Qui voit vos informations ?'),
        content: SingleChildScrollView(
          child: Text(
            'Votre nom figure sur vos prochaines commandes, vos avis et vos '
            'nouvelles conversations. Ce qui est déjà passé garde le nom '
            'd\'alors : une boutique doit pouvoir relire une commande telle '
            'qu\'elle a été faite.\n\n'
            'Votre numéro n\'est montré qu\'à celui qui vous livre — le '
            'livreur, ou la boutique quand elle livre elle-même — et '
            'seulement jusqu\'à la livraison. Vos commandes en cours suivent '
            'un changement de numéro.\n\n'
            'Votre photo et votre date de naissance ne sont visibles que de '
            'vous.'
            '${identifiant == null ? '' : '\n\nVous vous connectez avec « $identifiant » : changer de numéro n\'y touche pas.'}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Compris'),
          ),
        ],
      ),
    );
  }

  /// La photo, dans une feuille du kit : en choisir une, en prendre une, ou
  /// retirer celle qu'on a.
  Future<void> _changerPhoto() async {
    final user = ref.read(currentUserProvider).valueOrNull;
    final aUnePhoto =
        _apercu != null ||
        (!_retirerPhoto && user is ClientUser && user.avatarPath != null);
    final choix = await showShopSheet<_Photo>(
      context,
      heightFactor: aUnePhoto ? 0.45 : 0.35,
      child: Scaffold(
        body: Column(
          children: [
            const SheetHeader(title: 'Photo de profil'),
            Builder(
              builder: (context) => Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: ShopSizes.padding,
                ),
                child: Column(
                  children: [
                    ChevronListTile(
                      icon: ShopIcons.image,
                      title: 'Choisir une photo',
                      onTap: () => Navigator.of(context).pop(_Photo.galerie),
                    ),
                    ChevronListTile(
                      icon: ShopIcons.cameraAdd,
                      title: 'Prendre une photo',
                      showDivider: aUnePhoto,
                      onTap: () => Navigator.of(context).pop(_Photo.camera),
                    ),
                    if (aUnePhoto)
                      ChevronListTile(
                        icon: ShopIcons.delete,
                        title: 'Retirer la photo',
                        danger: true,
                        showDivider: false,
                        onTap: () => Navigator.of(context).pop(_Photo.retirer),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (!mounted || choix == null) return;

    if (choix == _Photo.retirer) {
      setState(() {
        _photo = null;
        _apercu = null;
        _retirerPhoto = true;
        _erreurPhoto = null;
      });
      return;
    }

    try {
      final photo = await ImagePicker().pickImage(
        source: choix == _Photo.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        // Une vignette ronde : inutile d'envoyer plus sur un réseau lent.
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (photo == null) return;
      final octets = await photo.readAsBytes();
      if (!mounted) return;
      setState(() {
        _photo = photo;
        _apercu = octets;
        _retirerPhoto = false;
        _erreurPhoto = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _erreurPhoto =
            'La photo n\'a pas pu être ouverte. Vérifiez l\'autorisation '
            'd\'accès aux photos dans les réglages du téléphone.',
      );
    }
  }

  Future<void> _enregistrer() async {
    if (!_formulaire.currentState!.validate()) return;
    final messager = ScaffoldMessenger.of(context);
    final routeur = GoRouter.of(context);
    final depot = ref.read(authRepositoryProvider);
    final user = ref.read(currentUserProvider).valueOrNull;
    final client = user is ClientUser ? user : null;

    final nom = _nom.text.trim();
    final telephone = _telephone.text.trim();
    final telephoneChange =
        _huitChiffres(telephone) != _huitChiffres(user?.phoneNumber ?? '');
    final naissance = _lireDate(_naissance.text.trim());
    final naissanceChange = !_memeJour(naissance, client?.birthDate);
    final photoChange = _photo != null || _retirerPhoto;

    setState(() => _envoi = true);
    try {
      if (nom != user?.displayName) {
        try {
          await depot.setDisplayName(nom);
        } on ValidationException catch (e) {
          setState(() => _erreurNom = e.message);
          return;
        }
      }
      if (telephoneChange) {
        try {
          await depot.setPhoneNumber(telephone);
        } on ValidationException catch (e) {
          setState(() => _erreurTelephone = e.message);
          return;
        }
      }
      if (naissanceChange) {
        try {
          await depot.setBirthDate(naissance);
        } on ValidationException catch (e) {
          setState(() => _erreurNaissance = e.message);
          return;
        }
      }
      if (photoChange) {
        try {
          await depot.setAvatar(
            _retirerPhoto ? null : _photo,
            previousPath: client?.avatarPath,
          );
        } on ValidationException catch (e) {
          setState(() => _erreurPhoto = e.message);
          return;
        }
      }
      messager.showSnackBar(
        const SnackBar(content: Text('Votre profil est enregistré.')),
      );
      // Ouvert depuis « Mes informations », on y revient ; ouvert seul (un
      // lien), il n'y a rien dessous à retrouver.
      if (routeur.canPop()) {
        routeur.pop();
      } else {
        routeur.go(AppRoutes.clientProfileInfo);
      }
    } catch (erreur) {
      messager.showSnackBar(
        SnackBar(
          content: Text(
            messagePourUtilisateur(
              erreur,
              repli: 'Votre profil n\'a pas pu être enregistré.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider).valueOrNull;
    final photoActuelle = _retirerPhoto
        ? null
        : switch (user) {
            ClientUser(:final avatarPath) => avatarPath,
            _ => null,
          };
    final apercu = _apercu;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifier le profil'),
        actions: [
          IconButton(
            tooltip: 'Qui voit vos informations ?',
            onPressed: _expliquer,
            icon: const ShopIcon(ShopIcons.info),
          ),
          const SizedBox(width: ShopSizes.padding / 2),
        ],
      ),
      body: Form(
        key: _formulaire,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            ShopSizes.screenMargin,
            ShopSizes.padding,
            ShopSizes.screenMargin,
            ShopSizes.screenMargin,
          ),
          children: [
            Center(
              child: Semantics(
                button: true,
                label: 'Changer la photo de profil',
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: _envoi ? null : _changerPhoto,
                  child: Stack(
                    children: [
                      ShopAvatar(
                        name: _nom.text,
                        imagePath: photoActuelle,
                        preview: apercu == null ? null : MemoryImage(apercu),
                        radius: 56,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: ShopColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.scaffoldBackgroundColor,
                              width: 2,
                            ),
                          ),
                          child: const ShopIcon(
                            ShopIcons.cameraBold,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_erreurPhoto case final erreur?) ...[
              const SizedBox(height: ShopSizes.padding / 2),
              Text(
                erreur,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: ShopSizes.padding * 2),
            TextFormField(
              controller: _nom,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              maxLength: 60,
              validator: (v) => (v ?? '').trim().length < 2
                  ? 'Votre nom doit compter au moins 2 caractères.'
                  : null,
              decoration: InputDecoration(
                labelText: 'Nom',
                prefixIcon: const ShopFieldIcon(ShopIcons.profile),
                errorText: _erreurNom,
                // La limite tient sans compteur, comme dans le kit.
                counterText: '',
              ),
            ),
            const SizedBox(height: ShopSizes.padding / 2),
            // L'adresse se change sur son propre écran : elle se vérifie par
            // un code envoyé à la boîte (`0124`), ce qu'un formulaire
            // enregistré d'un seul geste ne peut pas porter.
            _ChampEmail(
              etat: ref.watch(contactEmailStatusProvider).valueOrNull,
              onTap: _envoi
                  ? null
                  : () => context.push(AppRoutes.accountEmail),
            ),
            const SizedBox(height: ShopSizes.padding),
            TextFormField(
              controller: _telephone,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              validator: Validators.phone,
              decoration: InputDecoration(
                labelText: 'Téléphone',
                prefixIcon: const ShopFieldIcon(ShopIcons.call),
                errorText: _erreurTelephone,
                helperText:
                    'Montré seulement à qui vous livre, le temps de la '
                    'livraison.',
                helperMaxLines: 2,
              ),
            ),
            const SizedBox(height: ShopSizes.padding),
            TextFormField(
              controller: _naissance,
              keyboardType: TextInputType.number,
              inputFormatters: [_SaisieDate()],
              validator: (v) => _erreurDate((v ?? '').trim()),
              decoration: InputDecoration(
                labelText: 'Date de naissance (facultative)',
                hintText: 'jj/mm/aaaa',
                prefixIcon: const ShopFieldIcon(ShopIcons.calender),
                errorText: _erreurNaissance,
                suffixIcon: _naissance.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Effacer la date',
                        onPressed: _naissance.clear,
                        icon: const ShopIcon(ShopIcons.closeCircle, size: 20),
                      ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomActionBar(
        label: 'Enregistrer',
        isLoading: _envoi,
        onPressed: _envoi ? null : _enregistrer,
      ),
    );
  }
}

enum _Photo { galerie, camera, retirer }

/// L'adresse e-mail dans le formulaire : affichée comme les autres champs,
/// elle s'ouvre sur l'écran où elle se vérifie.
class _ChampEmail extends StatelessWidget {
  const _ChampEmail({required this.etat, required this.onTap});

  final ({String? email, bool verified})? etat;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final email = etat?.email;
    final aide = switch (etat) {
      null => null,
      (email: null, verified: _) =>
        'Un code vous sera envoyé pour la vérifier.',
      (email: _, verified: true) => 'Vérifiée.',
      (email: _, verified: false) =>
        'Jamais vérifiée : touchez pour la vérifier.',
    };
    return Semantics(
      button: true,
      label: email == null
          ? 'Ajouter une adresse e-mail'
          : 'Adresse e-mail : $email. Changer',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ShopSizes.radius),
        child: InputDecorator(
          isEmpty: email == null,
          decoration: InputDecoration(
            labelText: email == null
                ? 'Ajouter une adresse e-mail'
                : 'Adresse e-mail (facultative)',
            prefixIcon: const ShopFieldIcon(ShopIcons.message),
            suffixIcon: const ShopFieldIcon(ShopIcons.miniRight),
            helperText: aide,
            helperMaxLines: 2,
            helperStyle: etat?.verified == false && email != null
                ? theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  )
                : null,
          ),
          child: Text(email ?? '', style: theme.textTheme.bodyLarge),
        ),
      ),
    );
  }
}

/// « 12/03/1995 » : la forme qu'on lit et qu'on tape ici.
String _jjmmaaaa(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/'
    '${date.year.toString().padLeft(4, '0')}';

/// La date tapée, ou `null` si le champ est vide ou la date impossible
/// (le 31/02 n'existe pas : `DateTime` le décalerait au 3 mars sans rien
/// dire).
DateTime? _lireDate(String texte) {
  final m = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(texte);
  if (m == null) return null;
  final jour = int.parse(m.group(1)!);
  final mois = int.parse(m.group(2)!);
  final annee = int.parse(m.group(3)!);
  final date = DateTime(annee, mois, jour);
  if (date.year != annee || date.month != mois || date.day != jour) {
    return null;
  }
  return date;
}

/// Les mêmes bornes que `set_my_birth_date` (`0121`), dites avant l'envoi.
String? _erreurDate(String texte) {
  if (texte.isEmpty) return null;
  final date = _lireDate(texte);
  if (date == null) {
    return 'Date invalide : jj/mm/aaaa, par exemple 12/03/1995.';
  }
  final maintenant = DateTime.now();
  final aujourdhui = DateTime(
    maintenant.year,
    maintenant.month,
    maintenant.day,
  );
  if (date.isAfter(aujourdhui)) {
    return 'La date de naissance ne peut pas être dans le futur.';
  }
  if (date.isBefore(DateTime(1900))) {
    return 'La date de naissance doit être postérieure au 1er janvier 1900.';
  }
  return null;
}

bool _memeJour(DateTime? a, DateTime? b) => a == null || b == null
    ? a == b
    : a.year == b.year && a.month == b.month && a.day == b.day;

/// Les huit chiffres d'un numéro malien, quelle que soit sa forme : « 70 12
/// 34 56 » et « +22370123456 » sont le même numéro.
String _huitChiffres(String numero) {
  final chiffres = numero.replaceAll(RegExp(r'\D'), '');
  return chiffres.length > 8
      ? chiffres.substring(chiffres.length - 8)
      : chiffres;
}

/// Glisse les barres de « jj/mm/aaaa » pendant la frappe : on ne tape que
/// des chiffres, huit au plus.
class _SaisieDate extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue ancien,
    TextEditingValue nouveau,
  ) {
    var chiffres = nouveau.text.replaceAll(RegExp(r'\D'), '');
    if (chiffres.length > 8) chiffres = chiffres.substring(0, 8);
    final texte = StringBuffer();
    for (var i = 0; i < chiffres.length; i++) {
      if (i == 2 || i == 4) texte.write('/');
      texte.write(chiffres[i]);
    }
    final resultat = texte.toString();
    return TextEditingValue(
      text: resultat,
      selection: TextSelection.collapsed(offset: resultat.length),
    );
  }
}
