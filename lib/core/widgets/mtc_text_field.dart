import 'package:flutter/material.dart';

class MtcTextField extends StatefulWidget {
  const MtcTextField({
    super.key,
    required this.label,
    this.controller,
    this.focusNode,
    this.obscureText = false,
    this.revealable = false,
    this.keyboardType,
    this.validator,
    this.prefixIcon,
    this.textInputAction,
    this.onChanged,
    this.autofillHints,
    this.maxLines = 1,
    this.enabled = true,
  });

  final String label;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final bool obscureText;

  /// Ajoute un œil qui affiche ou masque la saisie d'un champ [obscureText].
  ///
  /// Facultatif, mais conseillé pour tout mot de passe : sur un clavier de
  /// téléphone, un mot de passe qu'on ne peut pas relire est un mot de passe
  /// qu'on tape trois fois. (L'écran de connexion, au kit, a son propre œil.)
  final bool revealable;

  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final IconData? prefixIcon;
  final TextInputAction? textInputAction;
  final void Function(String)? onChanged;
  final Iterable<String>? autofillHints;
  final int maxLines;

  /// Un champ grisé, qui garde sa valeur mais refuse la saisie. Sert aux
  /// valeurs qu'on montre sans permettre de les changer — le texte d'un code
  /// promo déjà distribué, par exemple.
  final bool enabled;

  @override
  State<MtcTextField> createState() => _MtcTextFieldState();
}

class _MtcTextFieldState extends State<MtcTextField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    final masque = widget.obscureText && !_visible;
    final avecOeil = widget.obscureText && widget.revealable;

    return TextFormField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      obscureText: masque,
      keyboardType: widget.keyboardType,
      validator: widget.validator,
      textInputAction: widget.textInputAction,
      onChanged: widget.onChanged,
      autofillHints: widget.autofillHints,
      maxLines: widget.maxLines,
      enabled: widget.enabled,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: widget.prefixIcon != null ? Icon(widget.prefixIcon) : null,
        suffixIcon: avecOeil
            ? IconButton(
                tooltip: _visible ? 'Masquer' : 'Afficher',
                icon: Icon(
                  _visible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                onPressed: () => setState(() => _visible = !_visible),
              )
            : null,
      ),
    );
  }
}
