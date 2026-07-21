// lib/screens/notifications/notifications_screen.dart
//
// Phase 4 - نظام الإشعارات: صفحة كاملة تعرض كل إشعارات المستخدم الحالي
// (أي دور) - عنوان/محتوى/تاريخ ووقت/حالة قراءة، الأحدث فالأقدم. الضغط على
// إشعار يعلّمه مقروء وبيفتح الشاشة المناسبة حسب نوعه ودور المستخدم الحالي.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_themes.dart';
import '../../data/models/notification_model.dart';
import '../../data/models/offer_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../services/order_service.dart';
import '../business/business_dashboard_screen.dart';
import '../admin/admin_dashboard_screen.dart';
import '../driver/active_delivery_screen.dart';
import '../driver/group_delivery_screen.dart';
import '../driver/smart_offer_dialog.dart';
import '../orders/order_tracking_screen.dart';
import '../loyalty/loyalty_screen.dart';
import '../../core/i18n/app_localizations.dart';
import '../../widgets/main_layout.dart';
import '../../widgets/role_drawer.dart';
import '../../widgets/app_card.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  static const Color brandColor = AppColors.brand;
  final _orderService = OrderService();

  @override
  void initState() {
    super.initState();
    // ✅ منجدد القائمة وقت فتح الشاشة (مش بس أول مرة بالتطبيق) عشان تكون
    // محدّثة فعليًا حتى لو كانت loadInitial انعملت من قبل بمكان تاني
    ref.read(notificationProvider.notifier).refresh();
  }

  Future<void> _handleTap(NotificationModel n) async {
    ref.read(notificationProvider.notifier).markRead(n.id);
    final role = ref.read(authProvider).user?.role;

    switch (n.type) {
      case 'OrderStatus':
        if (n.relatedId == null) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OrderTrackingScreen(orderId: n.relatedId!),
          ),
        );
        break;

      case 'NewOrder':
        if (role == 'Restaurant') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BusinessDashboardScreen()),
          );
        }
        break;

      case 'SmartAssignmentOffer':
        await _openPendingOffer();
        break;

      case 'AdminApproval':
        if (role == 'Admin') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
          );
        } else if (role == 'Restaurant') {
          // ✅ نفس الإشعار نوعًا بيوصل لصاحب متجر (موافقة/رفض متجره) - قبل
          // هيك ما كان في أي تعامل غير Admin، فالضغط ما كان يفتح شي إطلاقًا
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BusinessDashboardScreen()),
          );
        }
        break;

      case 'LoyaltyEarned':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LoyaltyScreen()),
        );
        break;

      case 'NewReview':
      case 'UserStatus':
      default:
        // إعلامي فقط - ما في شاشة مخصّصة تُفتح
        break;
    }
  }

  // ✅ عرض التعيين الذكي ممكن يكون خلص وقته لحد ما السائق ضغط على الإشعار -
  // منتحقق من وجوده فعليًا (getMyPendingOffer) قبل ما نعرض نافذة القبول/الرفض
  Future<void> _openPendingOffer() async {
    final result = await _orderService.getMyPendingOffer();
    if (!mounted) return;
    if (result.offer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.t(Localizations.localeOf(context), 'notifications_offer_expired'),
          ),
        ),
      );
      return;
    }
    final offer = result.offer!;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => SmartOfferDialog(
        offer: offer,
        onAccept: () => _respondToOffer(offer, 'accept'),
        onReject: () => _respondToOffer(offer, 'reject'),
      ),
    );
  }

  Future<bool> _respondToOffer(DeliveryOfferModel offer, String action) async {
    final result = await respondToDeliveryOffer(_orderService, offer, action);

    if (!mounted) return true;

    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.message.isNotEmpty
                ? result.message
                : AppLocalizations.t(Localizations.localeOf(context), 'notifications_generic_error'),
          ),
        ),
      );
      return result.code == 'EXPIRED' || result.code == 'NOT_OFFERED';
    }

    if (action == 'accept') {
      if (offer.isGroup) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => GroupDeliveryScreen(groupId: offer.respondTargetId),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ActiveDeliveryScreen(orderId: offer.respondTargetId),
          ),
        );
      }
    }
    return true;
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'OrderStatus':
        return Icons.local_shipping_outlined;
      case 'NewOrder':
        return Icons.receipt_long_outlined;
      case 'SmartAssignmentOffer':
        return Icons.bolt;
      case 'UserStatus':
        return Icons.verified_user_outlined;
      case 'AdminApproval':
        return Icons.storefront_outlined;
      case 'NewReview':
        return Icons.star_outline;
      case 'LoyaltyEarned':
        return Icons.stars_outlined;
      default:
        return Icons.notifications_none_outlined;
    }
  }

  String _relativeTime(Locale locale, DateTime at) {
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 1) return AppLocalizations.t(locale, 'notifications_time_now');
    if (diff.inMinutes < 60) {
      return AppLocalizations.t(locale, 'notifications_time_minutes').replaceFirst('{n}', '${diff.inMinutes}');
    }
    if (diff.inHours < 24) {
      return AppLocalizations.t(locale, 'notifications_time_hours').replaceFirst('{n}', '${diff.inHours}');
    }
    if (diff.inDays < 7) {
      return AppLocalizations.t(locale, 'notifications_time_days').replaceFirst('{n}', '${diff.inDays}');
    }
    return '${at.year}-${at.month.toString().padLeft(2, '0')}-${at.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authProvider).user?.role;

    // ✅ هاد الشاشة مشتركة بين كل الأدوار (Customer/Restaurant/Driver/Admin) -
    // الهيدر الموحّد الجديد (MainLayout/AppHeader) مبني خصيصًا للزبون (سلة،
    // "طلباتي"...) فما لازم يظهر لغير الأدوار التانية. لوحات Admin/Driver/
    // Business لازم تضل بنفس AppBar+Drawer الحالي تمامًا بدون أي تغيير.
    if (role == 'Customer') {
      return MainLayout(
        builder: (context, isWeb, padding, width) =>
            _buildCustomerBody(context, padding),
      );
    }

    final locale = Localizations.localeOf(context);
    final drawer = roleDrawerFor(role);
    return Scaffold(
      drawer: drawer,
      appBar: AppBar(
        title: Text(AppLocalizations.t(locale, 'drawer_notifications')),
        backgroundColor: Theme.of(context).cardColor,
        foregroundColor: Theme.of(context).textTheme.bodyLarge?.color,
        elevation: 0,
        actions: [
          if (ref.watch(notificationProvider).unreadCount > 0)
            TextButton(
              onPressed: () =>
                  ref.read(notificationProvider.notifier).markAllRead(),
              child: Text(
                AppLocalizations.t(locale, 'notifications_mark_all_read'),
                style: TextStyle(
                  color: brandColor,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (drawer != null)
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
        ],
      ),
      body: _buildList(locale: locale, padding: 14),
    );
  }

  /// جسم الشاشة لغير الزبون - نفس الـ ListView الأصلي بدون أي تعديل
  /// (AppBar بره هاد الدالة بيتكفّل بالعنوان وزر "تعليم الكل كمقروء").
  Widget _buildList({required Locale locale, required double padding}) {
    final state = ref.watch(notificationProvider);
    return state.isLoading && state.items.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : state.items.isEmpty
        ? Center(
            child: Text(
              AppLocalizations.t(locale, 'notifications_empty'),
              style: TextStyle(color: Colors.grey[600]),
            ),
          )
        : RefreshIndicator(
            onRefresh: () => ref.read(notificationProvider.notifier).refresh(),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: padding, vertical: 10),
              itemCount: state.items.length,
              itemBuilder: (context, index) => _buildRow(locale, state.items[index]),
            ),
          );
  }

  /// جسم الشاشة للزبون فقط (داخل MainLayout) - نفس المحتوى + عنوان صفحة
  /// وزر "تعليم الكل كمقروء" بالمكان اللي كان AppBar.actions يعرضهم فيه سابقًا.
  Widget _buildCustomerBody(BuildContext context, double padding) {
    final state = ref.watch(notificationProvider);
    final locale = Localizations.localeOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(padding, 16, padding, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppLocalizations.t(locale, 'drawer_notifications'),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              if (state.unreadCount > 0)
                TextButton(
                  onPressed: () =>
                      ref.read(notificationProvider.notifier).markAllRead(),
                  child: Text(
                    AppLocalizations.t(locale, 'notifications_mark_all_read'),
                    style: TextStyle(
                      color: brandColor,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(child: _buildList(locale: locale, padding: padding)),
      ],
    );
  }

  Widget _buildRow(Locale locale, NotificationModel n) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        color: n.isRead ? null : brandColor.withValues(alpha: 0.06),
        onTap: () => _handleTap(n),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: brandColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(_iconFor(n.type), color: brandColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n.title,
                    style: TextStyle(
                      fontWeight: n.isRead ? FontWeight.w600 : FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    n.body,
                    style: TextStyle(fontSize: 12.5, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _relativeTime(locale, n.createdAt),
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            if (!n.isRead) ...[
              const SizedBox(width: 6),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
