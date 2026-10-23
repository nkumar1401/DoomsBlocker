import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

enum StudyScanType {
  checkIn,
  checkOut,
  unknown,
}

class StudyQrPayload {
  final StudyScanType type;
  final String zoneName;
  final String raw;

  const StudyQrPayload({
    required this.type,
    required this.zoneName,
    required this.raw,
  });

  static StudyQrPayload? parse(String raw) {
    final trimmed = raw.trim();
    if (!trimmed.startsWith('DOOMSBLOCKER_STUDY:')) {
      return null;
    }
    final parts = trimmed.split(':');
    if (parts.length < 3) return null;
    final action = parts[1].toUpperCase();
    final name = parts.sublist(2).join(':').trim();

    if (action == 'IN') {
      return StudyQrPayload(
        type: StudyScanType.checkIn,
        zoneName: name.isNotEmpty ? name : 'Library Study Zone',
        raw: trimmed,
      );
    } else if (action == 'OUT') {
      return StudyQrPayload(
        type: StudyScanType.checkOut,
        zoneName: name.isNotEmpty ? name : 'Library Study Zone',
        raw: trimmed,
      );
    }
    return StudyQrPayload(
      type: StudyScanType.unknown,
      zoneName: name,
      raw: trimmed,
    );
  }
}

class QrScannerScreen extends StatefulWidget {
  final String? title;
  final String? subtitle;
  final StudyScanType? expectedType;

  const QrScannerScreen({
    Key? key,
    this.title,
    this.subtitle,
    this.expectedType,
  }) : super(key: key);

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen>
    with SingleTickerProviderStateMixin {
  late final MobileScannerController _controller;
  late final AnimationController _animController;
  late final Animation<double> _laserAnimation;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _laserAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    for (final barcode in barcodes) {
      final raw = barcode.rawValue;
      if (raw == null || raw.isEmpty) continue;

      final payload = StudyQrPayload.parse(raw);
      if (payload != null) {
        setState(() => _isProcessing = true);
        Navigator.of(context).pop(payload);
        return;
      } else {
        // Unrecognized QR code
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Not a valid DoomsBlocker Library QR code.\nPayload: $raw',
              style: const TextStyle(fontSize: 12),
            ),
            backgroundColor: const Color(0xFFEF4444),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleText = widget.title ??
        (widget.expectedType == StudyScanType.checkOut
            ? 'Scan Desk Exit QR'
            : 'Scan Library QR');
    final subtitleText = widget.subtitle ??
        (widget.expectedType == StudyScanType.checkOut
            ? 'Scan the printed QR at the library exit desk to release early'
            : 'Point your camera at the printed Library Entrance or Exit poster');

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),

          // Dark vignette overlay with square transparent cutout
          LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.biggest;
              final scanBoxSize = size.width * 0.72;
              final left = (size.width - scanBoxSize) / 2;
              final top = (size.height - scanBoxSize) / 2 - 20;

              return Stack(
                children: [
                  // Translucent dark mask
                  ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      Colors.black.withOpacity(0.65),
                      BlendMode.srcOut,
                    ),
                    child: Stack(
                      children: [
                        Container(
                          decoration: const BoxDecoration(
                            color: Colors.black,
                            backgroundBlendMode: BlendMode.dstOut,
                          ),
                        ),
                        Align(
                          alignment: Alignment.center,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 40),
                            width: scanBoxSize,
                            height: scanBoxSize,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Viewfinder corners and laser line
                  Positioned(
                    left: left,
                    top: top,
                    width: scanBoxSize,
                    height: scanBoxSize,
                    child: Stack(
                      children: [
                        // Futuristic border
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: const Color(0xFF06B6D4).withOpacity(0.4),
                              width: 1.5,
                            ),
                          ),
                        ),

                        // Corner Reticles
                        const Positioned(
                          top: 0,
                          left: 0,
                          child: _CornerReticle(isTop: true, isLeft: true),
                        ),
                        const Positioned(
                          top: 0,
                          right: 0,
                          child: _CornerReticle(isTop: true, isLeft: false),
                        ),
                        const Positioned(
                          bottom: 0,
                          left: 0,
                          child: _CornerReticle(isTop: false, isLeft: true),
                        ),
                        const Positioned(
                          bottom: 0,
                          right: 0,
                          child: _CornerReticle(isTop: false, isLeft: false),
                        ),

                        // Animated scanning laser line
                        AnimatedBuilder(
                          animation: _laserAnimation,
                          builder: (context, child) {
                            return Positioned(
                              top: _laserAnimation.value * (scanBoxSize - 20) + 10,
                              left: 14,
                              right: 14,
                              child: Container(
                                height: 3,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(2),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      Color(0xFF06B6D4),
                                      Color(0xFF10B981),
                                      Color(0xFF06B6D4),
                                      Colors.transparent,
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF06B6D4).withOpacity(0.8),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),

          // Header / Controls
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Text(
                        titleText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.flash_on, color: Colors.amber),
                            onPressed: () => _controller.toggleTorch(),
                          ),
                          IconButton(
                            icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
                            onPressed: () => _controller.switchCamera(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
                  child: Text(
                    subtitleText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Prompt
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withOpacity(0.9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.12),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF06B6D4).withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.qr_code_scanner,
                      color: Color(0xFF06B6D4),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Hold camera steady over the printed QR poster at the desk.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CornerReticle extends StatelessWidget {
  final bool isTop;
  final bool isLeft;

  const _CornerReticle({
    Key? key,
    required this.isTop,
    required this.isLeft,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const size = 26.0;
    const thickness = 3.5;
    const color = Color(0xFF10B981);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Positioned(
            top: isTop ? 0 : null,
            bottom: !isTop ? 0 : null,
            left: 0,
            right: 0,
            child: Container(
              height: thickness,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Positioned(
            top: 0,
            bottom: 0,
            left: isLeft ? 0 : null,
            right: !isLeft ? 0 : null,
            child: Container(
              width: thickness,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
