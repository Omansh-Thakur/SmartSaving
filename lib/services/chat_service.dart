import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'api_config.dart';

class ChatService {
  ChatService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const Duration _chatTimeout = Duration(seconds: 25);

  Future<String> sendMessage({
    required String message,
    required int productId,
  }) async {
    final trimmedMessage = message.trim();
    if (trimmedMessage.isEmpty) {
      throw const ChatServiceException('Please enter a message.');
    }

    try {
      final response = await _client
          .post(
            Uri.parse(ApiConfig.chatApiUrl),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'message': trimmedMessage,
              'product_id': productId,
            }),
          )
          .timeout(_chatTimeout);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body is! Map<String, dynamic>) {
          throw const ChatServiceException(
            'Invalid response from server. Please try again.',
          );
        }

        final reply = body['reply']?.toString().trim();
        if (reply == null || reply.isEmpty) {
          throw const ChatServiceException(
            'Assistant returned an empty response.',
          );
        }
        return reply;
      }

      throw ChatServiceException(_mapHttpError(response));
    } on TimeoutException {
      throw ChatServiceException(_timeoutMessage());
    } on SocketException {
      throw const ChatServiceException(
        'Network error. Check your internet connection.',
      );
    } on http.ClientException {
      throw const ChatServiceException(
        'Unable to reach assistant service. Verify backend URL and connectivity.',
      );
    } on FormatException {
      throw const ChatServiceException(
        'Invalid response from server. Please try again.',
      );
    }
  }

  String _timeoutMessage() {
    if (ApiConfig.backendBaseUrl.contains('10.0.2.2')) {
      return 'Assistant server is not reachable. If you are using a real device, run with --dart-define=BACKEND_BASE_URL=http://<your-machine-ip>:8000';
    }
    return 'Assistant request timed out. Please try again.';
  }

  String _mapHttpError(http.Response response) {
    final serverMessage = _tryParseServerMessage(response.body);
    if (serverMessage != null && serverMessage.isNotEmpty) {
      return serverMessage;
    }

    switch (response.statusCode) {
      case 400:
        return 'Please provide a valid chat message and product id.';
      case 404:
        return 'Product not found for assistant context.';
      case 502:
        return 'Assistant model is temporarily unavailable. Please retry.';
      case 500:
        return 'Assistant service is not configured correctly. Check backend logs.';
      default:
        return 'Unable to fetch assistant response (HTTP ${response.statusCode}).';
    }
  }

  String? _tryParseServerMessage(String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map<String, dynamic>) {
        final detail = data['detail']?.toString().trim();
        if (detail != null && detail.isNotEmpty) {
          return detail;
        }
        final message = data['message']?.toString().trim();
        if (message != null && message.isNotEmpty) {
          return message;
        }
      }
    } catch (_) {
      // Ignore parse failures and fallback to status-code based message.
    }
    return null;
  }
}

class ChatServiceException implements Exception {
  const ChatServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

final chatService = ChatService();
