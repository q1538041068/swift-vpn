import 'dart:math' as math;
import 'package:flutter/material.dart';

class TrafficChart extends StatefulWidget {
  final Stream<({int upload, int download})> statsStream;

  const TrafficChart({super.key, required this.statsStream});

  @override
  State<TrafficChart> createState() => _TrafficChartState();
}

class _TrafficChartState extends State<TrafficChart> {
  final List<({int upload, int download})> _history = [];
  int _lastUpload = 0;
  int _lastDownload = 0;
  int _uploadSpeed = 0;
  int _downloadSpeed = 0;
  int _totalUpload = 0;
  int _totalDownload = 0;

  @override
  void initState() {
    super.initState();
    widget.statsStream.listen((stats) {
      setState(() {
        final du = stats.upload - _lastUpload;
        final dd = stats.download - _lastDownload;
        _uploadSpeed = du < 0 ? 0 : du;
        _downloadSpeed = dd < 0 ? 0 : dd;
        _lastUpload = stats.upload;
        _lastDownload = stats.download;
        _totalUpload = stats.upload;
        _totalDownload = stats.download;

        _history.add((upload: _uploadSpeed, download: _downloadSpeed));
        if (_history.length > 60) _history.removeAt(0);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Speed display
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _SpeedIndicator(
              label: '下载',
              speed: _downloadSpeed,
              color: const Color(0xFF42A5F5),
              icon: Icons.arrow_downward,
            ),
            Container(
              width: 1,
              height: 48,
              color: Colors.grey.withValues(alpha: 0.2),
            ),
            _SpeedIndicator(
              label: '上传',
              speed: _uploadSpeed,
              color: const Color(0xFF66BB6A),
              icon: Icons.arrow_upward,
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Mini chart
        if (_history.isNotEmpty)
          SizedBox(
            height: 60,
            child: CustomPaint(
              size: Size.infinite,
              painter: _ChartPainter(
                uploads: _history.map((h) => h.upload).toList(),
                downloads: _history.map((h) => h.download).toList(),
              ),
            ),
          ),
        const SizedBox(height: 8),
        // Total usage
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.data_usage, size: 14, color: Colors.grey.shade500),
            const SizedBox(width: 4),
            Text(
              '总计: ↓${_formatBytes(_totalDownload)}  ↑${_formatBytes(_totalUpload)}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ),
      ],
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

class _SpeedIndicator extends StatelessWidget {
  final String label;
  final int speed;
  final Color color;
  final IconData icon;

  const _SpeedIndicator({
    required this.label,
    required this.speed,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _formatSpeed(speed),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  String _formatSpeed(int bytesPerSec) {
    if (bytesPerSec < 1024) return '$bytesPerSec B/s';
    if (bytesPerSec < 1024 * 1024) {
      return '${(bytesPerSec / 1024).toStringAsFixed(1)} K/s';
    }
    return '${(bytesPerSec / (1024 * 1024)).toStringAsFixed(1)} M/s';
  }
}

class _ChartPainter extends CustomPainter {
  final List<int> uploads;
  final List<int> downloads;

  _ChartPainter({required this.uploads, required this.downloads});

  @override
  void paint(Canvas canvas, Size size) {
    if (uploads.isEmpty) return;

    final maxUpload = uploads.reduce(math.max).toDouble();
    final maxDownload = downloads.reduce(math.max).toDouble();
    final maxVal = math.max(maxUpload, math.max(maxDownload, 1.0));

    final uploadPaint = Paint()
      ..color = const Color(0xFF66BB6A)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final downloadPaint = Paint()
      ..color = const Color(0xFF42A5F5)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final dx = size.width / (uploads.length - 1).clamp(1, 1000);

    for (int i = 0; i < uploads.length - 1; i++) {
      final x1 = i * dx;
      final x2 = (i + 1) * dx;
      final y1u = size.height - (uploads[i] / maxVal * size.height);
      final y2u = size.height - (uploads[i + 1] / maxVal * size.height);
      canvas.drawLine(Offset(x1, y1u), Offset(x2, y2u), uploadPaint);

      final y1d = size.height - (downloads[i] / maxVal * size.height);
      final y2d = size.height - (downloads[i + 1] / maxVal * size.height);
      canvas.drawLine(Offset(x1, y1d), Offset(x2, y2d), downloadPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) => true;
}
