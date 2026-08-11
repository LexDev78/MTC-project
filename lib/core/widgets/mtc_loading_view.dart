import 'package:flutter/material.dart';

class MtcLoadingView extends StatelessWidget {
  const MtcLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}
