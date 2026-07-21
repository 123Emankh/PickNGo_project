// lib/screens/admin/admin_user_detail_screen.dart
//
// تفاصيل مستخدم واحد (أي دور: زبون/سائق/صاحب متجر/شركة توصيل/أدمن) +
// تعديل حالة الحساب (Approved/Suspended/Rejected/Pending) - نقطة الوصول
// الوحيدة لتغيير User.status من لوحة الأدمن (PATCH /api/admin/users/:id/status).
import 'package:flutter/material.dart';
import '../../core/theme/app_themes.dart';
import '../../data/models/admin_models.dart';
import '../../services/admin_service.dart';
import '../../widgets/detail_app_bar.dart';

class AdminUserDetailScreen extends StatefulWidget {
  final AdminUserModel user;

  const AdminUserDetailScreen({super.key, required this.user});

  @override
  State<AdminUserDetailScreen> createState() => _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends State<AdminUserDetailScreen> {
  static const Color brandColor = AppColors.brand;
  final _adminService = AdminService();
  late AdminUserModel _user;
  bool _isSaving = false;

  static const Map<String, String> _categoryLabels = {
    'Customer': 'زبون',
    'Driver': 'سائق',
    'Restaurant': 'صاحب متجر',
    'Company': 'شركة توصيل',
    'Admin': 'أدمن',
  };

  static const Map<String, String> _statusLabels = {
    'Approved': 'نشط (Active)',
    'Suspended': 'معلّق (Suspended)',
    'Pending': 'بانتظار الموافقة',
    'Rejected': 'مرفوض',
  };

  static const Map<String, Color> _statusColors = {
    'Approved': AppColors.success,
    'Suspended': AppColors.error,
    'Pending': AppColors.warning,
    'Rejected': Colors.grey,
  };

  @override
  void initState() {
    super.initState();
    _user = widget.user;
  }

  Future<void> _changeStatus(String status) async {
    if (status == _user.status || _isSaving) return;

    final confirmed = await _confirm(status);
    if (!confirmed) return;

    setState(() => _isSaving = true);
    final result = await _adminService.updateUserStatus(_user.id, status);
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (result.success) {
      setState(() => _user = _user.copyWith(status: status));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم تحديث حالة الحساب إلى "${_statusLabels[status]}"')),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message.isNotEmpty ? result.message : 'تعذر تحديث الحالة')),
      );
    }
  }

  Future<bool> _confirm(String status) async {
    if (status == 'Approved') return true; // إعادة تفعيل ما بتحتاج تأكيد إضافي
    final label = _statusLabels[status] ?? status;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الإجراء'),
        content: Text('متأكد إنك بدك تغيّر حالة "${_user.fullName}" إلى "$label"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(status == 'Rejected' || status == 'Suspended' ? 'تأكيد' : 'موافق',
                style: const TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColors[_user.status] ?? Colors.grey;
    return Scaffold(
      appBar: const DetailAppBar(title: 'تفاصيل المستخدم'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: brandColor.withValues(alpha: 0.1),
                  child: Icon(Icons.person_outline, color: brandColor, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_user.fullName, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(_categoryLabels[_user.category] ?? _user.category,
                          style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text(_statusLabels[_user.status] ?? _user.status,
                      style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _infoCard([
              _infoRow(Icons.email_outlined, 'البريد الإلكتروني', _user.email),
              if (_user.phone != null && _user.phone!.isNotEmpty) _infoRow(Icons.phone_outlined, 'رقم الهاتف', _user.phone!),
              if (_user.city != null && _user.city!.isNotEmpty)
                _infoRow(Icons.location_on_outlined, 'المدينة', [_user.city, _user.region].where((v) => v != null && v.isNotEmpty).join(' - ')),
              if (_user.businessType != null && _user.businessType!.isNotEmpty)
                _infoRow(Icons.badge_outlined, 'نوع الحساب', _user.businessType!),
              if (_user.createdAt != null)
                _infoRow(Icons.calendar_today_outlined, 'تاريخ التسجيل', _formatDate(_user.createdAt!)),
              _infoRow(Icons.tag, 'معرّف الحساب', '#${_user.id}'),
            ]),
            const SizedBox(height: 24),
            const Text('تعديل حالة الحساب', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _statusLabels.keys.map((status) {
                final isCurrent = status == _user.status;
                return OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: isCurrent ? (_statusColors[status] ?? Colors.grey).withValues(alpha: 0.12) : null,
                    foregroundColor: _statusColors[status] ?? Colors.grey,
                    side: BorderSide(color: (_statusColors[status] ?? Colors.grey).withValues(alpha: isCurrent ? 1 : 0.4)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: (isCurrent || _isSaving) ? null : () => _changeStatus(status),
                  child: Text(_statusLabels[status]!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                );
              }).toList(),
            ),
            if (_isSaving) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Widget _infoCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: Colors.grey[500]),
          const SizedBox(width: 10),
          SizedBox(width: 110, child: Text(label, style: TextStyle(fontSize: 12.5, color: Colors.grey[600]))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
