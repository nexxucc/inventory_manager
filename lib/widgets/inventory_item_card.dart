import 'package:flutter/material.dart';
import '../models/inventory_item.dart';

typedef ItemTapCallback = void Function();
typedef ItemDeleteCallback = void Function();

class InventoryItemCard extends StatefulWidget {
  final InventoryItem item;
  final ItemTapCallback? onTap;
  final ItemDeleteCallback? onDelete;

  const InventoryItemCard({
    Key? key,
    required this.item,
    this.onTap,
    this.onDelete,
  }) : super(key: key);

  @override
  State<InventoryItemCard> createState() => _InventoryItemCardState();
}

class _InventoryItemCardState extends State<InventoryItemCard> {
  // For brief flash animation if desired:
  bool _flashHighlight = false;

  @override
  void didUpdateWidget(covariant InventoryItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If quantity crossed below lowThreshold, you could trigger a flash.
    final oldQty = oldWidget.item.quantity;
    final newQty = widget.item.quantity;
    final lowThreshold = widget.item.lowStockThreshold;
    if (lowThreshold != null &&
        oldQty > lowThreshold &&
        newQty <= lowThreshold) {
      _triggerFlash();
    }
  }

  void _triggerFlash() {
    setState(() {
      _flashHighlight = true;
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() {
          _flashHighlight = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Determine base background color based on stock thresholds
    Color baseColor = Colors.white;
    final lowThreshold = widget.item.lowStockThreshold;
    final qty = widget.item.quantity;
    if (lowThreshold != null && qty <= lowThreshold) {
      baseColor = Theme.of(context).colorScheme.error.withOpacity(0.1);
    }
    // If flashing highlight, override
    final bgColor = _flashHighlight
        ? Theme.of(context).colorScheme.error.withOpacity(0.3)
        : baseColor;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              children: [
                // Optional leading avatar with first letter
                CircleAvatar(
                  backgroundColor:
                      Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  child: Text(
                    widget.item.name.isNotEmpty
                        ? widget.item.name[0].toUpperCase()
                        : '',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Main info: name and quantity (and low threshold if present)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.item.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Qty: ${widget.item.quantity}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (widget.item.lowStockThreshold != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Low threshold: ${widget.item.lowStockThreshold}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                      ],
                    ],
                  ),
                ),
                // Delete button if provided
                if (widget.onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    color: Theme.of(context).colorScheme.error,
                    onPressed: widget.onDelete,
                    tooltip: 'Delete',
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
