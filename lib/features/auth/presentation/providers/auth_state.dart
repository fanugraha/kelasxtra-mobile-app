import 'package:freezed_annotation/freezed_annotation.dart';

import '../../data/models/user_model.dart';

part 'auth_state.freezed.dart';

/// Status autentikasi global aplikasi.
/// - [unknown]: masih cek token tersimpan (splash screen)
/// - [authenticated]: user login, [user] pasti terisi
/// - [unauthenticated]: belum/berhenti login
@freezed
class AuthState with _$AuthState {
  const factory AuthState.unknown() = _Unknown;
  const factory AuthState.authenticated(UserModel user) = _Authenticated;
  const factory AuthState.unauthenticated() = _Unauthenticated;
}
