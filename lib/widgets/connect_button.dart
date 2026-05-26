import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:vpn_client/services/vpn_service.dart';

class ConnectButton extends StatefulWidget {
  final VpnState state;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  const ConnectButton({
    super.key,
    required this.state,
    required this.onConnect,
    required this.onDisconnect,
  });

  @override
  State<ConnectButton> createState() => _ConnectButtonState();
}

class _ConnectButtonState extends State<ConnectButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.9, end: 1.05).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isActive = widget.state == VpnState.connected ||
        widget.state == VpnState.connecting;

    return GestureDetector(
      onTap: isActive ? widget.onDisconnect : widget.onConnect,
      child: AnimatedBuilder(
        animation: _pulseAnim,
        builder: (context, child) {
          final scale =
              widget.state == VpnState.connecting ? _pulseAnim.value : 1.0;
          return Transform.scale(
            scale: scale,
            child: child,
          );
        },
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _backgroundColor,
            boxShadow: [
              BoxShadow(
                color: _backgroundColor.withValues(alpha: 0.4),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(child: _buildContent()),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (widget.state) {
      case VpnState.connected:
        return const Icon(Icons.shield, color: Colors.white, size: 48);
      case VpnState.connecting:
        return const SizedBox(
          width: 48,
          height: 48,
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 3,
          ),
        );
      case VpnState.disconnecting:
        return const SizedBox(
          width: 48,
          height: 48,
          child: CircularProgressIndicator(
            color: Colors.white70,
            strokeWidth: 3,
          ),
        );
      case VpnState.error:
        return const Icon(Icons.error_outline, color: Colors.white, size: 48);
      case VpnState.disconnected:
        return const Icon(Icons.power_settings_new,
            color: Colors.white, size: 48);
    }
  }

  Color get _backgroundColor {
    switch (widget.state) {
      case VpnState.connected:
        return const Color(0xFF4CAF50);
      case VpnState.connecting:
        return const Color(0xFFFFA726);
      case VpnState.disconnecting:
        return Colors.orange.shade300;
      case VpnState.error:
        return const Color(0xFFEF5350);
      case VpnState.disconnected:
        return Colors.grey.shade400;
    }
  }
}
