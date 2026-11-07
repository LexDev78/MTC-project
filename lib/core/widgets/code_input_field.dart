import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Un code de [length] chiffres, case par case, comme l'écran « Verification
/// code » du kit.
///
/// Un seul champ de saisie, invisible, couvre les cases : c'est lui qui
/// porte le clavier, le collage d'un code copié et la saisie automatique du
/// téléphone (`oneTimeCode`). Les cases ne font que montrer ce qu'il
/// contient. Six champs d'un chiffre chacun obligeraient à promener le focus
/// de l'un à l'autre — et un collage n'en remplirait qu'un.
class CodeInputField extends StatefulWidget {
  const CodeInputField({
    super.key,
    required this.controller,
    this.length = 6,
    this.onCompleted,
    this.hasError = false,
    this.enabled = true,
    this.autofocus = true,
  });

  final TextEditingController controller;
  final int length;

  /// Appelé quand la dernière case est remplie.
  final ValueChanged<String>? onCompleted;

  /// Cases bordées de rouge : le code vient d'être refusé.
  final bool hasError;
  final bool enabled;
  final bool autofocus;

  @override
  State<CodeInputField> createState() => _CodeInputFieldState();
}

class _CodeInputFieldState extends State<CodeInputField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_suivre);
    _focus.addListener(_suivre);
  }

  @override
  void didUpdateWidget(CodeInputField ancien) {
    super.didUpdateWidget(ancien);
    if (ancien.controller != widget.controller) {
      ancien.controller.removeListener(_suivre);
      widget.controller.addListener(_suivre);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_suivre);
    _focus.dispose();
    super.dispose();
  }

  void _suivre() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final texte = widget.controller.text;
    final fond =
        theme.inputDecorationTheme.fillColor ?? scheme.surfaceContainerHighest;

    return Semantics(
      label: 'Code de vérification à ${widget.length} chiffres',
      value: texte.isEmpty ? null : texte.split('').join(' '),
      child: LayoutBuilder(
        builder: (context, contraintes) {
          const ecart = 8.0;
          final largeur =
              ((contraintes.maxWidth - ecart * (widget.length - 1)) /
                      widget.length)
                  .clamp(36.0, 56.0);
          return SizedBox(
            height: largeur * 1.2,
            child: Stack(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < widget.length; i++) ...[
                      if (i > 0) const SizedBox(width: ecart),
                      _Case(
                        chiffre: i < texte.length ? texte[i] : null,
                        largeur: largeur,
                        fond: fond,
                        // La case où ira le prochain chiffre.
                        active:
                            _focus.hasFocus &&
                            (i == texte.length ||
                                (texte.length == widget.length &&
                                    i == widget.length - 1)),
                        erreur: widget.hasError,
                      ),
                    ],
                  ],
                ),
                Positioned.fill(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focus,
                    enabled: widget.enabled,
                    autofocus: widget.autofocus,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(widget.length),
                    ],
                    onChanged: (valeur) {
                      if (valeur.length == widget.length) {
                        widget.onCompleted?.call(valeur);
                      }
                    },
                    // Invisible : les cases montrent la saisie.
                    showCursor: false,
                    enableInteractiveSelection: false,
                    cursorColor: Colors.transparent,
                    style: const TextStyle(color: Colors.transparent),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      filled: false,
                      counterText: '',
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Case extends StatelessWidget {
  const _Case({
    required this.chiffre,
    required this.largeur,
    required this.fond,
    required this.active,
    required this.erreur,
  });

  final String? chiffre;
  final double largeur;
  final Color fond;
  final bool active;
  final bool erreur;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bord = erreur
        ? scheme.error
        : active
        ? scheme.primary
        : Colors.transparent;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: largeur,
      height: largeur * 1.2,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fond,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: bord, width: 1.5),
      ),
      child: Text(
        chiffre ?? '',
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
    );
  }
}
