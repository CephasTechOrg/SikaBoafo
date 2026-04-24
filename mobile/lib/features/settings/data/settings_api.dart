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

class PaystackConnectionSettings {
  const PaystackConnectionSettings({
    required this.provider,
    required this.isConnected,
    required this.mode,
    required this.test,
    required this.live,
    this.accountLabel,
  });

  final String provider;
  final bool isConnected;
  final String mode;
  final String? accountLabel;
  final PaystackModeState test;
  final PaystackModeState live;

  factory PaystackConnectionSettings.fromJson(Map<String, dynamic> json) {
    return PaystackConnectionSettings(
      provider: (json['provider'] as String?) ?? 'paystack',
      isConnected: (json['is_connected'] as bool?) ?? false,
      mode: (json['mode'] as String?) ?? 'test',
      accountLabel: json['account_label'] as String?,
      test: PaystackModeState.fromJson(
        (json['test'] as Map<String, dynamic>? ?? const {}),
      ),
      live: PaystackModeState.fromJson(
        (json['live'] as Map<String, dynamic>? ?? const {}),
      ),
    );
  }
}

class PaystackModeState {
  const PaystackModeState({
    required this.configured,
    this.verifiedAt,
    this.publicKeyMasked,
    this.secretKeyMasked,
  });

  final bool configured;
  final DateTime? verifiedAt;
  final String? publicKeyMasked;
  final String? secretKeyMasked;

  factory PaystackModeState.fromJson(Map<String, dynamic> json) {
    return PaystackModeState(
      configured: (json['configured'] as bool?) ?? false,
      verifiedAt: json['verified_at'] == null
          ? null
          : DateTime.tryParse(json['verified_at'] as String),
      publicKeyMasked: json['public_key_masked'] as String?,
      secretKeyMasked: json['secret_key_masked'] as String?,
    );
  }
}

class SettingsApi {
  SettingsApi(this._apiClient);

  final ApiClient _apiClient;

  Future<List<StaffMember>> listStaff() async {
    final response = await _apiClient.dio.get<dynamic>('/staff');
    final body = response.data;
    if (body is! List) {
      throw const FormatException('Unexpected staff list payload.');
    }
    return body
        .cast<Map<String, dynamic>>()
        .map(StaffMember.fromJson)
        .toList(growable: false);
  }

  Future<List<StaffInvite>> listPendingInvites() async {
    final response = await _apiClient.dio.get<dynamic>('/staff/invites');
    final body = response.data;
    if (body is! List) {
      throw const FormatException('Unexpected invites payload.');
    }
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
    if (body is! Map<String, dynamic>) {
      throw const FormatException('Unexpected invite payload.');
    }
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
    if (body is! Map<String, dynamic>) {
      throw const FormatException('Unexpected member payload.');
    }
    return StaffMember.fromJson(body);
  }

  Future<StaffMember> deactivateStaff(String staffUserId) async {
    final response =
        await _apiClient.dio.patch<dynamic>('/staff/$staffUserId/deactivate');
    final body = response.data;
    if (body is! Map<String, dynamic>) {
      throw const FormatException('Unexpected member payload.');
    }
    return StaffMember.fromJson(body);
  }

  Future<PaystackConnectionSettings> fetchPaystackConnection() async {
    final response =
        await _apiClient.dio.get<dynamic>('/payments/paystack/connection');
    final body = response.data;
    if (body is! Map<String, dynamic>) {
      throw const FormatException('Unexpected paystack connection payload.');
    }
    return PaystackConnectionSettings.fromJson(body);
  }

  Future<PaystackConnectionSettings> savePaystackConnection({
    String? publicKey,
    String? secretKey,
    required String mode,
    String? accountLabel,
  }) async {
    final response = await _apiClient.dio.put<dynamic>(
      '/payments/paystack/connection',
      data: {
        'public_key': publicKey?.trim().isEmpty == true ? null : publicKey?.trim(),
        'secret_key': secretKey?.trim().isEmpty == true ? null : secretKey?.trim(),
        'mode': mode,
        'account_label':
            accountLabel?.trim().isEmpty == true ? null : accountLabel?.trim(),
      },
    );
    final body = response.data;
    if (body is! Map<String, dynamic>) {
      throw const FormatException('Unexpected paystack connection payload.');
    }
    return PaystackConnectionSettings.fromJson(body);
  }

  Future<PaystackConnectionSettings> disconnectPaystackConnection() async {
    final response =
        await _apiClient.dio.delete<dynamic>('/payments/paystack/connection');
    final body = response.data;
    if (body is! Map<String, dynamic>) {
      throw const FormatException('Unexpected paystack connection payload.');
    }
    return PaystackConnectionSettings.fromJson(body);
  }
}
