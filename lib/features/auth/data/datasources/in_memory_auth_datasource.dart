import 'dart:async';

import 'package:mtc_app/core/error/exceptions.dart';
import 'package:mtc_app/core/mock_data/demo_ids.dart';

import '../../domain/entities/app_user.dart';
import '../../domain/entities/user_role.dart';

/// In-memory "record" of an account: the [AppUser] plus its mock password.
class _AuthRecord {
  _AuthRecord(this.user, this.password);

  AppUser user;
  final String password;
}

/// Holds every seeded/created account and the current session, in memory.
/// Swapping to Firebase Auth later means replacing this file only — the
/// [AuthRepository] interface and every call site stay untouched.
class InMemoryAuthDatasource {
  InMemoryAuthDatasource() {
    _seedDemoAccounts();
  }

  final Map<String, _AuthRecord> _recordsByUsernameOrPhone = {};
  final StreamController<AppUser?> _currentUserController =
      StreamController<AppUser?>.broadcast();
  AppUser? _currentUser;

  static const String demoPassword = 'password123';

  /// Uses `Stream.multi` (not an `async*` generator forwarding a broadcast
  /// stream) so each new listener synchronously replays the current value
  /// before subscribing to future changes — an `async*` "yield current,
  /// then yield* the broadcast stream" pattern has a real race: the
  /// generator can still be scheduling that hand-off when an update fires,
  /// and broadcast controllers drop events with no listener attached yet.
  Stream<AppUser?> watchCurrentUser() {
    return Stream<AppUser?>.multi((controller) {
      controller.add(_currentUser);
      final subscription = _currentUserController.stream.listen(
        controller.add,
        onError: controller.addError,
      );
      controller.onCancel = subscription.cancel;
    }, isBroadcast: true);
  }

  AppUser login(String usernameOrPhone, String password) {
    final record = _recordsByUsernameOrPhone[usernameOrPhone];
    if (record == null || record.password != password) {
      throw const InvalidCredentialsException();
    }
    _setCurrentUser(record.user);
    return record.user;
  }

  AppUser createAccount(AppUser user, String usernameOrPhone, String password) {
    if (_recordsByUsernameOrPhone.containsKey(usernameOrPhone)) {
      throw const UsernameAlreadyTakenException();
    }
    _recordsByUsernameOrPhone[usernameOrPhone] = _AuthRecord(user, password);
    _setCurrentUser(user);
    return user;
  }

  void logout() => _setCurrentUser(null);

  /// Looks up an account by its login key without checking a password.
  /// Only meant to be called by the repository when restoring a session
  /// that was already authenticated in a previous app run.
  AppUser? findByKey(String usernameOrPhone) =>
      _recordsByUsernameOrPhone[usernameOrPhone]?.user;

  void restoreCurrentUser(AppUser user) => _setCurrentUser(user);

  void _setCurrentUser(AppUser? user) {
    _currentUser = user;
    _currentUserController.add(user);
  }

  void _seedDemoAccounts() {
    final now = DateTime.now();

    void seed(String key, AppUser user) {
      _recordsByUsernameOrPhone[key] = _AuthRecord(user, demoPassword);
    }

    seed(
      'client1',
      AppUser.client(
        id: DemoIds.clientAwa,
        displayName: 'Awa Traoré',
        usernameOrPhone: 'client1',
        phoneNumber: '+22370000001',
        createdAt: now,
      ),
    );
    seed(
      'client2',
      AppUser.client(
        id: DemoIds.clientMoussa,
        displayName: 'Moussa Diarra',
        usernameOrPhone: 'client2',
        phoneNumber: '+22370000002',
        createdAt: now,
      ),
    );
    seed(
      'fournisseur1',
      AppUser.supplierTiers(
        id: DemoIds.supplierBogolanBamako,
        displayName: 'Ibrahima Coulibaly',
        usernameOrPhone: 'fournisseur1',
        phoneNumber: '+22376000001',
        createdAt: now,
        businessName: 'Bogolan Bamako',
        verificationStatus: VerificationStatus.verified,
        city: 'Bamako',
        ratingAverage: 4.6,
        ratingCount: 132,
      ),
    );
    seed(
      'fournisseur2',
      AppUser.supplierTiers(
        id: DemoIds.supplierArtisanatSikasso,
        displayName: 'Fatoumata Keita',
        usernameOrPhone: 'fournisseur2',
        phoneNumber: '+22376000002',
        createdAt: now,
        businessName: 'Artisanat Sikasso',
        verificationStatus: VerificationStatus.pending,
        city: 'Sikasso',
        ratingAverage: 0,
        ratingCount: 0,
      ),
    );
    seed(
      'agent1',
      AppUser.supplierPrincipal(
        id: DemoIds.staffAgent,
        displayName: 'Agent MTC',
        usernameOrPhone: 'agent1',
        phoneNumber: '+22378000001',
        createdAt: now,
        staffRole: StaffRole.agent,
      ),
    );
    seed(
      'admin1',
      AppUser.supplierPrincipal(
        id: DemoIds.staffAdmin,
        displayName: 'Admin MTC',
        usernameOrPhone: 'admin1',
        phoneNumber: '+22378000002',
        createdAt: now,
        staffRole: StaffRole.admin,
      ),
    );
  }
}
