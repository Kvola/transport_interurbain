import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Service de partage de billets
/// Permet de partager les billets via différents canaux (SMS, WhatsApp, Email, etc.)
class ShareService {
  /// Partage générique via le système natif
  static Future<void> shareText({
    required String text,
    String? subject,
  }) async {
    await Share.share(text, subject: subject);
  }

  /// Partage avec fichier (QR Code par exemple)
  static Future<void> shareWithFile({
    required String text,
    required String filePath,
    String? subject,
  }) async {
    await Share.shareXFiles(
      [XFile(filePath)],
      text: text,
      subject: subject,
    );
  }

  /// Partage via SMS
  static Future<bool> shareViaSms({
    required String message,
    required String phoneNumber,
  }) async {
    // Nettoyer le numéro de téléphone
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[\s\-\.\(\)]'), '');
    
    final uri = Uri(
      scheme: 'sms',
      path: cleanPhone,
      queryParameters: {'body': message},
    );
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return true;
    }
    return false;
  }

  /// Partage via WhatsApp
  static Future<bool> shareViaWhatsApp({
    required String message,
    String? phoneNumber,
  }) async {
    String url;
    
    if (phoneNumber != null && phoneNumber.isNotEmpty) {
      // Nettoyer et formater le numéro pour WhatsApp (format international sans +)
      String cleanPhone = phoneNumber.replaceAll(RegExp(r'[\s\-\.\(\)\+]'), '');
      
      // Ajouter le code pays Côte d'Ivoire si nécessaire
      if (!cleanPhone.startsWith('225') && cleanPhone.length <= 10) {
        cleanPhone = '225$cleanPhone';
      }
      
      url = 'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}';
    } else {
      url = 'https://wa.me/?text=${Uri.encodeComponent(message)}';
    }
    
    final uri = Uri.parse(url);
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return true;
    }
    return false;
  }

  /// Partage via Email
  static Future<bool> shareViaEmail({
    required String message,
    required String subject,
    String? recipientEmail,
  }) async {
    final uri = Uri(
      scheme: 'mailto',
      path: recipientEmail ?? '',
      queryParameters: {
        'subject': subject,
        'body': message,
      },
    );
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return true;
    }
    return false;
  }

  /// Ouvre une URL dans le navigateur
  static Future<bool> openUrl(String url) async {
    final uri = Uri.parse(url);
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return true;
    }
    return false;
  }

  /// Copie le texte dans le presse-papier
  static Future<void> copyToClipboard(String text) async {
    await Share.share(text);
  }
}

/// Données de partage pour un billet
class TicketShareData {
  final String shareToken;
  final String shareUrl;
  final String shareMessage;
  final String smsMessage;
  final String ticketNumber;
  final String passengerName;
  final String? passengerPhone;
  final String route;
  final String departureDatetime;
  final String companyName;

  TicketShareData({
    required this.shareToken,
    required this.shareUrl,
    required this.shareMessage,
    required this.smsMessage,
    required this.ticketNumber,
    required this.passengerName,
    this.passengerPhone,
    required this.route,
    required this.departureDatetime,
    required this.companyName,
  });

  factory TicketShareData.fromJson(Map<String, dynamic> json) {
    return TicketShareData(
      shareToken: json['share_token'] ?? '',
      shareUrl: json['share_url'] ?? '',
      shareMessage: json['share_message'] ?? '',
      smsMessage: json['sms_message'] ?? '',
      ticketNumber: json['ticket_number'] ?? '',
      passengerName: json['passenger_name'] ?? '',
      passengerPhone: json['passenger_phone'],
      route: json['route'] ?? '',
      departureDatetime: json['departure_datetime'] ?? '',
      companyName: json['company_name'] ?? '',
    );
  }
}
