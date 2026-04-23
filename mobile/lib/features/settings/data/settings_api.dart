import '../../../core/services/api_client.dart';

class StaffMember {
  const StaffMember({
    required this.userId,
    required this.phoneNumber,
    required this.role,
    required this.roleDisplay,
    required this.isActive,
    this.fullName,
  });

  final String userId;
  final String phoneNumber;
  final String? fullName;
  final String role;
  final String roleDisplay;
  final bool isActive;

  factory StaffMember.fromJson(Map<String, dynamic> json) => StaffMember(
        userId: json['user_id'] as String,
        phoneNumber: json['phone_number'] as String,
        fullName: json['full_name'] as String?,
        role: json['role'] as String,
        roleDisplay: json['role_display'] as String,
        isActive: json['is_active'] as bool,
      );
}

class StaffInvite {
  const StaffInvite({
    required this.inviteId,
    required this.phoneNumber,
    required this.role,
    required this.roleDisplay,
    required this.status,
    required this.expiresAt,
  });

  final String inviteId;
  final String phoneNumber;
  final String role;
  final String roleDisplay;
  final String status;
  final DateTime expiresAt;

  factory StaffInvite.fromJson(Map<String, dynamic> json) => StaffInvite(
        inviteId: json['invite_id'] as String,
        phoneNumber: json['phone_number'] as String,
        role: json['role'] as String,
        roleDisplay: json['role_display'] as String,
        status: json['status'] as String,
        expiresAt: DateTime.parse(json['expires_at'] as String),
      );
}

class SettingsApi {
  SettingsApi(this._apiClient);

  final ApiClient _apiClient;

  Future<List<StaffMember>> listStaff() async {
    final response = await _apiClient.dio.get<dynamic>('/staff');
    final body = response.data;
    if (body is! List) throw const FormatException('Unexpected staff list payload.');
    return body
        .cast<Map<String, dynamic>>()
        .map(StaffMember.fromJson)
        .toList(growable: false);
  }

  Future<List<StaffInvite>> listPendingInvites() async {
    final response = await _apiClient.dio.get<dynamic>('/staff/invites');
    final body = response.data;
    if (body is! List) throw const FormatException('Unexpected invites payload.');
    return body
        .cast<Map<String, dynamic>>()
        .map(StaffInvite.fromJson)
        .toList(growable: false);
  }

  Future<StaffInvite> inviteStaff({
    required String phoneNumber,
    required String role,
  }) async {
    final response = await _apiClient.dio.post<dynamic>(
      '/staff/invite',
      data: {'phone_number': phoneNumber, 'role': role},
    );
    final body = response.data;
    if (body is! Map<String, dynamic>) throw const FormatException('Unexpected invite payload.');
    return StaffInvite.fromJson(body);
  }

  Future<StaffMember> updateRole({
    required String staffUserId,
    required String role,
  }) async {
    final response = await _apiClient.dio.patch<dynamic>(
      '/staff/$staffUserId/role',
      data: {'role': role},
    );
    final body = response.data;
    if (body is! Map<String, dynamic>) throw const FormatException('Unexpected member payload.');
    return StaffMember.fromJson(body);
  }

  Future<StaffMember> deactivateStaff(String staffUserId) async {
    final response = await _apiClient.dio.patch<dynamic>('/staff/$staffUserId/deactivate');
    final body = response.data;
    if (body is! Map<String, dynamic>) throw const FormatException('Unexpected member payload.');
    return StaffMember.fromJson(body);
  }
}
