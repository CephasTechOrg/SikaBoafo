import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Converts developer-facing exceptions into short, user-friendly messages.
///
/// Rules:
/// - Prefer actionable + calm language
/// - Hide technical details (stack traces, exception types)
/// - Preserve backend-provided `detail` if it already looks user-facing
String userFriendlyError(Object error) {
  if (error is UserFacingError) return error.message;

  if (error is ArgumentError) {
    final msg = error.message?.toString().trim();
    return (msg == null || msg.isEmpty) ? 'Invalid input. Please check and try again.' : msg;
  }

  if (error is FormatException) {
    // Usually indicates unexpected API payloads or corrupted local data.
    return 'Something went wrong while reading data. Please try again.';
  }

  if (error is DioException) {
    final status = error.response?.statusCode;
    final detail = _extractBackendDetail(error.response?.data);

    if (_isOfflineish(error)) {
      return 'No internet connection. Please check your network and try again.';
    }

    if (status == 401) {
      return 'Your session has expired. Please sign in again.';
    }
    if (status == 429) {
      return detail ??
          'Too many attempts. Please wait a moment and try again.';
    }
    if (status == 403) {
      return "You don't have permission to do that.";
    }
    if (status == 404) {
      return detail ?? 'We couldn’t find what you requested. Please refresh and try again.';
    }
    if (status == 409) {
      return detail ?? 'This action conflicts with the current state. Please refresh and try again.';
    }
    if (status != null && status >= 500) {
      return 'Server is having trouble right now. Please try again shortly.';
    }
    if (detail != null) {
      return detail;
    }
    return 'Request failed. Please try again.';
  }

  // Avoid dumping exception types into the UI.
  if (kDebugMode) {
    // ignore: avoid_print
    print('Unhandled error: $error');
  }
  return 'Something went wrong. Please try again.';
}

bool _isOfflineish(DioException e) {
  if (e.type == DioExceptionType.connectionError) return true;
  if (e.type == DioExceptionType.connectionTimeout) return true;
  if (e.type == DioExceptionType.receiveTimeout) return true;
  if (e.type == DioExceptionType.sendTimeout) return true;
  return false;
}

String? _extractBackendDetail(Object? data) {
  if (data is Map<String, dynamic>) {
    final d = data['detail'];
    if (d is String) {
      final s = d.trim();
      if (s.isEmpty) return null;
      // If backend sent a Python traceback or structured dev detail, hide it.
      final looksDev = s.contains('Traceback') ||
          s.contains('DioException') ||
          s.contains('psycopg') ||
          s.contains('sqlalchemy') ||
          s.contains('Exception') ||
          s.contains('Error:');
      return looksDev ? null : s;
    }
  }
  return null;
}

class UserFacingError implements Exception {
  const UserFacingError(this.message);
  final String message;

  @override
  String toString() => message;
}

