import 'package:flutter/material.dart';

import 'package:mtc_app/core/utils/currency_formatter.dart';

class CurrencyText extends StatelessWidget {
  const CurrencyText(this.amountFcfa, {super.key, this.style});

  final int amountFcfa;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Text(CurrencyFormatter.formatFcfa(amountFcfa), style: style);
  }
}
