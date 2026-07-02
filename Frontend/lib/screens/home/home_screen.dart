import 'package:flutter/material.dart';
import '../auth/login_screen.dart';
import '../auth/register_screen.dart';
//import '../auth/signup_screen.dart';

// --- نماذج البيانات ---
class CategoryModel {
  final String id;
  final String name;
  final IconData icon;
  CategoryModel({required this.id, required this.name, required this.icon});
}

class StoreModel {
  final String id;
  final String name;
  final String categoryName;
  final String imageUrl;
  final double averageRating;
  final int totalReviews;
  final String deliveryTime;
  final String deliveryFee;

  StoreModel({
    required this.id,
    required this.name,
    required this.categoryName,
    required this.imageUrl,
    required this.averageRating,
    required this.totalReviews,
    required this.deliveryTime,
    required this.deliveryFee,
  });
}

class ProductModel {
  final String id;
  final String name;
  final String description;
  final String storeName;
  final String imageUrl;
  final double price;
  final double rating;
  final int totalReviews;

  ProductModel({
    required this.id,
    required this.name,
    required this.description,
    required this.storeName,
    required this.imageUrl,
    required this.price,
    required this.rating,
    required this.totalReviews,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  List<CategoryModel> _categories = [];
  List<StoreModel> _stores = [];
  List<ProductModel> _products = [];

  final Color brandColor = const Color(0xFF006D32); // اللون الأخضر للمشروع

  @override
  void initState() {
    super.initState();
    _loadHomeData();
  }

  Future<void> _loadHomeData() async {
    await Future.delayed(const Duration(milliseconds: 500)); 

    _categories = [
      CategoryModel(id: 'cat_1', name: 'Restaurants', icon: Icons.restaurant_menu),
      CategoryModel(id: 'cat_2', name: 'Supermarkets', icon: Icons.shopping_cart_outlined),
      CategoryModel(id: 'cat_3', name: 'Pharmacies', icon: Icons.local_pharmacy_outlined),
      CategoryModel(id: 'cat_4', name: 'Clothing', icon: Icons.checkroom_outlined),
      CategoryModel(id: 'cat_5', name: 'Bookstores', icon: Icons.menu_book_outlined),
      CategoryModel(id: 'cat_6', name: 'Bakeries & Desserts', icon: Icons.cake_outlined),
      CategoryModel(id: 'cat_7', name: 'Electronics', icon: Icons.phone_android_outlined),
    ];

    _stores = [
      StoreModel(
        id: 'store_1',
        name: 'The Book Nook',
        categoryName: 'Bookstores',
        imageUrl: 'https://images.unsplash.com/photo-1507842217343-583bb7270b66?w=500&q=80',
        averageRating: 4.8,
        totalReviews: 312,
        deliveryTime: '10 min',
        deliveryFee: '\$2.49',
      ),
      StoreModel(
        id: 'store_2',
        name: 'HealthPlus Pharmacy',
        categoryName: 'Pharmacies',
        imageUrl: 'https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?w=500&q=80',
        averageRating: 4.7,
        totalReviews: 89,
        deliveryTime: '10 min',
        deliveryFee: '\$1.99',
      ),
      StoreModel(
        id: 'store_3',
        name: 'Sweet Dreams Bakery',
        categoryName: 'Bakeries & Desserts',
        imageUrl: 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=500&q=80',
        averageRating: 4.6,
        totalReviews: 187,
        deliveryTime: '25 min',
        deliveryFee: '\$2.99',
      ),
      StoreModel(
        id: 'store_4',
        name: 'Bella Italia',
        categoryName: 'Restaurants',
        imageUrl: 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=500&q=80',
        averageRating: 4.5,
        totalReviews: 128,
        deliveryTime: '30 min',
        deliveryFee: '\$3.99',
      ),
    ];

    _products = [
      ProductModel(id: 'p1', name: 'The Great Gatsby', description: 'Classic novel by F. Scott Fitzgerald', storeName: 'The Book Nook', imageUrl: 'https://images.unsplash.com/photo-1543002588-bfa74002ed7e?w=500&q=80', price: 9.99, rating: 4.9, totalReviews: 87),
      ProductModel(id: 'p2', name: 'Tiramisu', description: 'Classic Italian coffee-flavored dessert', storeName: 'Bella Italia', imageUrl: 'https://images.unsplash.com/photo-1571877227200-a0d98ea607e9?w=500&q=80', price: 8.99, rating: 4.8, totalReviews: 28),
      ProductModel(id: 'p3', name: 'First Aid Kit', description: 'Complete emergency first aid kit', storeName: 'HealthPlus Pharmacy', imageUrl: 'https://images.unsplash.com/photo-1603398938378-e54eab446dde?w=500&q=80', price: 24.99, rating: 4.8, totalReviews: 19),
      ProductModel(id: 'p4', name: 'Chocolate Cake', description: 'Rich double-layer chocolate cake', storeName: 'Sweet Dreams Bakery', imageUrl: 'https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=500&q=80', price: 28.99, rating: 4.8, totalReviews: 43),
      ProductModel(id: 'p5', name: 'Margherita Pizza', description: 'Classic pizza with fresh mozzarella and basil', storeName: 'Bella Italia', imageUrl: 'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=500&q=80', price: 12.99, rating: 4.7, totalReviews: 45),
      ProductModel(id: 'p6', name: 'Croissant', description: 'Buttery, flaky French croissant', storeName: 'Sweet Dreams Bakery', imageUrl: 'https://images.unsplash.com/photo-1555507036-ab1f4038808a?w=500&q=80', price: 3.49, rating: 4.7, totalReviews: 56),
    ];

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(brandColor)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: LayoutBuilder(
        builder: (context, constraints) {
          bool isWeb = constraints.maxWidth > 900;
          double paddingPercent = isWeb ? constraints.maxWidth * 0.08 : 16.0;

          return Column(
            children: [
              // الـ Header العلوي المحدث ومربوط الشاشات
              _buildHeader(isWeb, paddingPercent),
              
              // باقي محتوى الصفحة داخل القائمة التمريرية
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeroSection(isWeb, paddingPercent),
                      _buildFeaturesStrip(isWeb, paddingPercent),
                      _buildCategoriesSection(paddingPercent, constraints.maxWidth),
                      _buildPopularStoresSection(paddingPercent, constraints.maxWidth),
                      _buildTrendingProductsSection(paddingPercent, constraints.maxWidth),
                      _buildFooterSection(paddingPercent, isWeb),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // 🛠️ دالة بناء الـ Header العلوي (SmartMarket Navbar) ومربوطة بأزرار التحكم الفعلي
  Widget _buildHeader(bool isWeb, double padding) {
    return Container(
      width: double.infinity,
      padding:  EdgeInsets.symmetric(horizontal: padding, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // اللوجو والاسم التجاري
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981), 
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(6),
                child: const Icon(Icons.layers_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 8),
              const Text(
                "SmartMarket",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ],
          ),

          // شريط البحث في بيئة الويب
          if (isWeb)
            Container(
              width: 400,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6), 
                borderRadius: BorderRadius.circular(20),
              ),
              child: const TextField(
                decoration: InputDecoration(
                  hintText: "Search products, stores...",
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                  prefixIcon: Icon(Icons.search, color: Colors.grey, size: 18),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 11),
                ),
              ),
            ),

          // أزرار الدخول الفعلي والتوجيه الصحيح للشاشات 🚀
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart_outlined, color: Colors.black87, size: 22),
                onPressed: () {},
              ),
              const SizedBox(width: 8),
              
              // 1. زر تسجيل الدخول (Log in)
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const RegisterScreen(startOnLogin: true)),

                  );
                },
                child: const Text("Log in", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              
              // 2. زر إنشاء حساب جديد (Sign up) - تم تصحيح المسمى وإلغاء الـ const لتجنب أخطاء البناء
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669), 
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                        MaterialPageRoute(builder: (context) => const RegisterScreen()), // بيفتح مباشرة على Register

                  );
                },
                child: const Text("Sign up", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection(bool isWeb, double padding) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [brandColor.withOpacity(0.04), Colors.white, Colors.orange.shade50.withOpacity(0.2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: padding, vertical: isWeb ? 60 : 30),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: brandColor.withOpacity(0.08), borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.delivery_dining_outlined, size: 16, color: brandColor),
                      const SizedBox(width: 6),
                      Text("Fast delivery from local stores", style: TextStyle(color: brandColor, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: isWeb ? 54 : 34, fontWeight: FontWeight.bold, color: Colors.black87, height: 1.1, fontFamily: 'sans-serif'),
                    children: [
                      const TextSpan(text: "Everything you need,\n"),
                      TextSpan(text: "delivered", style: TextStyle(color: const Color(0xFF10B981))),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Shop from restaurants, supermarkets, pharmacies, bookstores, and more — all in one place. Delivery or pickup, your choice.",
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600, height: 1.5),
                ),
                const SizedBox(height: 32),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        elevation: 0,
                      ),
                      onPressed: () {},
                      icon: const Text("Browse Stores", style: TextStyle(fontWeight: FontWeight.bold)),
                      label: const Icon(Icons.arrow_forward, size: 16),
                    ),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      onPressed: () {},
                      child: const Text("View Categories", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                )
              ],
            ),
          ),
          if (isWeb) const Expanded(flex: 1, child: SizedBox()), 
        ],
      ),
    );
  }

  Widget _buildFeaturesStrip(bool isWeb, double padding) {
    var features = [
      {'icon': Icons.local_shipping_outlined, 'title': 'Fast Delivery', 'desc': 'From nearby stores'},
      {'icon': Icons.access_time, 'title': 'Pickup Ready', 'desc': 'Skip the wait'},
      {'icon': Icons.shield_outlined, 'title': 'Secure Orders', 'desc': 'Safe & reliable'},
    ];

    List<Widget> featureWidgets = features.map((f) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(backgroundColor: brandColor.withOpacity(0.08), child: Icon(f['icon'] as IconData, color: brandColor, size: 20)),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(f['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
            Text(f['desc'] as String, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          ],
        )
      ],
    )).toList();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: Colors.white, border: Border.symmetric(horizontal: BorderSide(color: Colors.grey.shade100))),
      padding: EdgeInsets.symmetric(horizontal: padding, vertical: 20),
      child: isWeb 
        ? Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: featureWidgets)
        : Column(children: featureWidgets.map((w) => Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: w)).toList()),
    );
  }

  Widget _buildCategoriesSection(double padding, double width) {
    int crossAxisCount = width > 1100 ? 7 : (width > 700 ? 4 : 3);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padding, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Shop by Category", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Text("Find exactly what you need", style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                ],
              ),
              TextButton.icon(
                onPressed: () {},
                label: const Icon(Icons.chevron_right, size: 14),
                icon: Text("View all", style: TextStyle(color: brandColor, fontWeight: FontWeight.bold)),
              )
            ],
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 0.95,
            ),
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              var cat = _categories[index];
              return Container(
                decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade100), borderRadius: BorderRadius.circular(16)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {},
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(radius: 22, backgroundColor: brandColor.withOpacity(0.05), child: Icon(cat.icon, color: brandColor, size: 20)),
                      const SizedBox(height: 10),
                      Text(cat.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPopularStoresSection(double padding, double width) {
    int crossAxisCount = width > 950 ? 4 : (width > 650 ? 2 : 1);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padding, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Popular Stores", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Text("Top rated by our customers", style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                ],
              ),
              TextButton.icon(
                onPressed: () {},
                label: const Icon(Icons.chevron_right, size: 14),
                icon: Text("See all", style: TextStyle(color: brandColor, fontWeight: FontWeight.bold)),
              )
            ],
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.9,
            ),
            itemCount: _stores.length,
            itemBuilder: (context, index) {
              var store = _stores[index];
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          Image.network(store.imageUrl, height: 130, width: double.infinity, fit: BoxFit.cover),
                          Positioned(
                            top: 10,
                            left: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(6)),
                              child: Text(store.categoryName, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          )
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(store.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(height: 2),
                            Text("Trusted platform items.", style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.star, color: Colors.amber, size: 14),
                                const SizedBox(width: 2),
                                Text("${store.averageRating}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                Text(" (${store.totalReviews})", style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                                const SizedBox(width: 6),
                                Icon(Icons.access_time, color: Colors.grey.shade400, size: 12),
                                const SizedBox(width: 2),
                                Text(store.deliveryTime, style: const TextStyle(fontSize: 11)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTrendingProductsSection(double padding, double width) {
    int crossAxisCount = width > 950 ? 4 : (width > 650 ? 3 : 2);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padding, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Trending Products", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text("Most popular items right now", style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.76,
            ),
            itemCount: _products.length,
            itemBuilder: (context, index) {
              var product = _products[index];
              return Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade100)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Image.network(product.imageUrl, width: double.infinity, fit: BoxFit.cover)),
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text(product.description, style: TextStyle(fontSize: 11, color: Colors.grey.shade400), maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.star, color: Colors.amber, size: 12),
                                const SizedBox(width: 2),
                                Text("${product.rating}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("\$${product.price.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                Container(
                                  height: 28, width: 28,
                                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade200)),
                                  child: const Icon(Icons.add, size: 16, color: Colors.black54),
                                )
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFooterSection(double padding, bool isWeb) {
    return Container(
      color: Colors.white,
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: padding, vertical: 40),
      child: isWeb 
        ? Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: _getFooterColumns())
        : Column(crossAxisAlignment: CrossAxisAlignment.start, children: _getFooterColumns().map((c) => Padding(padding: const EdgeInsets.only(bottom: 24), child: c)).toList()),
    );
  }

  List<Widget> _getFooterColumns() {
    return [
      Theme(
        data: Theme.of(context).copyWith(iconTheme: const IconThemeData(color: Colors.black87)),
        child: SizedBox(
          width: 250,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("SmartMarket", style: TextStyle(color: brandColor, fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 12),
              Text("Your one-stop marketplace for local stores.", style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            ],
          ),
        ),
      ),
      _buildFooterLinkColumn("Shop", ["Categories", "All Stores"]),
      _buildFooterLinkColumn("Account", ["My Orders", "Cart"]),
      _buildFooterLinkColumn("Business", ["Store Dashboard"]),
    ];
  }

  Widget _buildFooterLinkColumn(String title, List<String> links) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 12),
        ...links.map((link) => Padding(padding: const EdgeInsets.symmetric(vertical: 4.0), child: Text(link, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)))).toList()
      ],
    );
  }
}