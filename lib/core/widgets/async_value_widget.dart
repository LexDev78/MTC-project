import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mtc_error_view.dart';
import 'mtc_loading_view.dart';

/// Renders an [AsyncValue] through the app's shared loading/error views, so
/// every feature's list/detail screen handles async state the same way.
class AsyncValueWidget<T> extends StatelessWidget {
  const AsyncValueWidget({
    super.key,
    required this.value,
    required this.data,
    this.loading,
    this.error,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final WidgetBuilder? loading;
  final Widget Function(Object error, StackTrace stackTrace)? error;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: data,
      loading: () => loading?.call(context) ?? const MtcLoadingView(),
      error: (err, stack) =>
          error?.call(err, stack) ?? MtcErrorView(message: err.toString()),
    );
  }
}
