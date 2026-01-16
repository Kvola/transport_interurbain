import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:vibration/vibration.dart';

import '../../providers/scan_provider.dart';
import '../../providers/trip_provider.dart';
import '../../models/agent_models.dart';
import '../../theme/app_theme.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with WidgetsBindingObserver {
  MobileScannerController? _controller;
  bool _isProcessing = false;
  bool _torchOn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initController();
  }

  void _initController() {
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _controller?.stop();
    } else if (state == AppLifecycleState.resumed) {
      _controller?.start();
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    if (capture.barcodes.isEmpty) return;

    final barcode = capture.barcodes.first;
    if (barcode.rawValue == null) return;

    setState(() => _isProcessing = true);

    // Vibrer pour confirmer le scan
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 100);
    }

    // Traiter le QR code
    final scanProvider = Provider.of<ScanProvider>(context, listen: false);
    final result = await scanProvider.processQrCode(barcode.rawValue!);

    if (mounted && result != null) {
      // Afficher le résultat
      await _showResultSheet(result);
    }

    // Petit délai avant de permettre un nouveau scan
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() => _isProcessing = false);
  }

  Future<void> _showResultSheet(ScanResult result) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ScanResultSheet(result: result),
    );
    
    // Réinitialiser le provider après fermeture
    if (mounted) {
      Provider.of<ScanProvider>(context, listen: false).reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scanProvider = Provider.of<ScanProvider>(context);
    final tripProvider = Provider.of<TripProvider>(context);
    final currentTrip = tripProvider.currentTrip;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Scanner
          if (_controller != null)
            MobileScanner(
              controller: _controller!,
              onDetect: _onDetect,
            ),

          // Overlay
          CustomPaint(
            painter: _ScanOverlayPainter(),
            child: Container(),
          ),

          // En-tête
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white, size: 28),
                      ),
                      if (currentTrip != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            currentTrip.route,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      IconButton(
                        onPressed: () async {
                          setState(() => _torchOn = !_torchOn);
                          await _controller?.toggleTorch();
                        },
                        icon: Icon(
                          _torchOn ? Icons.flash_on : Icons.flash_off,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Zone de scan centrale
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _isProcessing 
                          ? AppTheme.warningColor 
                          : Colors.white,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: _isProcessing
                      ? const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 32),
                Text(
                  _isProcessing 
                      ? 'Traitement en cours...' 
                      : 'Placez le QR code dans le cadre',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),

          // Statistiques en bas
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.8),
                    Colors.transparent,
                  ],
                ),
              ),
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _ScanStat(
                      icon: Icons.qr_code_scanner,
                      value: scanProvider.sessionBoardedCount.toString(),
                      label: 'Embarqués (session)',
                    ),
                    _ScanStat(
                      icon: Icons.people,
                      value: '${currentTrip?.boardedCount ?? 0}/${currentTrip?.bookedSeats ?? 0}',
                      label: 'Total embarqués',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    final scanAreaSize = 250.0;
    final scanAreaLeft = (size.width - scanAreaSize) / 2;
    final scanAreaTop = (size.height - scanAreaSize) / 2;

    // Zone semi-transparente autour du cadre
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(scanAreaLeft, scanAreaTop, scanAreaSize, scanAreaSize),
        const Radius.circular(20),
      ))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ScanStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _ScanStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _ScanResultSheet extends StatelessWidget {
  final ScanResult result;

  const _ScanResultSheet({required this.result});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Contenu
              Expanded(
                child: result.success
                    ? _SuccessContent(
                        result: result,
                        scrollController: scrollController,
                      )
                    : _ErrorContent(result: result),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SuccessContent extends StatelessWidget {
  final ScanResult result;
  final ScrollController scrollController;

  const _SuccessContent({
    required this.result,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final passengers = result.passengers ?? (result.passenger != null ? [result.passenger!] : []);
    final allPaid = passengers.every((p) => p.isPaid);
    final anyBoarded = passengers.any((p) => p.isBoarded);

    return Column(
      children: [
        // Header avec statut
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          color: anyBoarded
              ? AppTheme.warningColor.withOpacity(0.1)
              : allPaid
                  ? AppTheme.scanSuccessColor.withOpacity(0.1)
                  : AppTheme.warningColor.withOpacity(0.1),
          child: Column(
            children: [
              Icon(
                anyBoarded
                    ? Icons.warning
                    : allPaid
                        ? Icons.check_circle
                        : Icons.warning,
                size: 48,
                color: anyBoarded
                    ? AppTheme.warningColor
                    : allPaid
                        ? AppTheme.scanSuccessColor
                        : AppTheme.warningColor,
              ),
              const SizedBox(height: 12),
              Text(
                anyBoarded
                    ? 'Passager déjà embarqué'
                    : allPaid
                        ? 'Passager vérifié ✓'
                        : 'Paiement en attente',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: anyBoarded
                      ? AppTheme.warningColor
                      : allPaid
                          ? AppTheme.scanSuccessColor
                          : AppTheme.warningColor,
                ),
              ),
              if (passengers.length > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${passengers.length} billets trouvés',
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
            ],
          ),
        ),

        // Liste des passagers/billets
        Expanded(
          child: ListView.builder(
            controller: scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: passengers.length,
            itemBuilder: (context, index) {
              final passenger = passengers[index];
              return _PassengerResultCard(passenger: passenger);
            },
          ),
        ),

        // Actions
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Fermer'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _BoardingButton(passengers: passengers),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PassengerResultCard extends StatelessWidget {
  final Passenger passenger;

  const _PassengerResultCard({required this.passenger});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nom et statut
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        passenger.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        passenger.phone,
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: passenger.isPaid
                        ? AppTheme.paidColor.withOpacity(0.1)
                        : AppTheme.unpaidColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        passenger.isPaid ? Icons.check_circle : Icons.cancel,
                        size: 16,
                        color: passenger.isPaid
                            ? AppTheme.paidColor
                            : AppTheme.unpaidColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        passenger.isPaid ? 'Payé' : 'Non payé',
                        style: TextStyle(
                          color: passenger.isPaid
                              ? AppTheme.paidColor
                              : AppTheme.unpaidColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            
            // Détails
            Row(
              children: [
                _DetailChip(
                  icon: Icons.event_seat,
                  label: 'Siège ${passenger.seatNumber ?? '-'}',
                ),
                const SizedBox(width: 8),
                _DetailChip(
                  icon: Icons.confirmation_number,
                  label: passenger.bookingReference,
                ),
              ],
            ),
            
            // Montant dû si non payé
            if (!passenger.isPaid && passenger.amountDue > 0) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.unpaidColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Montant à percevoir:'),
                    Text(
                      passenger.formattedAmountDue,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.unpaidColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            // Statut embarquement
            if (passenger.isBoarded) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.boardedColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check, color: AppTheme.boardedColor),
                    SizedBox(width: 8),
                    Text(
                      'Déjà embarqué',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.boardedColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _DetailChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _BoardingButton extends StatelessWidget {
  final List<Passenger> passengers;

  const _BoardingButton({required this.passengers});

  @override
  Widget build(BuildContext context) {
    final notBoarded = passengers.where((p) => !p.isBoarded).toList();
    
    if (notBoarded.isEmpty) {
      return ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey,
        ),
        child: const Text('Tous embarqués'),
      );
    }

    return Consumer<ScanProvider>(
      builder: (context, scanProvider, _) {
        return ElevatedButton.icon(
          onPressed: scanProvider.isProcessing
              ? null
              : () async {
                  final bookingIds = notBoarded.map((p) => p.bookingId).toList();
                  
                  bool success;
                  if (bookingIds.length == 1) {
                    success = await scanProvider.boardPassenger(bookingIds.first);
                  } else {
                    success = await scanProvider.boardPassengersBatch(bookingIds);
                  }
                  
                  if (context.mounted) {
                    if (success) {
                      // Mettre à jour les stats
                      final tripProvider = Provider.of<TripProvider>(context, listen: false);
                      for (final id in bookingIds) {
                        tripProvider.updatePassengerBoarded(id);
                      }
                      
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            bookingIds.length == 1
                                ? 'Passager embarqué avec succès'
                                : '${bookingIds.length} passagers embarqués',
                          ),
                          backgroundColor: AppTheme.scanSuccessColor,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(scanProvider.error ?? 'Erreur'),
                          backgroundColor: AppTheme.errorColor,
                        ),
                      );
                    }
                  }
                },
          icon: scanProvider.isProcessing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(Icons.check),
          label: Text(
            notBoarded.length == 1
                ? 'Embarquer'
                : 'Embarquer ${notBoarded.length} passagers',
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accentColor,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        );
      },
    );
  }
}

class _ErrorContent extends StatelessWidget {
  final ScanResult result;

  const _ErrorContent({required this.result});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: AppTheme.scanErrorColor,
          ),
          const SizedBox(height: 16),
          const Text(
            'QR Code non reconnu',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            result.message ?? 'Ce QR code n\'est pas valide pour ce voyage',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Réessayer'),
            ),
          ),
        ],
      ),
    );
  }
}
