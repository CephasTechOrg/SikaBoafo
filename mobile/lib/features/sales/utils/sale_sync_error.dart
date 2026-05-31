import 'dart:async';

import 'package:dio/dio.dart';

import '../../../shared/utils/user_friendly_error.dart';

/// User-facing copy for sale recording / sync failures (cash + Paystack pre-pay).
String humanizeSaleSyncError(Object error) {
  if (error is TimeoutException) {
    return error.message ??
        'Sale is still syncing. Connect to the internet and try again.';
  }
  if (error is StateError) {
    final msg = error.message.trim();
    if (msg.isNotEmpty) return msg;
    return 'Sale could not sync with the server.';
  }
  if (error is ArgumentError) {
    final msg = error.message?.toString().trim();
    if (msg != null && msg.isNotEmpty) return msg;
    return 'Invalid sale input. Please check quantities and try again.';
  }
  if (error is FormatException) {
    final msg = error.message.trim();
    if (msg.isNotEmpty) return msg;
    return 'Something went wrong while reading data. Please try again.';
  }
  if (error is DioException) {
    return _humanizeDio(error);
  }
  return userFriendlyError(error);
}

String _humanizeDio(DioException error) {
  final detail = error.response?.data;
  if (detail is Map<String, dynamic>) {
    final raw = detail['detail'];
    if (raw is String && raw.trim().isNotEmpty) {
      return raw.trim();
    }
    if (raw is List && raw.isNotEmpty) {
      final first = raw.first;
      if (first is Map<String, dynamic>) {
        final msg = first['msg'];
        if (msg is String && msg.trim().isNotEmpty) {
          return msg.trim();
        }
      }
    }
  }
  if (detail is String && detail.trim().isNotEmpty) {
    return detail.trim();
  }
  if (error.type == DioExceptionType.connectionError ||
      error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.sendTimeout) {
    return 'No internet connection. Please check your network and try again.';
  }
  final code = error.response?.statusCode;
  if (code == 401) {
    return 'Your session has expired. Please sign in again.';
  }
  if (code != null) {
    return 'Request failed (HTTP $code). Please try again.';
  }
  return error.message ?? 'Request failed. Please try again.';
}
