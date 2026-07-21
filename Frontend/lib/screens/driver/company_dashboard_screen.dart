// lib/screens/driver/company_dashboard_screen.dart
//
// لوحة إدارة كاملة لصاحب حساب شركة التوصيل: قبول/رفض طلبات الانضمام،
// عرض السائقين المعتمدين بحالتهم اللحظية (Available/Busy/Offline)، عدد
// الطلبات المنجزة، الأرباح، تفعيل/إيقاف، إزالة، وبحث/تصفية.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/company_service.dart';
import '../../services/socket_service.dart';
import '../../core/theme/app_themes.dart';
import '../../widgets/company_header.dart';

class CompanyDashboardScreen extends ConsumerStatefulWidget {
  const CompanyDashboardScreen({super.key});

  @override
  ConsumerState<CompanyDashboardScreen> createState() => _CompanyDashboardScreenState();
}

class _CompanyDashboardScreenState extends ConsumerState<CompanyDashboardScreen> {
  static const Color brandColor = AppColors.brand;

  final _companyService = CompanyService();
  final _searchController = TextEditingController();
  // نخزّن socket service وقت initState بدل ما ننادي ref.read() جوا dispose() -
  // لأنه ref ممكن يصير invalid وقت تفكيك شجرة الـ widgets كاملة (StateError حقيقي).
  late final SocketService _socket;

  bool _isLoading = true;
  List<CompanyRosterDriverModel> _roster = [];
  List<CompanyJoinRequestModel> _joinRequests = [];
  DriverAvailability? _statusFilter; // null = الكل
  String _search = '';
  final Set<String> _busyActionIds = {}; // سائقين قيد تنفيذ إجراء (تعطيل الأزرار مؤقتاً)

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() => _search = _searchController.text.trim()));
    _load();
    _connectLiveStatus();
  }

  Future<void> _connectLiveStatus() async {
    _socket = ref.read(socketServiceProvider);
    await _socket.connect();
    // ✅ السيرفر بيبث driver:status لغرفة الشركة تلقائياً (join وقت الاتصال) -
    // منحدّث السائق المتأثر بس بالقائمة، بدون إعادة تحميل كامل.
    _socket.onDriverStatus((event) {
      if (!mounted) return;
      final index = _roster.indexWhere((d) => d.id == event.driverId);
      if (index == -1) return;
      setState(() {
        final updated = [..._roster];
        updated[index] = updated[index].copyWith(availability: parseDriverAvailability(event.status));
        _roster = updated;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _socket.offDriverStatus();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      _companyService.getMyRoster(),
      _companyService.getJoinRequests(),
    ]);
    if (!mounted) return;
    final rosterResult = results[0] as CompanyRosterResult;
    final requestsResult = results[1] as CompanyJoinRequestsResult;
    setState(() {
      _isLoading = false;
      if (rosterResult.success) _roster = rosterResult.roster;
      if (requestsResult.success) _joinRequests = requestsResult.requests;
    });
  }

  List<CompanyRosterDriverModel> get _filteredRoster {
    return _roster.where((d) {
      if (_statusFilter != null && d.availability != _statusFilter) return false;
      if (_search.isEmpty) return true;
      final q = _search.toLowerCase();
      return d.fullName.toLowerCase().contains(q) || (d.phone ?? '').contains(q);
    }).toList();
  }

  Future<void> _approveRequest(CompanyJoinRequestModel request) async {
    setState(() => _busyActionIds.add(request.id));
    final result = await _companyService.approveJoinRequest(request.id);
    if (!mounted) return;
    setState(() => _busyActionIds.remove(request.id));
    if (result.success) {
      await _load();
      if (!mounted) return;
      _showSnack('تمت الموافقة على ${request.fullName}');
    } else {
      _showSnack(result.message.isNotEmpty ? result.message : 'حدث خطأ، حاولي مرة أخرى', isError: true);
    }
  }

  Future<void> _rejectRequest(CompanyJoinRequestModel request) async {
    setState(() => _busyActionIds.add(request.id));
    final result = await _companyService.rejectJoinRequest(request.id);
    if (!mounted) return;
    setState(() {
      _busyActionIds.remove(request.id);
      if (result.success) _joinRequests = _joinRequests.where((r) => r.id != request.id).toList();
    });
    if (!result.success) {
      _showSnack(result.message.isNotEmpty ? result.message : 'حدث خطأ، حاولي مرة أخرى', isError: true);
    }
  }

  Future<void> _toggleActive(CompanyRosterDriverModel driver) async {
    final newValue = !driver.isActive;
    setState(() {
      _roster = _roster.map((d) => d.id == driver.id ? d.copyWith(isActive: newValue) : d).toList();
    });
    final result = await _companyService.setDriverActive(driver.id, newValue);
    if (!mounted) return;
    if (!result.success) {
      setState(() {
        _roster = _roster.map((d) => d.id == driver.id ? d.copyWith(isActive: !newValue) : d).toList();
      });
      _showSnack(result.message.isNotEmpty ? result.message : 'حدث خطأ، حاولي مرة أخرى', isError: true);
    }
  }

  Future<void> _confirmRemove(CompanyRosterDriverModel driver) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('إزالة السائق؟'),
        content: Text('رح تتم إزالة ${driver.fullName} من شركتك. فيه يقدر ينضم لشركة تانية بعدين.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('إزالة'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busyActionIds.add(driver.id));
    final result = await _companyService.removeDriver(driver.id);
    if (!mounted) return;
    setState(() {
      _busyActionIds.remove(driver.id);
      if (result.success) _roster = _roster.where((d) => d.id != driver.id).toList();
    });
    if (!result.success) {
      _showSnack(result.message.isNotEmpty ? result.message : 'حدث خطأ، حاولي مرة أخرى', isError: true);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalEarnings = _roster.fold<double>(0, (sum, d) => sum + d.earnings);

    return Scaffold(
      body: Column(
        children: [
          LayoutBuilder(
            builder: (context, headerConstraints) {
              final isWeb = headerConstraints.maxWidth > 900;
              final padding = isWeb ? headerConstraints.maxWidth * 0.06 : 20.0;
              return CompanyHeader(isWeb: isWeb, padding: padding);
            },
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: RefreshIndicator(
                onRefresh: _load,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final padding = constraints.maxWidth > 900 ? constraints.maxWidth * 0.06 : 20.0;
                    return SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.symmetric(horizontal: padding, vertical: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'لوحة تحكم شركة التوصيل',
                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                          ),
                          const SizedBox(height: 20),
                          if (_isLoading)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 60),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          else ...[
                            _buildSummaryRow(totalEarnings),
                            if (_joinRequests.isNotEmpty) ...[
                              const SizedBox(height: 24),
                              _buildJoinRequestsSection(),
                            ],
                            const SizedBox(height: 24),
                            _buildSearchAndFilters(),
                            const SizedBox(height: 16),
                            if (_filteredRoster.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 40),
                                child: Center(
                                  child: Text(
                                    _roster.isEmpty ? 'لسا ما في سائقين منتسبين لشركتك' : 'ما في نتائج مطابقة',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                ),
                              )
                            else
                              ..._filteredRoster.map(_buildDriverCard),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(double totalEarnings) {
    return Row(
      children: [
        Expanded(child: _summaryTile(Icons.groups_outlined, '${_roster.length}', 'سائق منتسب')),
        const SizedBox(width: 12),
        Expanded(
          child: _summaryTile(
            Icons.bolt,
            '${_roster.where((d) => d.availability == DriverAvailability.available).length}',
            'متاح الآن',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: _summaryTile(Icons.payments_outlined, '₪${totalEarnings.toStringAsFixed(0)}', 'إجمالي رسوم التوصيل')),
      ],
    );
  }

  Widget _summaryTile(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: brandColor, size: 22),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildJoinRequestsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_add_alt_1, color: AppColors.accent, size: 20),
              const SizedBox(width: 8),
              Text(
                'طلبات انضمام (${_joinRequests.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._joinRequests.map(_buildJoinRequestCard),
        ],
      ),
    );
  }

  Widget _buildJoinRequestCard(CompanyJoinRequestModel request) {
    final isBusy = _busyActionIds.contains(request.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: brandColor.withValues(alpha: 0.1),
            child: Icon(Icons.person_outline, color: brandColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(request.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(
                  '${request.vehicleType ?? ''} ${request.phone != null ? '• ${request.phone}' : ''}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 11),
                ),
              ],
            ),
          ),
          if (isBusy)
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          else ...[
            IconButton(
              icon: const Icon(Icons.close, color: Colors.redAccent, size: 20),
              tooltip: 'رفض',
              onPressed: () => _rejectRequest(request),
            ),
            IconButton(
              icon: Icon(Icons.check_circle, color: brandColor, size: 22),
              tooltip: 'قبول',
              onPressed: () => _approveRequest(request),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('السائقون', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'ابحث بالاسم أو رقم الهاتف...',
            prefixIcon: const Icon(Icons.search, size: 20),
            filled: true,
            fillColor: Theme.of(context).cardColor,
            contentPadding: const EdgeInsets.symmetric(vertical: 0),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: [
            _filterChip('الكل', null),
            _filterChip('متاح', DriverAvailability.available),
            _filterChip('مشغول', DriverAvailability.busy),
            _filterChip('غير متصل', DriverAvailability.offline),
          ],
        ),
      ],
    );
  }

  Widget _filterChip(String label, DriverAvailability? value) {
    final isSelected = _statusFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _statusFilter = value),
      selectedColor: brandColor,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      backgroundColor: Theme.of(context).cardColor,
      side: BorderSide(color: isSelected ? brandColor : Theme.of(context).dividerColor),
    );
  }

  Widget _buildDriverCard(CompanyRosterDriverModel driver) {
    final isBusy = _busyActionIds.contains(driver.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: brandColor.withValues(alpha: 0.1),
                child: Icon(Icons.person_outline, color: brandColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(driver.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(
                      '${driver.vehicleType ?? ''} ${driver.phone != null ? '• ${driver.phone}' : ''}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
              _statusBadge(driver.availability),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _statRow(Icons.local_shipping_outlined, '${driver.deliveredCount}', 'طلب موصّل'),
              ),
              Expanded(
                child: _statRow(Icons.payments_outlined, '₪${driver.earnings.toStringAsFixed(2)}', 'أرباح'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Switch(
                value: driver.isActive,
                activeThumbColor: brandColor,
                onChanged: isBusy ? null : (_) => _toggleActive(driver),
              ),
              Text(
                driver.isActive ? 'مفعّل' : 'موقوف',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: driver.isActive ? brandColor : Colors.grey[600],
                ),
              ),
              const Spacer(),
              if (isBusy)
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              else
                TextButton.icon(
                  onPressed: () => _confirmRemove(driver),
                  icon: const Icon(Icons.person_remove_outlined, size: 16, color: Colors.redAccent),
                  label: const Text('إزالة', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statRow(IconData icon, String value, String label) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[500]),
        const SizedBox(width: 6),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
      ],
    );
  }

  Widget _statusBadge(DriverAvailability availability) {
    late Color color;
    late String label;
    switch (availability) {
      case DriverAvailability.available:
        color = brandColor;
        label = 'متاح';
        break;
      case DriverAvailability.busy:
        color = AppColors.accent;
        label = 'مشغول';
        break;
      case DriverAvailability.offline:
        color = Colors.grey;
        label = 'غير متصل';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10)),
        ],
      ),
    );
  }
}
