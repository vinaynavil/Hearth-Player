import 'dart:async';
import 'package:flutter/material.dart';

import '../services/update_service.dart';

/// Standalone authentic Windows 11 styled dialog for notifying the user
/// of an available app update with Update, Hide for 24 Hours, and Cancel actions.
class WindowsUpdateDialog extends StatefulWidget {
  final UpdateInfo updateInfo;
  final UpdateService updateService;

  const WindowsUpdateDialog({
    super.key,
    required this.updateInfo,
    required this.updateService,
  });

  /// Displays the update dialog in a non-dismissible modal.
  static Future<void> show(
    BuildContext context,
    UpdateInfo info,
    UpdateService service,
  ) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (_) => WindowsUpdateDialog(
        updateInfo: info,
        updateService: service,
      ),
    );
  }

  @override
  State<WindowsUpdateDialog> createState() => _WindowsUpdateDialogState();
}

class _WindowsUpdateDialogState extends State<WindowsUpdateDialog> {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String? _errorMessage;
  bool _isCloseHovered = false;

  Future<void> _startUpdate() async {
    if (_isDownloading) return;
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _errorMessage = null;
    });

    try {
      await widget.updateService.downloadAndInstallUpdate(
        widget.updateInfo,
        onProgress: (double p) {
          if (!mounted) return;
          setState(() {
            _downloadProgress = p;
          });
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isDownloading = false;
        _errorMessage = 'Download failed: $e';
      });
    }
  }

  Future<void> _hideFor24Hours() async {
    if (_isDownloading) return;
    await widget.updateService.snoozeFor24Hours();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  void _dismissDialog() {
    if (_isDownloading) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 460,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFF888888),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // -------------------------------------------------------------
            // Windows 11 Native Title Bar
            // -------------------------------------------------------------
            Container(
              height: 32,
              color: const Color(0xFFF3F3F3),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.system_update_alt,
                    size: 16,
                    color: Color(0xFF0067C0),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Hearth Update',
                    style: TextStyle(
                      fontFamily: 'Segoe UI',
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const Spacer(),
                  MouseRegion(
                    cursor: _isDownloading
                        ? SystemMouseCursors.basic
                        : SystemMouseCursors.click,
                    onEnter: (_) {
                      if (!_isDownloading && mounted) {
                        setState(() => _isCloseHovered = true);
                      }
                    },
                    onExit: (_) {
                      if (mounted) setState(() => _isCloseHovered = false);
                    },
                    child: GestureDetector(
                      onTap: _dismissDialog,
                      child: Container(
                        width: 46,
                        height: 32,
                        color: _isCloseHovered && !_isDownloading
                            ? const Color(0xFFE81123)
                            : Colors.transparent,
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: _isCloseHovered && !_isDownloading
                              ? Colors.white
                              : (_isDownloading
                                  ? const Color(0xFFAAAAAA)
                                  : const Color(0xFF1A1A1A)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // -------------------------------------------------------------
            // Main Content Area
            // -------------------------------------------------------------
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'A new version of Hearth is available',
                    style: TextStyle(
                      fontFamily: 'Segoe UI',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF005FB8),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Hearth ${widget.updateInfo.latestVersion} is ready to install '
                    '(installed version: ${UpdateService.currentVersion}).',
                    style: const TextStyle(
                      fontFamily: 'Segoe UI',
                      fontSize: 12.5,
                      color: Color(0xFF505050),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'What\'s new in this version:',
                    style: TextStyle(
                      fontFamily: 'Segoe UI',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 130,
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9F9F9),
                      border: Border.all(
                        color: const Color(0xFFDADADA),
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        widget.updateInfo.releaseNotes,
                        style: const TextStyle(
                          fontFamily: 'Segoe UI',
                          fontSize: 12.5,
                          color: Color(0xFF2B2B2B),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),

                  // Download Progress & Error Section
                  if (_isDownloading || _errorMessage != null) ...[
                    const SizedBox(height: 14),
                    if (_isDownloading) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Downloading update package... '
                            '${(_downloadProgress * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                              fontFamily: 'Segoe UI',
                              fontSize: 12,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: _downloadProgress > 0 ? _downloadProgress : null,
                        minHeight: 6,
                        backgroundColor: const Color(0xFFE5E5E5),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF0067C0),
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ],
                    if (_errorMessage != null) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            fontFamily: 'Segoe UI',
                            fontSize: 12,
                            color: Color(0xFFC42B1C),
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),

            // -------------------------------------------------------------
            // Windows 11 Native Bottom Command Bar
            // -------------------------------------------------------------
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFF3F3F3),
                border: Border(
                  top: BorderSide(
                    color: Color(0xFFE5E5E5),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Hide for 24 Hours
                  _WindowsButton(
                    label: 'Hide for 24 hours',
                    enabled: !_isDownloading,
                    onPressed: _hideFor24Hours,
                  ),
                  const Spacer(),
                  // Update (Primary Blue)
                  _WindowsButton(
                    label: _isDownloading ? 'Updating...' : 'Update',
                    isPrimary: true,
                    minWidth: 88,
                    enabled: !_isDownloading,
                    onPressed: _startUpdate,
                  ),
                  const SizedBox(width: 8),
                  // Cancel
                  _WindowsButton(
                    label: 'Cancel',
                    minWidth: 80,
                    enabled: !_isDownloading,
                    onPressed: _dismissDialog,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A native Windows 11 system button with standard hover states and borders.
class _WindowsButton extends StatefulWidget {
  final String label;
  final bool isPrimary;
  final double? minWidth;
  final bool enabled;
  final VoidCallback onPressed;

  const _WindowsButton({
    required this.label,
    this.isPrimary = false,
    this.minWidth,
    this.enabled = true,
    required this.onPressed,
  });

  @override
  State<_WindowsButton> createState() => _WindowsButtonState();
}

class _WindowsButtonState extends State<_WindowsButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final bool primary = widget.isPrimary;
    final bool enabled = widget.enabled;

    Color bg;
    Color border;
    Color textColor;

    if (primary) {
      if (!enabled) {
        bg = const Color(0xFF7FAED6);
        border = const Color(0xFF7FAED6);
        textColor = Colors.white.withValues(alpha: 0.8);
      } else if (_isHovered) {
        bg = const Color(0xFF005BA1);
        border = const Color(0xFF005BA1);
        textColor = Colors.white;
      } else {
        bg = const Color(0xFF0067C0);
        border = const Color(0xFF005BA1);
        textColor = Colors.white;
      }
    } else {
      if (!enabled) {
        bg = const Color(0xFFFBFBFB);
        border = const Color(0xFFE0E0E0);
        textColor = const Color(0xFFAAAAAA);
      } else if (_isHovered) {
        bg = const Color(0xFFF0F0F0);
        border = const Color(0xFFB8B8B8);
        textColor = const Color(0xFF1A1A1A);
      } else {
        bg = const Color(0xFFFBFBFB);
        border = const Color(0xFFCCCCCC);
        textColor = const Color(0xFF1A1A1A);
      }
    }

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) {
        if (enabled && mounted) setState(() => _isHovered = true);
      },
      onExit: (_) {
        if (mounted) setState(() => _isHovered = false);
      },
      child: GestureDetector(
        onTap: enabled ? widget.onPressed : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          height: 30,
          constraints: widget.minWidth != null
              ? BoxConstraints(minWidth: widget.minWidth!)
              : null,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: border, width: 1),
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: TextStyle(
              fontFamily: 'Segoe UI',
              fontSize: 12.5,
              fontWeight: primary ? FontWeight.w600 : FontWeight.w400,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}
