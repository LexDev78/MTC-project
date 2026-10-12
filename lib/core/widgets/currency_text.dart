import 'package:flutter/material.dart';

import 'package:mtc_app/core/utils/currency_formatter.dart';

class CurrencyText extends StatelessWidget {
  const CurrencyText(this.amountFcfa, {super.key, this.style, this.compareAtAmountFcfa});

  final int amountFcfa;
  final TextStyle? style;

  /// The product's pre-discount price — shown struck through just before
  /// [amountFcfa] when set and actually higher than it. `null`/lower is a
  /// silent no-op rather than an error, so callers can pass
  /// `product.compareAtPriceFcfa` straight through unconditionally.
  final int? compareAtAmountFcfa;

  @override
  Widget build(BuildContext context) {
    final current = Text(CurrencyFormatter.formatFcfa(amountFcfa), style: style);
    final compareAt = compareAtAmountFcfa;
    if (compareAt == null || compareAt <= amountFcfa) return current;

    final baseStyle = style ?? DefaultTextStyle.of(context).style;
    // `Wrap` rather than `Row` — this sits on narrow catalog grid cards, so
    // the struck-through price needs to be free to drop to its own line
    // instead of overflowing when both amounts don't fit side by side.
    return Wrap(
      spacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          CurrencyFormatter.formatFcfa(compareAt),
          style: baseStyle.copyWith(
            decoration: TextDecoration.lineThrough,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.normal,
            fontSize: (baseStyle.fontSize ?? 14) * 0.8,
          ),
        ),
        current,
      ],
    );
  }
}
