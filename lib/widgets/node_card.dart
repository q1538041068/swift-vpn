import 'package:flutter/material.dart';
import 'package:vpn_client/models/proxy_node.dart';

class NodeCard extends StatelessWidget {
  final ProxyNode node;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onFavorite;
  final VoidCallback? onDelete;

  const NodeCard({
    super.key,
    required this.node,
    this.isSelected = false,
    this.onTap,
    this.onFavorite,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: isSelected ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(
                color: Theme.of(context).colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _buildTypeIcon(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            node.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _buildLatencyBadge(),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${node.address}:${node.port}  ${node.type.name.toUpperCase()}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    if (node.remarks != null && node.remarks!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          node.remarks!,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              if (onFavorite != null)
                IconButton(
                  icon: Icon(
                    node.isFavorite ? Icons.star : Icons.star_border,
                    color: node.isFavorite ? Colors.amber : Colors.grey,
                    size: 22,
                  ),
                  onPressed: onFavorite,
                ),
              if (onDelete != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: Colors.grey,
                  onPressed: onDelete,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeIcon() {
    IconData icon;
    Color color;
    switch (node.type) {
      case ProxyType.shadowsocks:
        icon = Icons.cloud;
        color = const Color(0xFF42A5F5);
        break;
      case ProxyType.vmess:
        icon = Icons.flash_on;
        color = const Color(0xFFAB47BC);
        break;
      case ProxyType.trojan:
        icon = Icons.shield;
        color = const Color(0xFF66BB6A);
        break;
      default:
        icon = Icons.language;
        color = Colors.grey;
    }
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }

  Widget _buildLatencyBadge() {
    Color color;
    switch (node.status) {
      case NodeStatus.ok:
        color = const Color(0xFF4CAF50);
        break;
      case NodeStatus.slow:
        color = const Color(0xFFFFA726);
        break;
      case NodeStatus.timeout:
        color = const Color(0xFFEF5350);
        break;
      case NodeStatus.unknown:
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        node.displayLatency,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
