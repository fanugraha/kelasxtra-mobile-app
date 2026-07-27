import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

enum UserRole {
  @JsonValue('siswa')
  siswa,
  @JsonValue('tutor')
  tutor,
  @JsonValue('admin')
  admin,
  @JsonValue('orang_tua')
  orangTua,
}

enum LevelPendidikan {
  @JsonValue('sd')
  sd,
  @JsonValue('smp')
  smp,
  @JsonValue('sma')
  sma,
  @JsonValue('mahasiswa')
  mahasiswa,
  @JsonValue('umum')
  umum,
}

@freezed
class UserModel with _$UserModel {
  const factory UserModel({
    required int id,
    required String name,
    required String email,
    String? phone,
    required UserRole role,
    @JsonKey(name: 'level_pendidikan') LevelPendidikan? levelPendidikan,
    @JsonKey(name: 'is_active') required bool isActive,
    @JsonKey(name: 'hide_from_leaderboard_feed') @Default(false) bool hideFromLeaderboardFeed,
    @JsonKey(name: 'parent_id') int? parentId,
    @JsonKey(name: 'google_id') String? googleId,
    @JsonKey(name: 'email_verified_at') DateTime? emailVerifiedAt,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _UserModel;

  factory UserModel.fromJson(Map<String, dynamic> json) => _$UserModelFromJson(json);
}
