import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/share_service.dart';
import '../theme/app_theme.dart';

/// Bottom sheet pour partager un billet
/// Affiche les différentes options de partage disponibles
class TicketShareSheet extends StatelessWidget {
  final TicketShareData shareData;
  final VoidCallback? onShared;

  const TicketShareSheet({
    super.key,
    required this.shareData,
    this.onShared,
  });

  /// Afficher le bottom sheet
  static Future<void> show(BuildContext context, TicketShareData shareData) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TicketShareSheet(shareData: shareData),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Indicateur
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Icône et titre
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.share,
                  color: AppTheme.primaryColor,
                  size: 32,
                ),
              ),
              
              const SizedBox(height: 16),
              
              const Text(
                'Partager le billet',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 8),
              
              Text(
                'Envoyez ce billet à ${shareData.passengerName}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Résumé du billet
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.confirmation_number, color: AppTheme.primaryColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shareData.ticketNumber,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${shareData.route} • ${shareData.departureDatetime}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Options de partage
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ShareOption(
                    icon: Icons.sms,
                    label: 'SMS',
                    color: Colors.blue,
                    onTap: () => _shareViaSms(context),
                  ),
                  _ShareOption(
                    icon: Icons.message,
                    label: 'WhatsApp',
                    color: const Color(0xFF25D366),
                    onTap: () => _shareViaWhatsApp(context),
                  ),
                  _ShareOption(
                    icon: Icons.email,
                    label: 'Email',
                    color: Colors.red,
                    onTap: () => _shareViaEmail(context),
                  ),
                  _ShareOption(
                    icon: Icons.more_horiz,
                    label: 'Plus',
                    color: Colors.grey,
                    onTap: () => _shareViaSystem(context),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Lien de partage
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.link, color: AppTheme.primaryColor, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Lien de partage',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            shareData.shareUrl,
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () => _copyLink(context),
                          icon: const Icon(Icons.copy, size: 18),
                          label: const Text('Copier'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.primaryColor,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Bouton ouvrir dans navigateur
              OutlinedButton.icon(
                onPressed: () => _openInBrowser(context),
                icon: const Icon(Icons.open_in_browser),
                label: const Text('Voir le billet en ligne'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _shareViaSms(BuildContext context) async {
    final phone = shareData.passengerPhone ?? '';
    final success = await ShareService.shareViaSms(
      message: shareData.smsMessage,
      phoneNumber: phone,
    );
    
    if (!success && context.mounted) {
      _showError(context, 'Impossible d\'ouvrir l\'application SMS');
    } else {
      Navigator.pop(context);
      onShared?.call();
    }
  }

  void _shareViaWhatsApp(BuildContext context) async {
    final success = await ShareService.shareViaWhatsApp(
      message: shareData.shareMessage,
      phoneNumber: shareData.passengerPhone,
    );
    
    if (!success && context.mounted) {
      _showError(context, 'WhatsApp n\'est pas installé sur cet appareil');
    } else {
      Navigator.pop(context);
      onShared?.call();
    }
  }

  void _shareViaEmail(BuildContext context) async {
    final success = await ShareService.shareViaEmail(
      message: shareData.shareMessage,
      subject: 'Votre billet de transport - ${shareData.ticketNumber}',
      recipientEmail: null, // L'utilisateur saisira l'email
    );
    
    if (!success && context.mounted) {
      _showError(context, 'Impossible d\'ouvrir l\'application email');
    } else {
      Navigator.pop(context);
      onShared?.call();
    }
  }

  void _shareViaSystem(BuildContext context) async {
    await ShareService.shareText(
      text: shareData.shareMessage,
      subject: 'Billet de transport - ${shareData.ticketNumber}',
    );
    
    if (context.mounted) {
      Navigator.pop(context);
      onShared?.call();
    }
  }

  void _copyLink(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: shareData.shareUrl));
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lien copié dans le presse-papier'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _openInBrowser(BuildContext context) async {
    final success = await ShareService.openUrl(shareData.shareUrl);
    
    if (!success && context.mounted) {
      _showError(context, 'Impossible d\'ouvrir le navigateur');
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}

class _ShareOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ShareOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bouton de partage à intégrer dans les écrans
class ShareTicketButton extends StatelessWidget {
  final int bookingId;
  final bool isForOther;
  final String? passengerName;
  final Future<TicketShareData?> Function(int bookingId) onGenerateShareLink;

  const ShareTicketButton({
    super.key,
    required this.bookingId,
    this.isForOther = false,
    this.passengerName,
    required this.onGenerateShareLink,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => _handleShare(context),
      icon: const Icon(Icons.share),
      label: Text(isForOther ? 'Envoyer au voyageur' : 'Partager'),
      style: ElevatedButton.styleFrom(
        backgroundColor: isForOther ? AppTheme.accentColor : AppTheme.primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    );
  }

  void _handleShare(BuildContext context) async {
    // Afficher un loader
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final shareData = await onGenerateShareLink(bookingId);
      
      if (context.mounted) {
        Navigator.pop(context); // Fermer le loader
        
        if (shareData != null) {
          TicketShareSheet.show(context, shareData);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Impossible de générer le lien de partage'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Fermer le loader
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
