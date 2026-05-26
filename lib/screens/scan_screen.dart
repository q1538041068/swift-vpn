import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:vpn_client/models/proxy_node.dart';
import 'package:vpn_client/utils/link_parser.dart';

class ScanScreen extends StatefulWidget {
  final void Function(ProxyNode node) onScanned;

  const ScanScreen({super.key, required this.onScanned});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  MobileScannerController? _controller;
  bool _scanned = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('扫描二维码',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(Icons.flash_on,
                color: _controller?.torchEnabled == true ? Colors.yellow : null),
            onPressed: () => _controller?.toggleTorch(),
            tooltip: '手电筒',
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_android),
            onPressed: () => _controller?.switchCamera(),
            tooltip: '翻转摄像头',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                ),
                // Scan overlay
                Center(
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _scanned ? Colors.green : Colors.white,
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                if (_scanned)
                  Center(
                    child: Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Icon(Icons.check_circle,
                            color: Colors.green, size: 64),
                      ),
                    ),
                  ),
                if (_error != null)
                  Positioned(
                    bottom: 24,
                    left: 24,
                    right: 24,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Tip
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Column(
              children: [
                const Icon(Icons.qr_code, size: 24, color: Colors.grey),
                const SizedBox(height: 8),
                Text(
                  '将 ss:// 或 vmess:// 二维码放入框内自动识别',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    final link = barcode.rawValue!.trim();
    if (!link.startsWith('ss://') && !link.startsWith('vmess://')) return;

    final node = LinkParser.parse(link);
    if (node == null) {
      setState(() {
        _error = '无法识别该二维码内容';
        _scanned = true;
      });
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _scanned = false;
            _error = null;
          });
        }
      });
      return;
    }

    setState(() => _scanned = true);

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        widget.onScanned(node);
        Navigator.pop(context);
      }
    });
  }
}
