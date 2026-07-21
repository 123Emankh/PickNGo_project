// lib/screens/checkout/checkout_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../data/models/cart_item_model.dart';
import '../../data/models/store_model.dart';
import '../../data/palestine_areas.dart';
import '../../services/store_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/location_provider.dart';
import '../../services/coupon_service.dart';
import '../../services/loyalty_service.dart';
import '../../services/order_service.dart';
import '../../services/payment_service.dart';
import '../../widgets/main_layout.dart';
import '../../widgets/location_picker_map.dart';
import '../../widgets/app_card.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_themes.dart';
import 'order_success_screen.dart';
import 'payment_webview_screen.dart';

const _cardPaymentMethods = {'CreditCard', 'DebitCard'};

class CheckoutScreen extends ConsumerStatefulWidget {
  // إضافة البارامترات المستلمة من صفحة السلة هنا
  final String storeName;
  final List<CartItem> checkoutItems;
  final double totalPrice;

  const CheckoutScreen({
    super.key,
    required this.storeName,
    required this.checkoutItems,
    required this.totalPrice,
  });

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  static const Color brandColor = AppColors.brand;

  final _addressController = TextEditingController();
  final _instructionsController = TextEditingController();
  final _couponController = TextEditingController();
  final _couponService = CouponService();
  final _pointsController = TextEditingController();
  final _loyaltyService = LoyaltyService();
  String _paymentMethod = 'Cash';
  // ✅ إلزامي - أساس حساب رسم التوصيل الصحيح (داخل المدينة/مدينة تانية/
  // مناطق محتلة)، راجع utils/deliveryFee.js بالباك إند. مش الإحداثيات -
  // هاي فقط للخريطة/تتبع السائق.
  String? _selectedCity;
  // ✅ بيانات المتجر (مدينة/منطقة/شرائح رسوم التوصيل) - تُجلب مرة وقت فتح
  // الشاشة، تُستخدم بس لعرض تقدير رسم التوصيل هون؛ السيرفر هو المصدر
  // الحقيقي والوحيد للحساب الفعلي وقت إنشاء الطلب (calculateDeliveryFee).
  StoreModel? _store;
  LatLng?
  _pickedLocation; // اختياري - بيحسّن دقة التوصيل وبيفعّل Grouped Delivery
  bool _isPlacingOrder = false;
  bool _isValidatingCoupon = false;
  String? _couponPreviewMessage;
  bool _couponPreviewSuccess = false;
  String? _errorMessage;

  // ✅ Loyalty: رصيد النقاط الحالي (يُجلب مرة وقت فتح الشاشة) - الاستبدال
  // الفعلي (وحسم الرصيد) بيصير سيرفر-سايد وقت إنشاء الطلب فقط، هون بس
  // لعرض/معاينة. بيُطبَّق على أول متجر بالسلة بس (نفس قيد كود الخصم أصلًا -
  // راجع _validateCoupon)، عشان ما يصير استبدال مزدوج لنفس النقاط عبر أكتر
  // من طلب لو السلة فيها أكتر من متجر.
  int _pointsBalance = 0;
  bool _isPreviewingPoints = false;
  int? _pointsToRedeem;
  String? _pointsPreviewMessage;
  bool _pointsPreviewSuccess = false;

  static const List<String> _paymentMethodKeys = [
    'Cash',
    'CreditCard',
    'DebitCard',
    'Wallet',
  ];

  String _paymentLabel(BuildContext context, String key) {
    final locale = Localizations.localeOf(context);
    switch (key) {
      case 'Cash':
        return AppLocalizations.t(locale, 'checkout_payment_cash');
      case 'CreditCard':
        return AppLocalizations.t(locale, 'checkout_payment_credit_card');
      case 'DebitCard':
        return AppLocalizations.t(locale, 'checkout_payment_debit_card');
      case 'Wallet':
        return AppLocalizations.t(locale, 'checkout_payment_wallet');
      default:
        return key;
    }
  }

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    if (user?.locationAddress != null && user!.locationAddress!.isNotEmpty) {
      _addressController.text = user.locationAddress!;
    }

    // ✅ نحدد موقع التوصيل تلقائيًا من GPS الجهاز بدل ما نجبر الزبون يضغط
    // يدويًا على الخريطة كل مرة - نفس LocationService الصامتة المستخدمة أصلاً
    // لتوسيط الخريطة (userLocationProvider)، بس هلق بنعتمد نتيجتها كموقع
    // التوصيل الفعلي مباشرة. الزبون لسا يقدر يعدّل الدبوس يدويًا لو بدو
    // يوصّل لعنوان تاني غير موقعه الحالي - هاد بس بيلغي الخطوة الإجبارية.
    ref.read(userLocationProvider.future).then((location) {
      if (!mounted || location == null || _pickedLocation != null) return;
      setState(() => _pickedLocation = location);
    });

    _loyaltyService.getMyLoyalty().then((result) {
      if (!mounted || !result.success) return;
      setState(() => _pointsBalance = result.balance);
    });

    if (widget.checkoutItems.isNotEmpty) {
      final storeId = widget.checkoutItems.first.product.storeId;
      StoreService().getStoreDetail(storeId).then((result) {
        if (!mounted || !result.success) return;
        setState(() => _store = result.store);
      });
    }
  }

  // ✅ نفس منطق calculateDeliveryFee بالباك إند بالظبط (utils/deliveryFee.js)
  // - تقدير للعرض بس، السيرفر بيعيد نفس الحساب وقت إنشاء الطلب فعليًا.
  double? get _estimatedDeliveryFee {
    if (_store == null || _selectedCity == null) return null;
    final region = _selectedCity == occupiedArea
        ? 'Israel'
        : cityInfo[_selectedCity]?.$1;
    if (region == 'Israel') return _store!.deliveryFeeOccupiedAreas;
    if (_selectedCity == _store!.city && region == _store!.region) {
      return _store!.deliveryFeeInsideCity;
    }
    return _store!.deliveryFeeOutsideCity;
  }

  @override
  void dispose() {
    _addressController.dispose();
    _instructionsController.dispose();
    _couponController.dispose();
    _pointsController.dispose();
    super.dispose();
  }

  // ⚠️ نفس قيد الكوبون بالضبط - بتعاين/بتُطبَّق بس على أول متجر بالسلة
  Future<void> _validatePoints() async {
    final requested = int.tryParse(_pointsController.text.trim());
    if (requested == null || requested <= 0) return;

    if (requested > _pointsBalance) {
      setState(() {
        _pointsPreviewSuccess = false;
        _pointsPreviewMessage = AppLocalizations.t(
          Localizations.localeOf(context),
          'checkout_points_insufficient_balance',
        ).replaceFirst('{balance}', '$_pointsBalance');
        _pointsToRedeem = null;
      });
      return;
    }

    setState(() {
      _isPreviewingPoints = true;
      _pointsPreviewMessage = null;
    });

    final result = await _loyaltyService.previewRedemption(
      points: requested,
      cartTotal: widget.totalPrice,
    );

    if (!mounted) return;
    setState(() {
      _isPreviewingPoints = false;
      _pointsPreviewSuccess = result.success;
      if (result.success) {
        _pointsToRedeem = result.pointsRedeemed;
        _pointsPreviewMessage = AppLocalizations.t(
          Localizations.localeOf(context),
          'checkout_points_preview_success',
        ).replaceFirst('{amount}', result.discountAmount.toStringAsFixed(2));
      } else {
        _pointsToRedeem = null;
        _pointsPreviewMessage = result.message;
      }
    });
  }

  // ⚠️ بتعاين بس على أول متجر بالسلة - لو السلة فيها أكتر من متجر، الكود ممكن
  // ينطبق فعليًا على متجر تاني وقت تقديم الطلب الحقيقي (كل طلب بيتحقق لحاله بالباك إند)
  Future<void> _validateCoupon() async {
    final code = _couponController.text.trim();
    if (code.isEmpty) return;

    final grouped = _groupByStore(widget.checkoutItems);
    if (grouped.isEmpty) return;
    final firstEntry = grouped.entries.first;
    final storeId = firstEntry.value.first.product.storeId;
    final storeTotal = firstEntry.value.fold<double>(
      0,
      (sum, i) => sum + i.subtotal,
    );

    setState(() {
      _isValidatingCoupon = true;
      _couponPreviewMessage = null;
    });

    final result = await _couponService.validateCoupon(
      code: code,
      restaurantId: storeId,
      cartTotal: storeTotal,
    );

    if (!mounted) return;
    setState(() {
      _isValidatingCoupon = false;
      _couponPreviewSuccess = result.success;
      _couponPreviewMessage = result.success
          ? AppLocalizations.t(
              Localizations.localeOf(context),
              'checkout_coupon_valid',
            ).replaceFirst('{amount}', result.discountAmount.toStringAsFixed(2))
                .replaceFirst('{store}', firstEntry.value.first.storeName)
          : result.message;
    });
  }

  // دمج معالجة المتاجر لتقرأ من widget.checkoutItems بدلاً من السلة الكاملة
  Map<String, List<CartItem>> _groupByStore(List<CartItem> items) {
    final Map<String, List<CartItem>> grouped = {};
    for (final item in items) {
      final key = item.product.storeId.isNotEmpty
          ? item.product.storeId
          : item.storeName;
      grouped.putIfAbsent(key, () => []).add(item);
    }
    return grouped;
  }

  Future<void> _placeOrder() async {
    // نتحقق من العناصر الممررة لهذه الشاشة المحددة
    if (_addressController.text.trim().isEmpty) {
      setState(
        () => _errorMessage = AppLocalizations.t(
          Localizations.localeOf(context),
          'checkout_address_required',
        ),
      );
      return;
    }
    if (_selectedCity == null) {
      setState(
        () => _errorMessage = AppLocalizations.t(
          Localizations.localeOf(context),
          'checkout_city_required',
        ),
      );
      return;
    }
    if (widget.checkoutItems.isEmpty) {
      setState(
        () => _errorMessage = AppLocalizations.t(
          Localizations.localeOf(context),
          'checkout_items_empty',
        ),
      );
      return;
    }

    setState(() {
      _isPlacingOrder = true;
      _errorMessage = null;
    });

    // ✅ شبكة أمان: لو الزبون ضغط "إتمام الطلب" بسرعة قبل ما GPS يخلص (نادر -
    // initState بدأ الطلب أصلاً بس ممكن ياخد لحظات) - نستنى نتيجة نفس الطلب
    // (userLocationProvider مخزّن نتيجته - ما بيعيد طلب GPS جديد لو أصلاً
    // شغّال أو خلص). بدون هاد، الطلب كان ممكن يروح بدون إحداثيات ويفوّت
    // Grouped Delivery بصمت رغم إنه الموقع كان رح يوصل بعد ثانية أو ثنتين.
    if (_pickedLocation == null) {
      final location = await ref.read(userLocationProvider.future);
      if (location != null && mounted) {
        setState(() => _pickedLocation = location);
      }
    }

    final orderService = OrderService();
    final paymentService = PaymentService();
    final couponCode = _couponController.text.trim().isEmpty
        ? null
        : _couponController.text.trim();
    // ✅ 'West Bank' | 'Gaza Strip' لمدينة حقيقية من palestineAreas، أو
    // 'Israel' لو اختار الزبون "داخل الأراضي المحتلة" (مش بمدينة/إحداثيات محددة)
    final deliveryRegion = _selectedCity == occupiedArea
        ? 'Israel'
        : cityInfo[_selectedCity]?.$1;
    // نستخدم العناصر الخاصة بهذا المتجر فقط
    final grouped = _groupByStore(widget.checkoutItems);
    final List<String> placedOrderNumbers = [];
    final List<String> failedPaymentOrderNumbers = [];
    final List<String> failedStores = [];
    final List<CartItem> itemsToRemoveFromCart = [];
    double totalSavings = 0;
    // ✅ النقاط بتُستبدل على أول طلب ينجح إنشاؤه بس (مش أول متجر بالحلقة
    // بالضرورة - لو أول متجر فشل إنشاء طلبه لأي سبب، منسيب الفرصة للمتجر
    // التالي بدل ما نضيّع الاستبدال كليًا)
    bool pointsAlreadyApplied = false;

    for (final entry in grouped.entries) {
      final storeId = entry.value.first.product.storeId;
      final items = entry.value
          .map(
            (item) => {
              'product_id': item.product.id,
              'quantity': item.quantity,
              if (item.selectedVariant != null)
                'variant_id': item.selectedVariant!.id,
              if (item.selectedAddons.isNotEmpty)
                'addon_ids': item.selectedAddons.map((a) => a.id).toList(),
              if (item.selectedExclusionLabels.isNotEmpty)
                'special_requests': item.selectedExclusionLabels,
              if (item.selectedOptions.isNotEmpty)
                'option_value_ids': item.selectedOptions
                    .map((o) => o.valueId)
                    .toList(),
            },
          )
          .toList();

      final wantsPointsHere = !pointsAlreadyApplied && _pointsToRedeem != null;
      final result = await orderService.createOrder(
        storeId: storeId,
        items: items,
        deliveryAddress: _addressController.text.trim(),
        deliveryCity: _selectedCity!,
        deliveryRegion: deliveryRegion!,
        deliveryLat: _pickedLocation?.latitude,
        deliveryLng: _pickedLocation?.longitude,
        paymentMethod: _paymentMethod,
        specialInstructions: _instructionsController.text.trim().isEmpty
            ? null
            : _instructionsController.text.trim(),
        couponCode: couponCode,
        redeemPoints: wantsPointsHere ? _pointsToRedeem : null,
      );

      if (!result.success || result.order == null) {
        // ✅ لو فشل الطلب اللي كان لازم ياخد الاستبدال (رصيد تغيّر بينها
        // وبين المعاينة مثلاً)، منوقف محاولة الاستبدال بالكامل بدل ما نضلل
        // المستخدم إنه استبدل نقاط وهو ما استبدلها فعليًا بأي متجر
        if (wantsPointsHere) pointsAlreadyApplied = true;
        failedStores.add(entry.value.first.storeName);
        continue;
      }

      if (wantsPointsHere) pointsAlreadyApplied = true;

      // الطلب انخلق فعليًا (بغض النظر عن نتيجة الدفع) - عناصره تنشال من السلة
      itemsToRemoveFromCart.addAll(entry.value);
      totalSavings += result.order!.discount;

      if (!_cardPaymentMethods.contains(_paymentMethod)) {
        // Cash / Wallet: زي ما كان، فوري بدون بوابة دفع
        placedOrderNumbers.add(result.order!.orderNumber);
        continue;
      }

      // بطاقة: لازم نمر عبر HyperPay قبل ما نعتبر الطلب "مدفوع"
      final checkoutResult = await paymentService.createCheckoutSession(
        orderId: result.order!.id,
      );

      if (!checkoutResult.success || checkoutResult.widgetUrl == null) {
        failedPaymentOrderNumbers.add(result.order!.orderNumber);
        continue;
      }

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              PaymentWebViewScreen(widgetUrl: checkoutResult.widgetUrl!),
        ),
      );

      // بغض النظر إذا المستخدم خلّص الفورم أو رجع لبرا (cancelled)، الباك إند هو
      // مصدر الحقيقة الوحيد - دايمًا منتحقق منه قبل ما نقرر شو نعرض للمستخدم.
      final statusResult = await paymentService.verifyPaymentStatus(
        orderId: result.order!.id,
      );

      if (statusResult.success && statusResult.paymentStatus == 'Paid') {
        placedOrderNumbers.add(result.order!.orderNumber);
      } else {
        failedPaymentOrderNumbers.add(result.order!.orderNumber);
      }
    }

    if (!mounted) return;

    setState(() => _isPlacingOrder = false);

    if (placedOrderNumbers.isNotEmpty || failedPaymentOrderNumbers.isNotEmpty) {
      // تفريغ عناصر الطلبات يلي فعليًا انخلقت بس من السلة العامة
      for (var item in itemsToRemoveFromCart) {
        ref.read(cartProvider.notifier).removeItem(item.product.id);
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => OrderSuccessScreen(
            orderNumbers: placedOrderNumbers,
            hasPartialFailure: failedStores.isNotEmpty,
            failedPaymentOrderNumbers: failedPaymentOrderNumbers,
            totalSavings: totalSavings,
          ),
        ),
      );
    } else {
      setState(() {
        _errorMessage = AppLocalizations.t(
          Localizations.localeOf(context),
          'checkout_place_order_failed',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      builder: (context, isWeb, padding, width) {
        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: padding,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                              TextButton.icon(
                                onPressed: () => Navigator.pop(context),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  foregroundColor: Colors.grey[600],
                                ),
                                icon: const Icon(Icons.arrow_back, size: 16),
                                label: Text(
                                  AppLocalizations.t(
                                    Localizations.localeOf(context),
                                    'checkout_back_to_cart',
                                  ),
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${AppLocalizations.t(Localizations.localeOf(context), 'checkout_title_prefix')} - ${widget.storeName}', // عرض اسم المتجر المحدد
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 24),
                              _sectionCard(
                                title: AppLocalizations.t(
                                  Localizations.localeOf(context),
                                  'checkout_delivery_address',
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    DropdownButtonFormField<String>(
                                      initialValue: _selectedCity,
                                      isExpanded: true,
                                      decoration: InputDecoration(
                                        hintText: AppLocalizations.t(
                                          Localizations.localeOf(context),
                                          'checkout_select_city',
                                        ),
                                        filled: true,
                                        fillColor: const Color(0xFFF7F8F7),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          borderSide: BorderSide.none,
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 14,
                                        ),
                                      ),
                                      items: deliveryAreas
                                          .map((city) => DropdownMenuItem(
                                                value: city,
                                                child: Text(city),
                                              ))
                                          .toList(),
                                      onChanged: (value) =>
                                          setState(() => _selectedCity = value),
                                    ),
                                    const SizedBox(height: 14),
                                    TextField(
                                      controller: _addressController,
                                      maxLines: 2,
                                      decoration: InputDecoration(
                                        hintText: AppLocalizations.t(
                                          Localizations.localeOf(context),
                                          'checkout_address_hint',
                                        ),
                                        filled: true,
                                        fillColor: const Color(0xFFF7F8F7),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                        contentPadding: const EdgeInsets.all(
                                          14,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    _buildLocationPickerSection(),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              _sectionCard(
                                title: AppLocalizations.t(
                                  Localizations.localeOf(context),
                                  'checkout_payment_method',
                                ),
                                child: RadioGroup<String>(
                                  groupValue: _paymentMethod,
                                  onChanged: (value) {
                                    setState(() => _paymentMethod = value!);
                                  },
                                  child: Column(
                                    children: _paymentMethodKeys.map((key) {
                                      return RadioListTile<String>(
                                        value: key,
                                        activeColor: brandColor,
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(
                                          _paymentLabel(context, key),
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              _sectionCard(
                                title: AppLocalizations.t(
                                  Localizations.localeOf(context),
                                  'checkout_special_instructions',
                                ),
                                child: TextField(
                                  controller: _instructionsController,
                                  maxLines: 2,
                                  decoration: InputDecoration(
                                    hintText: AppLocalizations.t(
                                      Localizations.localeOf(context),
                                      'checkout_instructions_hint',
                                    ),
                                    filled: true,
                                    fillColor: const Color(0xFFF7F8F7),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.all(14),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              _sectionCard(
                                title: AppLocalizations.t(
                                  Localizations.localeOf(context),
                                  'checkout_coupon_title',
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          TextField(
                                            controller: _couponController,
                                            decoration: InputDecoration(
                                              hintText: AppLocalizations.t(
                                                Localizations.localeOf(context),
                                                'checkout_coupon_hint',
                                              ),
                                              filled: true,
                                              fillColor: const Color(
                                                0xFFF7F8F7,
                                              ),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                borderSide: BorderSide.none,
                                              ),
                                              contentPadding:
                                                  const EdgeInsets.all(14),
                                            ),
                                          ),
                                          if (_couponPreviewMessage !=
                                              null) ...[
                                            const SizedBox(height: 6),
                                            Text(
                                              _couponPreviewMessage!,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: _couponPreviewSuccess
                                                    ? brandColor
                                                    : Colors.redAccent,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: brandColor,
                                        side: const BorderSide(
                                          color: brandColor,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                          horizontal: 16,
                                        ),
                                      ),
                                      onPressed: _isValidatingCoupon
                                          ? null
                                          : _validateCoupon,
                                      child: _isValidatingCoupon
                                          ? const SizedBox(
                                              height: 16,
                                              width: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: brandColor,
                                              ),
                                            )
                                          : Text(
                                              AppLocalizations.t(
                                                Localizations.localeOf(context),
                                                'checkout_coupon_apply',
                                              ),
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_pointsBalance > 0) ...[
                                const SizedBox(height: 16),
                                _sectionCard(
                                  title: AppLocalizations.t(
                                    Localizations.localeOf(context),
                                    'checkout_points_title',
                                  ).replaceFirst('{balance}', '$_pointsBalance'),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            TextField(
                                              controller: _pointsController,
                                              keyboardType: TextInputType.number,
                                              decoration: InputDecoration(
                                                hintText: AppLocalizations.t(
                                                  Localizations.localeOf(context),
                                                  'checkout_points_hint',
                                                ),
                                                filled: true,
                                                fillColor: const Color(0xFFF7F8F7),
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(10),
                                                  borderSide: BorderSide.none,
                                                ),
                                                contentPadding: const EdgeInsets.all(14),
                                              ),
                                            ),
                                            if (_pointsPreviewMessage != null) ...[
                                              const SizedBox(height: 6),
                                              Text(
                                                _pointsPreviewMessage!,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: _pointsPreviewSuccess ? brandColor : Colors.redAccent,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: brandColor,
                                          side: const BorderSide(color: brandColor),
                                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                                        ),
                                        onPressed: _isPreviewingPoints ? null : _validatePoints,
                                        child: _isPreviewingPoints
                                            ? const SizedBox(
                                                height: 16,
                                                width: 16,
                                                child: CircularProgressIndicator(strokeWidth: 2, color: brandColor),
                                              )
                                            : Text(
                                                AppLocalizations.t(
                                                  Localizations.localeOf(context),
                                                  'checkout_coupon_apply',
                                                ),
                                              ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 16),
                              // تمرير القائمة والسعر المفلترين للمتجر المحدد للـ Widget بالأسفل
                              _orderSummary(
                                context,
                                widget.checkoutItems,
                                widget.totalPrice,
                              ),
                              if (_errorMessage != null) ...[
                                const SizedBox(height: 12),
                                Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: brandColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    elevation: 0,
                                  ),
                                  onPressed: _isPlacingOrder
                                      ? null
                                      : _placeOrder,
                                  child: _isPlacingOrder
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation(
                                              Colors.white,
                                            ),
                                          ),
                                        )
                                      : Text(
                                          AppLocalizations.t(
                                            Localizations.localeOf(context),
                                            'checkout_place_order',
                                          ),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
  }

  // ✅ اختياري - بيحسّن دقة التوصيل، وبيفعّل Grouped Delivery (محتاجة إحداثيات
  // حقيقية تحسب عليها المسافة؛ عنوان نصي بس ما يكفي). نفس LocationPickerMap
  // المستخدمة أصلًا بـ store_setup_screen.dart لاختيار موقع المتجر.
  Widget _buildLocationPickerSection() {
    final locale = Localizations.localeOf(context);
    final currentLocation = ref.watch(userLocationProvider).valueOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.t(locale, 'checkout_delivery_location_label'),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        LocationPickerMap(
          initialCenter:
              _pickedLocation ?? currentLocation ?? const LatLng(31.95, 35.2),
          onLocationSelected: (point) =>
              setState(() => _pickedLocation = point),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(
              _pickedLocation != null ? Icons.check_circle : Icons.info_outline,
              size: 14,
              color: _pickedLocation != null ? brandColor : Colors.grey[500],
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                AppLocalizations.t(
                  locale,
                  _pickedLocation != null
                      ? 'checkout_delivery_location_picked'
                      : 'checkout_delivery_location_hint',
                ),
                style: TextStyle(
                  fontSize: 11.5,
                  color: _pickedLocation != null
                      ? brandColor
                      : Colors.grey[500],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return SizedBox(
      width: double.infinity,
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  Widget _orderSummary(
    BuildContext context,
    List<CartItem> items,
    double totalPrice,
  ) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.t(
              Localizations.localeOf(context),
              'checkout_order_summary',
            ),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 10),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.selectedVariant != null
                              ? '${item.quantity}x ${item.product.name} (${item.selectedVariant!.label})'
                              : '${item.quantity}x ${item.product.name}',
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (item.selectedAddons.isNotEmpty)
                          Text(
                            '+ ${item.selectedAddons.map((a) => a.name).join('، ')}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (item.selectedExclusionLabels.isNotEmpty)
                          Text(
                            '- ${item.selectedExclusionLabels.join('، ')}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  Text(
                    '₪${item.subtotal.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppLocalizations.t(
                  Localizations.localeOf(context),
                  'checkout_subtotal',
                ),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                '₪${totalPrice.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (_estimatedDeliveryFee != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppLocalizations.t(
                    Localizations.localeOf(context),
                    'checkout_delivery_fee',
                  ),
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
                Text(
                  '₪${_estimatedDeliveryFee!.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(height: 1),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppLocalizations.t(
                    Localizations.localeOf(context),
                    'checkout_total',
                  ),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                Text(
                  '₪${(totalPrice + _estimatedDeliveryFee!).toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: brandColor,
                  ),
                ),
              ],
            ),
          ] else
            Text(
              AppLocalizations.t(
                Localizations.localeOf(context),
                'checkout_delivery_fee_note',
              ),
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
        ],
      ),
    );
  }
}
