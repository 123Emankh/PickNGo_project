// lib/screens/orders/order_details_dialog.dart
//
// نافذة "تفاصيل الطلب" الكاملة: كل بيانات OrderModel (زي ما بيرجعها getMyOrders)
// بمكان واحد - قائمة المنتجات كاملة (مش أول 2 بس زي الكارد)، عنوان التوصيل،
// طلبات خاصة، طريقة/حالة الدفع، وتفصيل السعر. كل البيانات موجودة أصلاً
// بـ OrderModel المحمّل بشاشة My Orders - ما في نداء شبكة إضافي.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/order_model.dart';
import '../../core/constants/api_constants.dart';
import '../../core/theme/app_themes.dart';

class OrderDetailsDialog extends StatelessWidget {
  final OrderModel order;

  const OrderDetailsDialog({super.key, required this.order});

  static const Color brandColor = AppColors.brand;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'تفاصيل الطلب',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            order.orderNumber,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          _statusBadge(context),
                        ],
                      ),
                      if (order.orderTime != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('d MMM y, h:mm a', 'en_US').format(order.orderTime!.toLocal()),
                              style: TextStyle(color: Colors.grey[500], fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                      if (order.storeName != null) ...[
                        const SizedBox(height: 14),
                        _sectionTitle('المتجر'),
                        const SizedBox(height: 6),
                        Text(order.storeName!, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                        if ((order.storeAddress ?? order.storeCity) != null) ...[
                          const SizedBox(height: 3),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.storefront_outlined, size: 14, color: Colors.grey[500]),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  order.storeAddress ?? order.storeCity!,
                                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                      const SizedBox(height: 14),
                      _sectionTitle('المنتجات (${order.items.length})'),
                      const SizedBox(height: 6),
                      ...order.items.map(_buildItemRow),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Divider(height: 1),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.location_on_outlined, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              order.deliveryAddress,
                              style: TextStyle(color: Colors.grey[700], fontSize: 12.5),
                            ),
                          ),
                        ],
                      ),
                      if (order.specialInstructions != null && order.specialInstructions!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.note_outlined, size: 14, color: Colors.grey[500]),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                order.specialInstructions!,
                                style: TextStyle(color: Colors.grey[700], fontSize: 12.5),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.payments_outlined, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            '${order.paymentMethod} · ${order.paymentStatus}',
                            style: TextStyle(color: Colors.grey[700], fontSize: 12.5),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Divider(height: 1),
                      ),
                      _priceRow('المجموع', order.totalAmount),
                      _priceRow('رسوم التوصيل', order.deliveryFee),
                      if (order.discount > 0) _priceRow('الخصم', -order.discount),
                      const SizedBox(height: 4),
                      _priceRow('الإجمالي', order.finalAmount, bold: true),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5, letterSpacing: 0.3, color: brandColor),
    );
  }

  Widget _statusBadge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: brandColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        order.status,
        style: const TextStyle(color: brandColor, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildItemRow(OrderItemModel item) {
    final url = ApiConstants.resolveImageUrl(item.imageUrl);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              width: 34,
              height: 34,
              color: Colors.grey.shade200,
              child: url != null
                  ? Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.fastfood_outlined, size: 16, color: Colors.grey),
                    )
                  : const Icon(Icons.fastfood_outlined, size: 16, color: Colors.grey),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text('${item.quantity}x ${item.name}', style: const TextStyle(fontSize: 12.5)),
          ),
          Text(
            '₪${item.subtotal.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _priceRow(String label, double amount, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: bold ? 14 : 12.5,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: bold ? null : Colors.grey[600],
            ),
          ),
          Text(
            '${amount < 0 ? '-' : ''}₪${amount.abs().toStringAsFixed(2)}',
            style: TextStyle(fontSize: bold ? 14 : 12.5, fontWeight: bold ? FontWeight.bold : FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
