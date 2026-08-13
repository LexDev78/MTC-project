import 'package:flutter/material.dart';

import 'package:mtc_app/core/widgets/core_widgets.dart';

/// "Messages" tab of `SupplierShell` — the messaging lot adds
/// `ChatRepository.watchConversationsForSupplier` and reuses
/// `ChatThreadScreen` as-is (it's already agnostic of which side is
/// viewing).
class SupplierConversationListScreen extends StatelessWidget {
  const SupplierConversationListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: const MtcComingSoon(
        title: 'Messagerie — bientôt disponible',
        subtitle: 'Vos échanges avec les clients arriveront ici.',
      ),
    );
  }
}
