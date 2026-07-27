import 'package:freezed_annotation/freezed_annotation.dart';

import 'user_model.dart';

part 'auth_response_model.freezed.dart';
part 'auth_response_model.g.dart';

/// Sesuai schema AuthLoginResponse: dipakai oleh /auth/login dan /auth/google.
@freezed
class AuthResponseModel with _$AuthResponseModel {
  const factory AuthResponseModel({
    required UserModel user,
    required String token,
  }) = _AuthResponseModel;

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) =>
      _$AuthResponseModelFromJson(json);
}
