import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';


class WallpaperEditor extends StatefulWidget {
  final Map<String, dynamic> wallpaper;

  const WallpaperEditor({super.key, required this.wallpaper});

  @override
  State<WallpaperEditor> createState() => _WallpaperEditorState();
}

class _WallpaperEditorState extends State<WallpaperEditor> {
  final GlobalKey _repaintKey = GlobalKey();
  static const _channel = MethodChannel('com.ybt.wallpaper/wallpaper');

  double _blur = 0.0;
  double _brightness = 0.0; // -0.5 to 0.5
  bool _isGrayscale = false;
  BoxFit _fitMode = BoxFit.cover; // cover=Fill, contain=Fit, none=Center

  bool _isProcessing = false;

  // Grayscale matrix
  static const List<double> _grayscaleMatrix = [
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0,      0,      0,      1, 0,
  ];

  // Brightness matrix generator
  List<double> _brightnessMatrix(double value) {
    final translation = value * 255;
    return [
      1, 0, 0, 0, translation,
      0, 1, 0, 0, translation,
      0, 0, 1, 0, translation,
      0, 0, 0, 1, 0,
    ];
  }

  Future<void> _triggerHaptic(HapticFeedbackType type) async {
    try {
      if (type == HapticFeedbackType.light) {
        await HapticFeedback.lightImpact();
      } else {
        await HapticFeedback.mediumImpact();
      }
    } catch (_) {}
  }

  Future<Uint8List?> _capturePng() async {
    try {
      RenderRepaintBoundary? boundary = _repaintKey.currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      return null;
    }
  }

  Future<void> _saveToGallery() async {
    await _triggerHaptic(HapticFeedbackType.medium);
    setState(() => _isProcessing = true);

    try {
      // Request permissions
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          final photosStatus = await Permission.photos.request();
          if (!photosStatus.isGranted) {
            _showSnackBar('Storage permission required to save image', isError: true);
            setState(() => _isProcessing = false);
            return;
          }
        }
      }

      final bytes = await _capturePng();
      if (bytes == null) {
        _showSnackBar('Failed to capture wallpaper custom layout', isError: true);
        setState(() => _isProcessing = false);
        return;
      }

      await Gal.putImageBytes(bytes, album: 'YBT Wallpaper');
      _showSnackBar('Wallpaper saved to gallery!');
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _setWallpaper(int location) async {
    await _triggerHaptic(HapticFeedbackType.medium);
    setState(() => _isProcessing = true);

    try {
      final bytes = await _capturePng();
      if (bytes == null) {
        _showSnackBar('Failed to capture edited image', isError: true);
        setState(() => _isProcessing = false);
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
          '${tempDir.path}/temp_wallpaper_${widget.wallpaper['id']}_${DateTime.now().millisecondsSinceEpoch}.png');
      await tempFile.writeAsBytes(bytes);

      final success = await _channel.invokeMethod('setWallpaper', {
        'filePath': tempFile.path,
        'location': location,
      });

      if (success == true) {
        _showSnackBar('Wallpaper applied successfully!');
      } else {
        _showSnackBar('Failed to set wallpaper', isError: true);
      }
    } catch (e) {
      _showSnackBar('Failed to apply: $e', isError: true);
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showSetAsSheet() {
    _triggerHaptic(HapticFeedbackType.light);
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Set Wallpaper As',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _setWallpaper(1); // Home Screen
                },
                icon: const Icon(Icons.home_rounded),
                label: const Text('Home Screen'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _setWallpaper(2); // Lock Screen
                },
                icon: const Icon(Icons.lock_rounded),
                label: const Text('Lock Screen'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _setWallpaper(3); // Both Screens
                },
                icon: const Icon(Icons.phonelink_setup_rounded),
                label: const Text('Home & Lock Screens'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFEF4444) : Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Customize Wallpaper',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Preview Box
              Expanded(
                flex: 5,
                child: Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.4 : 0.1),
                        blurRadius: 15,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: RepaintBoundary(
                      key: _repaintKey,
                      child: Container(
                        color: Colors.black,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ColorFiltered(
                              colorFilter: ColorFilter.matrix(
                                  _brightnessMatrix(_brightness)),
                              child: ColorFiltered(
                                colorFilter: _isGrayscale
                                    ? const ColorFilter.matrix(_grayscaleMatrix)
                                    : const ColorFilter.mode(
                                        Colors.transparent, BlendMode.dst),
                                child: ImageFiltered(
                                  imageFilter: ui.ImageFilter.blur(
                                      sigmaX: _blur, sigmaY: _blur),
                                  child: InteractiveViewer(
                                    minScale: 0.5,
                                    maxScale: 3.0,
                                    child: CachedNetworkImage(
                                      imageUrl: widget.wallpaper['file_url'] ?? '',
                                      fit: _fitMode,
                                      placeholder: (ctx, url) => Center(
                                        child: CircularProgressIndicator(
                                          valueColor:
                                              AlwaysStoppedAnimation(Theme.of(context).colorScheme.primary),
                                        ),
                                      ),
                                      errorWidget: (ctx, url, err) => const Center(
                                        child: Icon(Icons.error, color: Colors.red),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Editing Panel
              Expanded(
                flex: 4,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -3),
                      )
                    ],
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Fit Mode selector row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Fitting Mode',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Row(
                              children: [
                                _fitButton('Fill', BoxFit.cover),
                                const SizedBox(width: 8),
                                _fitButton('Fit', BoxFit.contain),
                                const SizedBox(width: 8),
                                _fitButton('Center', BoxFit.none),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Blur Slider
                        Row(
                          children: [
                            const Icon(Icons.blur_on_rounded, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'Blur',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            Expanded(
                              child: Slider(
                                value: _blur,
                                min: 0.0,
                                max: 15.0,
                                activeColor: Theme.of(context).colorScheme.primary,
                                onChanged: (v) => setState(() => _blur = v),
                              ),
                            ),
                            Text('${_blur.toStringAsFixed(1)}px'),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Brightness Slider
                        Row(
                          children: [
                            const Icon(Icons.brightness_medium_rounded, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'Brightness',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            Expanded(
                              child: Slider(
                                value: _brightness,
                                min: -0.5,
                                max: 0.5,
                                activeColor: Theme.of(context).colorScheme.primary,
                                onChanged: (v) => setState(() => _brightness = v),
                              ),
                            ),
                            Text('${(_brightness * 100).toStringAsFixed(0)}%'),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Grayscale Toggle
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Row(
                            children: [
                              Icon(Icons.color_lens_outlined, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Grayscale (B&W)',
                                style: TextStyle(
                                    fontWeight: FontWeight.w500, fontSize: 14),
                              ),
                            ],
                          ),
                          value: _isGrayscale,
                          activeThumbColor: Theme.of(context).colorScheme.primary,
                          onChanged: (v) => setState(() => _isGrayscale = v),
                        ),
                        const SizedBox(height: 16),

                        // Save and Apply Row
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _isProcessing ? null : _saveToGallery,
                                icon: const Icon(Icons.save_alt_rounded),
                                label: const Text('Save to Gallery'),
                                style: OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  side: BorderSide(color: Theme.of(context).colorScheme.primary),
                                  foregroundColor: Theme.of(context).colorScheme.primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _isProcessing ? null : _showSetAsSheet,
                                icon: const Icon(Icons.wallpaper_rounded),
                                label: const Text('Set As'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),),
                ),
              ),
            ],
          ),
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation(Theme.of(context).colorScheme.primary),
                        ),
                        const SizedBox(width: 16),
                        const Text(
                          'Applying effects...',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _fitButton(String label, BoxFit mode) {
    final isSelected = _fitMode == mode;
    return GestureDetector(
      onTap: () {
        _triggerHaptic(HapticFeedbackType.light);
        setState(() => _fitMode = mode);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : null,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

enum HapticFeedbackType { light, medium }
