// lib/screens/auth_screen.dart
import 'package:flutter/material.dart';

enum UserRole { customer, vendor, driver }

class AuthScreen extends StatefulWidget {
  const AuthScreen({Key? key}) : super(key: key);

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isRegistering = false;
  UserRole selectedRole = UserRole.customer;

  // Controllers
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _storeNameController = TextEditingController();

  String selectedBusinessCategory = 'مطعم';
  String selectedVehicleType = 'Motorcycle';

  final List<Map<String, String>> businessCategories = [
    {'id': 'مطعم', 'label': '🍔 مطعم'},
    {'id': 'صيدلية', 'label': '💊 صيدلية'},
    {'id': 'ملابس', 'label': '👕 ملابس'},
    {'id': 'سوبرماركت', 'label': '🛒 سوبرماركت'},
    {'id': 'إلكترونيات', 'label': '💻 إلكترونيات'},
    {'id': 'أخرى', 'label': '📦 أخرى'},
  ];

  final List<Map<String, String>> vehicleTypes = [
    {'id': 'Bicycle', 'label': '🚲 Bicycle'},
    {'id': 'Motorcycle', 'label': '🏍️ Motorcycle'},
    {'id': 'Car', 'label': '🚗 Car'},
    {'id': 'Van', 'label': '🚚 Van'},
    {'id': 'Company Driver', 'label': '💼 Company'},
  ];

  void _submit() {
    final email = _emailController.text;
    final password = _passwordController.text;
    
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال البريد الإلكتروني وكلمة المرور')),
      );
      return;
    }

    if (isRegistering) {
      final name = _nameController.text;
      final phone = _phoneController.text;
      if (name.isEmpty || phone.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الرجاء إكمال كافة الحقول المطلوبة')),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم إنشاء حساب ${selectedRole.name} بنجاح!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم تسجيل الدخول بنجاح كـ ${selectedRole.name}')),
      );
    }
  }

  // دالة مؤقتة لتجربة الضغط على نسيت كلمة المرور
  void _forgotPassword() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('سيتم إرسال رابط إعادة تعيين كلمة المرور إلى بريدك الإلكتروني')),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF006D32);
    
    return Scaffold(
      backgroundColor: const Color(0xFFF7FBF1),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. الهوية والشعار
Center(
  child: Column(
    children: [
      // اللوجو القديم الفعلي للتطبيق
      Image.asset(
        'assets/images/logo.png', // 👈 تأكدي من مطابقة هذا المسار لمسار ملف اللوجو في مشروعك
        width: 100,
        height: 100,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          // في حال لم يجد المسار، يعرض أيقونة حماية بديلة لكي لا يتوقف التطبيق عن العمل
          return const Icon(Icons.storefront, size: 80, color: Color(0xFF006D32));
        },
      ),
      const SizedBox(height: 12),
      const Text(
        'PickNGo',
        style: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w900,
          color: primaryColor,
        ),
      ),
      const Text(
        'Cairo\'s Modern Multi-Vendor Delivery System',
        style: TextStyle(fontSize: 13, color: Colors.grey),
        textAlign: TextAlign.center,
      ),
    ],
  ),
),
                
                  
                    
                      
                      
          
                     
                      
                       
                       
                     
                    
                   
                  
                  
                  const SizedBox(height: 30),

                  // 2. شريط التحويل (Login / Register)
                  Container(
                    padding: const EdgeInsets.all(4.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF3EB),
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => isRegistering = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12.0),
                              decoration: BoxDecoration(
                                color: !isRegistering ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Login',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: !isRegistering ? primaryColor : Colors.grey,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => isRegistering = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12.0),
                              decoration: BoxDecoration(
                                color: isRegistering ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Register',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isRegistering ? primaryColor : Colors.grey,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 3. اختيار نوع الحساب
                  const Text(
                    'Choose Your Account Type',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'اختر نوع الحساب للوصول إلى لوحة التحكم الخاصة بك:',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  
                  Row(
                    children: [
                      Expanded(
                        child: _buildRoleCard(
                          role: UserRole.customer,
                          emoji: '🛒',
                          title: 'Customer',
                          subtitle: 'يشتري أو يطلب',
                          isSelected: selectedRole == UserRole.customer,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _buildRoleCard(
                          role: UserRole.vendor,
                          emoji: '🏪',
                          title: 'Business',
                          subtitle: 'مالك متجر',
                          isSelected: selectedRole == UserRole.vendor,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _buildRoleCard(
                          role: UserRole.driver,
                          emoji: '🏍️',
                          title: 'Driver',
                          subtitle: 'مندوب توصيل',
                          isSelected: selectedRole == UserRole.driver,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 4. بطاقة المدخلات
                  Card(
                    color: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                      side: const BorderSide(color: Color(0xFFEFF3EB)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            isRegistering
                                ? 'Create Account (${selectedRole.name.toUpperCase()})'
                                : 'Welcome Back!',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 16),

                          if (isRegistering) ...[
                            _buildTextField(
                              controller: _nameController,
                              label: 'Full Name / الاسم الكامل',
                              hint: 'أدخل الاسم الثلاثي',
                              icon: Icons.person_outline,
                            ),
                            const SizedBox(height: 12),
                            _buildTextField(
                              controller: _phoneController,
                              label: 'Phone Number / رقم الهاتف',
                              hint: '01xxxxxxxxx',
                              icon: Icons.phone_android_outlined,
                              keyboardType: TextInputType.phone,
                            ),
                            const SizedBox(height: 12),

                            if (selectedRole == UserRole.vendor) ...[
                              const Divider(color: Color(0xFFEFF3EB), height: 24),
                              const Text(
                                'Store Setup / إعدادات المتجر',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: primaryColor),
                              ),
                              const SizedBox(height: 8),
                              _buildTextField(
                                controller: _storeNameController,
                                label: 'Store Name / اسم النشاط التجاري',
                                hint: 'أدخل اسم المطعم أو المحل',
                                icon: Icons.storefront_outlined,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'نوع النشاط (Activity Type):',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                              const SizedBox(height: 8),
                              _buildBusinessGrid(),
                              const SizedBox(height: 12),
                            ],

                            if (selectedRole == UserRole.driver) ...[
                              const Divider(color: Color(0xFFEFF3EB), height: 24),
                              const Text(
                                'Driver Preferences / تفضيلات التوصيل',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: primaryColor),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'نوع المركبة (Vehicle Type):',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                              const SizedBox(height: 8),
                              _buildVehicleGrid(),
                              const SizedBox(height: 12),
                            ],
                          ],

                          _buildTextField(
                            controller: _emailController,
                            label: 'Email Address / البريد الإلكتروني',
                            hint: 'name@example.com',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: _passwordController,
                            label: 'Password / كلمة المرور',
                            hint: 'أدخل كلمة مرور قوية',
                            icon: Icons.lock_outline,
                            obscureText: true,
                          ),
                          
                          // ✨ إضافة زر "نسيت كلمة المرور" المخصص لحالة تسجيل الدخول فقط
                          if (!isRegistering) ...[
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft, // لتتناسب مع التوجيه الأجنبي، أو جربي centerRight للغة العربية
                              child: TextButton(
                                onPressed: _forgotPassword,
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 0),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  'Forgot Password? / نسيت كلمة السر؟',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: primaryColor,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          
                          if (isRegistering) ...[
                            const SizedBox(height: 12),
                            _buildTextField(
                              controller: _confirmPasswordController,
                              label: 'Confirm Password / تأكيد كلمة المرور',
                              hint: 'أعد كتابة كلمة المرور للتحقق',
                              icon: Icons.lock_clock_outlined,
                              obscureText: true,
                            ),
                          ],
                          
                          const SizedBox(height: 20),

                          ElevatedButton(
                            onPressed: _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              isRegistering ? 'Sign Up' : 'Log In',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required UserRole role,
    required String emoji,
    required String title,
    required String subtitle,
    required bool isSelected,
  }) {
    const primaryColor = Color(0xFF006D32);
    return InkWell(
      onTap: () => setState(() => selectedRole = role),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEAF5EC) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? primaryColor : const Color(0xFFEFF3EB),
            width: 2.0,
          ),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isSelected ? primaryColor : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                color: isSelected ? primaryColor.withOpacity(0.8) : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.grey),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEFF3EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEFF3EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF006D32), width: 2.0),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      ),
    );
  }

  Widget _buildBusinessGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: businessCategories.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 2.0,
      ),
      itemBuilder: (context, index) {
        final category = businessCategories[index];
        final isSelected = selectedBusinessCategory == category['id'];
        return GestureDetector(
          onTap: () => setState(() => selectedBusinessCategory = category['id']!),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFEAF5EC) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? const Color(0xFF006D32) : Colors.transparent,
                width: 1.5,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              category['label']!,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isSelected ? const Color(0xFF006D32) : const Color(0xFF475569),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVehicleGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: vehicleTypes.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 2.8,
      ),
      itemBuilder: (context, index) {
        final vehicle = vehicleTypes[index];
        final isSelected = selectedVehicleType == vehicle['id'];
        return GestureDetector(
          onTap: () => setState(() => selectedVehicleType = vehicle['id']!),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFEAF5EC) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? const Color(0xFF006D32) : Colors.transparent,
                width: 1.5,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              vehicle['label']!,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isSelected ? const Color(0xFF006D32) : const Color(0xFF475569),
              ),
            ),
          ),
        );
      },
    );
  }
}