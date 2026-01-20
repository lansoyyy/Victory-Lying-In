import 'dart:convert';

import 'package:http/http.dart' as http;

import 'third_party_config.dart';

class NotificationService {
  final http.Client _client;

  NotificationService({http.Client? client})
      : _client = client ?? http.Client();

  Future<bool> sendEmail({
    required String toEmail,
    required String subject,
    required String message,
    String? toName,
  }) async {
    try {
      final payload = {
        'service_id': ThirdPartyConfig.emailJsServiceId,
        'template_id': ThirdPartyConfig.emailJsTemplateId,
        'user_id': ThirdPartyConfig.emailJsPublicKey,
        'template_params': {
          'to_email': toEmail,
          'to_name': toName ?? '',
          'subject': subject,
          'message': message,
        },
      };

      final res = await _client.post(
        Uri.parse(ThirdPartyConfig.emailJsEndpoint),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> sendSms({
    required String number,
    required String message,
  }) async {
    try {
      final res = await _client.post(
        Uri.parse(ThirdPartyConfig.semaphoreMessagesEndpoint),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'apikey': ThirdPartyConfig.semaphoreApiKey,
          'number': number,
          'message': message,
          'sendername': ThirdPartyConfig.semaphoreSenderName,
        },
      );

      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<void> sendToUser({
    required String subject,
    required String message,
    String? email,
    String? phone,
    String? name,
  }) async {
    bool emailSent = false;

    if ((email ?? '').isNotEmpty) {
      emailSent = await sendEmail(
        toEmail: email!,
        subject: subject,
        message: message,
        toName: name,
      );
    }

    if (!emailSent && (phone ?? '').isNotEmpty) {
      await sendSms(number: phone!, message: message);
    }
  }

  Future<void> sendToClinic({
    required String subject,
    required String message,
  }) async {
    await sendToUser(
      subject: subject,
      message: message,
      email: ThirdPartyConfig.clinicNotificationEmail,
      phone: ThirdPartyConfig.clinicNotificationPhone,
      name: 'Clinic',
    );
  }
}
