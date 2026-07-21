// src/utils/seed.js
// تشغيل: node src/utils/seed.js
require('dotenv').config();
const bcrypt = require('bcrypt');
const { sequelize, User, Category, Restaurant, Product, SystemSettings } = require('../models');
const GROUPING_DEFAULTS = require('../services/grouping/config');

const run = async () => {
  // ⚠️ هاد السكربت بينشئ حسابات بكلمات مرور معروفة ثابتة (Admin/Customer/
  // Restaurant/Driver/Company) - مفيدة جدًا بالتطوير بس backdoor حقيقي لو
  // انشغّلت غلط على قاعدة إنتاج. رفض كامل وفوري لو NODE_ENV=production.
  if (process.env.NODE_ENV === 'production') {
    console.error('❌ Refusing to run seed.js with NODE_ENV=production - this script creates accounts with well-known passwords.');
    process.exit(1);
  }

  try {
    await sequelize.authenticate();
    // ⚠️ الشيما بتنجهّز عبر migrations (npm run migrate) مش هون - هاد
    // السكربت بيدخل بيانات بس، ما بيغيّر شكل الجداول.

    // 1) الفئات
    const categoriesData = [
      { name: 'مطاعم', icon: 'UtensilsCrossed', sort_order: 1 },
      { name: 'سوبرماركت', icon: 'ShoppingCart', sort_order: 2 },
      { name: 'صيدليات', icon: 'Pill', sort_order: 3 },
      { name: 'ملابس', icon: 'Shirt', sort_order: 4 },
      { name: 'أثاث', icon: 'BookOpen', sort_order: 5 },
    ];

    const categories = [];
    for (const c of categoriesData) {
      const [cat] = await Category.findOrCreate({ where: { name: c.name }, defaults: c });
      categories.push(cat);
    }
    console.log(`✅ Categories ready: ${categories.length}`);

    // 1.5) إعدادات Grouped Delivery (صف وحيد id=1) - لوحة الأدمن (Delivery
    // Management → Grouped Delivery Settings) بتعدّله بدل ما نلمس الكود
    await SystemSettings.findOrCreate({
      where: { id: 1 },
      defaults: {
        grouped_delivery_enabled: GROUPING_DEFAULTS.GROUPED_DELIVERY_ENABLED,
        max_store_distance: GROUPING_DEFAULTS.MAX_STORE_DISTANCE_KM,
        max_delivery_distance: GROUPING_DEFAULTS.MAX_DROPOFF_DISTANCE_KM,
        max_time_between_orders: GROUPING_DEFAULTS.MAX_GROUPING_WINDOW_MIN,
        max_orders_per_group: GROUPING_DEFAULTS.MAX_ORDERS_PER_GROUP,
        max_stores_per_trip: GROUPING_DEFAULTS.MAX_STORES_PER_TRIP,
        minimum_driver_rating: GROUPING_DEFAULTS.MINIMUM_DRIVER_RATING,
        auto_assign_driver: GROUPING_DEFAULTS.AUTO_ASSIGN_DRIVER
      }
    });
    console.log('✅ System settings ready');

    // 2) صاحب متجر تجريبي (لازم يكون له user)
    const hashedPassword = await bcrypt.hash('123456', 10);
    const [vendorUser] = await User.findOrCreate({
      where: { email: 'vendor@picknGo.test' },
      defaults: {
        full_name: 'Demo Vendor',
        email: 'vendor@picknGo.test',
        password: hashedPassword,
        phone: '0590000000',
        role: 'Restaurant',
        business_type: 'Restaurant',
        status: 'Approved',
        is_verified: true
      }
    });

    // 3) متجر تجريبي
    const [store] = await Restaurant.findOrCreate({
      where: { name: 'مطعم بيك اند جو' },
      defaults: {
        user_id: vendorUser.user_id,
        category_id: categories[0].category_id,
        description: 'أشهى الوجبات السريعة',
        cuisine_type: 'Fast Food',
        image_url: 'https://images.unsplash.com/photo-1550547660-d9450f859349',
        address: 'شارع رئيسي، رام الله',
        location_lat: 31.9038,
        location_lng: 35.2034,
        city: 'رام الله والبيرة',
        region: 'West Bank',
        phone: '022960000',
        delivery_fee: 10.00,
        // ✅ باج حقيقي كان موجود: rating/review_count هون كانوا أرقام
        // مفبركة بدون أي صف Review حقيقي وراءها - نفس فئة باج "الوصف
        // الوهمي" اللي انصلح بالتدقيق السابق (راجع الميموري). تُركوا فاضيين
        // هلق (0.00/0 الافتراضي بالموديل) - يتحدثوا فقط لما يصير تقييم حقيقي.
        approval_status: 'Approved',
        is_active: true
      }
    });
    console.log(`✅ Store ready: ${store.name}`);

    // 4) منتجات تجريبية
    const productsData = [
      { name: 'برجر لحم', description: 'برجر لحم مشوي مع جبنة وخس', price: 35, image_url: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd' },
      { name: 'بيتزا مارجريتا', description: 'بيتزا إيطالية كلاسيكية', price: 45, image_url: 'https://images.unsplash.com/photo-1574071318508-1cdbab80d002' },
      { name: 'بطاطا مقلية', description: 'بطاطا مقرمشة مع صوص', price: 15, image_url: 'https://images.unsplash.com/photo-1573080496219-bb080dd4f877' },
    ];

    for (const p of productsData) {
      await Product.findOrCreate({
        where: { name: p.name, restaurant_id: store.restaurant_id },
        defaults: { ...p, restaurant_id: store.restaurant_id }
      });
    }
    console.log(`✅ Products ready: ${productsData.length}`);

    // 5) متاجر إضافية بفئات مختلفة (عشان تصفح الزبون يبيّن تنوّع حقيقي، مش متجر واحد بس)
    const moreStoresData = [
      {
        email: 'supermarket@picknGo.test',
        storeName: 'سوبرماركت الأمل',
        categoryIndex: 1, // سوبرماركت
        description: 'كل احتياجاتك اليومية بمكان واحد',
        image_url: 'https://images.unsplash.com/photo-1542838132-92c53300491e',
        address: 'شارع الإرسال، رام الله',
        city: 'رام الله والبيرة',
        delivery_fee: 8,
        products: [
          { name: 'حليب طازج', description: 'لتر حليب طازج كامل الدسم', price: 8, image_url: 'https://images.unsplash.com/photo-1550583724-b2692b85b150' },
          { name: 'خبز أبيض', description: 'ربطة خبز طازج', price: 4, image_url: 'https://images.unsplash.com/photo-1509440159596-0249088772ff' },
          { name: 'بيض بلدي', description: 'طبق بيض بلدي 30 حبة', price: 18, image_url: 'https://images.unsplash.com/photo-1518569656558-1f25e69d93d7' },
        ],
      },
      {
        email: 'pharmacy@picknGo.test',
        storeName: 'صيدلية الشفاء',
        categoryIndex: 2, // صيدليات
        description: 'أدوية ومستلزمات طبية بتوصيل سريع',
        image_url: 'https://images.unsplash.com/photo-1584308666744-24d5c474f2ae',
        address: 'شارع المستشفى، نابلس',
        city: 'نابلس',
        delivery_fee: 10,
        products: [
          { name: 'فيتامين سي', description: 'علبة فيتامين سي فوّار', price: 12, image_url: 'https://images.unsplash.com/photo-1550572017-edd951b55104' },
          { name: 'معقم يدين', description: 'معقم يدين 250 مل', price: 6, image_url: 'https://images.unsplash.com/photo-1584744982526-93aac5b47c4b' },
        ],
      },
      {
        email: 'clothes@picknGo.test',
        storeName: 'بوتيك الأناقة',
        categoryIndex: 3, // ملابس
        description: 'أحدث صيحات الموضة للرجال والنساء',
        image_url: 'https://images.unsplash.com/photo-1445205170230-053b83016050',
        address: 'شارع الجامعة، الخليل',
        city: 'الخليل',
        delivery_fee: 12,
        products: [
          { name: 'تيشيرت قطن', description: 'تيشيرت قطن 100% مقاسات متعددة', price: 25, image_url: 'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab' },
          { name: 'جينز كلاسيك', description: 'بنطلون جينز مريح', price: 55, image_url: 'https://images.unsplash.com/photo-1542272604-787c3835535d' },
        ],
      },
      {
        email: 'furniture@picknGo.test',
        storeName: 'أثاث المنزل الذهبي',
        categoryIndex: 4, // أثاث
        description: 'أثاث منزلي ومكتبي بجودة عالية',
        image_url: 'https://images.unsplash.com/photo-1567016432779-094069958ea5',
        address: 'شارع الصناعة، بيت لحم',
        city: 'بيت لحم',
        delivery_fee: 20,
        products: [
          { name: 'كرسي مكتب', description: 'كرسي مكتب مريح قابل للتعديل', price: 180, image_url: 'https://images.unsplash.com/photo-1592078615290-033ee584e267' },
          { name: 'طاولة قهوة', description: 'طاولة قهوة خشبية أنيقة', price: 220, image_url: 'https://images.unsplash.com/photo-1533090161767-e6ffed986c88' },
        ],
      },
    ];

    for (const s of moreStoresData) {
      const hashedPw = await bcrypt.hash('123456', 10);
      const [ownerUser] = await User.findOrCreate({
        where: { email: s.email },
        defaults: {
          full_name: s.storeName,
          email: s.email,
          password: hashedPw,
          phone: '0590000001',
          role: 'Restaurant',
          business_type: 'Restaurant',
          status: 'Approved',
          is_verified: true
        }
      });

      const [newStore] = await Restaurant.findOrCreate({
        where: { name: s.storeName },
        defaults: {
          user_id: ownerUser.user_id,
          category_id: categories[s.categoryIndex].category_id,
          description: s.description,
          image_url: s.image_url,
          address: s.address,
          location_lat: 31.9,
          location_lng: 35.2,
          city: s.city,
          region: 'West Bank',
          phone: '022960001',
          delivery_fee: s.delivery_fee,
          approval_status: 'Approved',
          is_active: true
        }
      });

      for (const p of s.products) {
        await Product.findOrCreate({
          where: { name: p.name, restaurant_id: newStore.restaurant_id },
          defaults: { ...p, restaurant_id: newStore.restaurant_id }
        });
      }

      console.log(`✅ Store ready: ${newStore.name} (${s.products.length} products)`);
    }

    // 5.5) محلات حقيقية بفلسطين (أسماء وأحياء حقيقية من بحث ويب - إحداثيات
    // مركز المدينة تقريبية زي باقي متاجر السييد، مش عنوان دقيق GPS لكل محل،
    // وبعض أرقام الهواتف/المنتجات تمثيلية لعدم توفرها بمصدر موثوق عام)
    const realStoresData = [
      {
        email: 'misterbaker@picknGo.test',
        storeName: 'مطعم مستر بيكر',
        categoryIndex: 0, // مطاعم
        description: 'من أعرق مطاعم الشاورما بنابلس - مشهور بالشاورما مع المثومة',
        image_url: 'https://images.unsplash.com/photo-1633436375231-745a9e3a4c17?w=600',
        address: 'شارع فيصل، البلدة القديمة، نابلس',
        location_lat: 32.2211, location_lng: 35.2544,
        city: 'نابلس', delivery_fee: 8,
        products: [
          { name: 'شاورما عربي بالمثومة', description: 'شاورما دجاج مع صوص المثومة الخاص وبطاطا حارة', price: 28, image_url: 'https://images.unsplash.com/photo-1529006557810-274b9b2fc783?w=600' },
          { name: 'شاورما دجاج صحن', description: 'صحن شاورما دجاج مع أرز وسلطات', price: 32, image_url: 'https://images.unsplash.com/photo-1529193591184-b1d58069ecdd?w=600' },
        ],
      },
      {
        email: 'charcoal@picknGo.test',
        storeName: 'Charcoal Restaurant & Cafe',
        categoryIndex: 0, // مطاعم
        description: 'مطعم ومقهى معروف برام الله - أطباق مشاوي وبرغر على الفحم',
        image_url: 'https://images.unsplash.com/photo-1550547660-d9450f859349?w=600',
        address: 'مجمع الوايفز، شارع مجمع فلسطين الطبي، رام الله',
        location_lat: 31.9038, location_lng: 35.2034,
        city: 'رام الله والبيرة', delivery_fee: 10,
        products: [
          { name: 'برجر مشوي على الفحم', description: 'برجر لحم بلدي مشوي على الفحم مع جبنة وصوص خاص', price: 42, image_url: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=600' },
          { name: 'دجاج مشوي', description: 'صدر دجاج متبل مشوي على الفحم', price: 38, image_url: 'https://images.unsplash.com/photo-1598515213692-5f252f0e0dfa?w=600' },
        ],
      },
      {
        email: 'karaz@picknGo.test',
        storeName: 'سوبرماركت كرز',
        categoryIndex: 1, // سوبرماركت
        description: 'سلسلة سوبرماركت فلسطينية بتوصل لكل مناطق الضفة الغربية',
        image_url: 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=600',
        address: 'الشارع الرئيسي، رام الله',
        location_lat: 31.9010, location_lng: 35.2050,
        city: 'رام الله والبيرة', delivery_fee: 8,
        products: [
          { name: 'سلة خضار وفواكه طازجة', description: 'تشكيلة خضار وفواكه موسمية طازجة', price: 15, image_url: 'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=600' },
          { name: 'منتجات ألبان محلية', description: 'حليب وأجبان ولبنة من منتجين محليين', price: 12, image_url: 'https://images.unsplash.com/photo-1610832958506-aa56368176cf?w=600' },
        ],
      },
      {
        email: 'bravo@picknGo.test',
        storeName: 'سوبرماركت برافو',
        categoryIndex: 1, // سوبرماركت
        description: 'سلسلة سوبرماركت معروفة بفروع بنابلس (بيت وزن) ورام الله',
        image_url: 'https://images.unsplash.com/photo-1578916171728-46686eac8d58?w=600',
        address: 'بيت وزن، نابلس',
        location_lat: 32.2250, location_lng: 35.2600,
        city: 'نابلس', delivery_fee: 8,
        products: [
          { name: 'بقالة أساسية', description: 'أرز، سكر، زيت وبقوليات', price: 10, image_url: 'https://images.unsplash.com/photo-1596797882317-3600101927d1?w=600' },
          { name: 'معلبات متنوعة', description: 'تشكيلة معلبات فول وحمص وذرة', price: 8, image_url: 'https://images.unsplash.com/photo-1584736286279-dddd0dbdb499?w=600' },
        ],
      },
      {
        email: 'alsayedpharmacy@picknGo.test',
        storeName: 'صيدلية السيد',
        categoryIndex: 2, // صيدليات
        description: 'من أقدم الصيدليات برام الله - أكتر من 55 عام بالخدمة',
        image_url: 'https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?w=600',
        address: 'شارع ركب، رام الله',
        location_lat: 31.9060, location_lng: 35.2040,
        city: 'رام الله والبيرة', delivery_fee: 8,
        products: [
          { name: 'أدوية بدون وصفة', description: 'مسكنات وأدوية زكام ورشح شائعة', price: 15, image_url: 'https://images.unsplash.com/photo-1550572017-edd951b55104?w=600' },
          { name: 'فيتامينات ومكملات', description: 'فيتامين سي وحديد ومكملات يومية', price: 20, image_url: 'https://images.unsplash.com/photo-1550572017-edd951b55104?w=600' },
        ],
      },
      {
        email: 'alnoorpharmacy@picknGo.test',
        storeName: 'صيدلية النور',
        categoryIndex: 2, // صيدليات
        description: 'صيدلية معروفة برام الله والبيرة',
        image_url: 'https://images.unsplash.com/photo-1587854692152-cbe660dbde88?w=600',
        address: 'رام الله والبيرة',
        location_lat: 31.9080, location_lng: 35.2070,
        city: 'رام الله والبيرة', delivery_fee: 8,
        products: [
          { name: 'مستلزمات عناية شخصية', description: 'منتجات عناية بالبشرة والشعر', price: 18, image_url: 'https://images.unsplash.com/photo-1584744982526-93aac5b47c4b?w=600' },
          { name: 'معقمات ومطهرات', description: 'معقم يدين ومطهرات منزلية', price: 6, image_url: 'https://images.unsplash.com/photo-1584744982526-93aac5b47c4b?w=600' },
        ],
      },
      {
        email: 'romafashion@picknGo.test',
        storeName: 'Roma Fashion',
        categoryIndex: 3, // ملابس
        description: 'محل ملابس رجالية معروف - دوار المنارة، مقابل بنك القدس',
        image_url: 'https://images.unsplash.com/photo-1445205170230-053b83016050?w=600',
        address: 'شارع ركب، دوار المنارة، رام الله',
        location_lat: 31.9040, location_lng: 35.2038,
        city: 'رام الله والبيرة', delivery_fee: 10,
        products: [
          { name: 'قميص رجالي كلاسيك', description: 'قميص قطن رسمي مقاسات متعددة', price: 65, image_url: 'https://images.unsplash.com/photo-1602810318383-e386cc2a3ccf?w=600' },
          { name: 'بنطلون رجالي قماش', description: 'بنطلون قماش كلاسيك مريح', price: 90, image_url: 'https://images.unsplash.com/photo-1542272604-787c3835535d?w=600' },
        ],
      },
      {
        email: 'trendystore@picknGo.test',
        storeName: 'Trendy Store',
        categoryIndex: 3, // ملابس
        description: 'محل ملابس نسائية معروف - شارع الإرسال، مقابل KFC',
        image_url: 'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?w=600',
        address: 'شارع الإرسال، رام الله',
        location_lat: 31.8990, location_lng: 35.2010,
        city: 'رام الله والبيرة', delivery_fee: 10,
        products: [
          { name: 'فستان نسائي عصري', description: 'فستان يومي عصري بقصّة مريحة', price: 110, image_url: 'https://images.unsplash.com/photo-1595950653106-6c9ebd614d3a?w=600' },
          { name: 'بلوزة نسائية', description: 'بلوزة قطن قصّة عصرية', price: 55, image_url: 'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?w=600' },
        ],
      },
      {
        email: 'aminfurniture@picknGo.test',
        storeName: 'أمين للموبيليا',
        categoryIndex: 4, // أثاث
        description: 'تصنيع واستيراد وتركيب أثاث منزلي ومكتبي - بيتونيا، المنطقة الصناعية',
        image_url: 'https://images.unsplash.com/photo-1567016432779-094069958ea5?w=600',
        address: 'المنطقة الصناعية، بيتونيا، رام الله',
        location_lat: 31.8950, location_lng: 35.1750,
        city: 'رام الله والبيرة', delivery_fee: 25,
        products: [
          { name: 'كنبة 3 مقاعد', description: 'كنبة قماش مريحة 3 مقاعد', price: 850, image_url: 'https://images.unsplash.com/photo-1550254478-ead40cc54513?w=600' },
          { name: 'طاولة طعام خشبية', description: 'طاولة طعام خشب طبيعي 6 كراسي', price: 450, image_url: 'https://images.unsplash.com/photo-1533090161767-e6ffed986c88?w=600' },
        ],
      },
      {
        email: 'americanfurniture@picknGo.test',
        storeName: 'الشركة الأمريكية للأثاث',
        categoryIndex: 4, // أثاث
        description: 'أثاث منزلي ومكتبي - المنطقة الصناعية، رام الله',
        image_url: 'https://images.unsplash.com/photo-1555041469-a586c61ea9bc?w=600',
        address: 'المنطقة الصناعية، رام الله',
        location_lat: 31.8940, location_lng: 35.1770,
        city: 'رام الله والبيرة', delivery_fee: 25,
        products: [
          { name: 'غرفة نوم كاملة', description: 'طقم غرفة نوم خشبي كامل مع دولاب', price: 2200, image_url: 'https://images.unsplash.com/photo-1567016432779-094069958ea5?w=600' },
          { name: 'خزانة ملابس', description: 'خزانة ملابس خشبية 4 أبواب', price: 600, image_url: 'https://images.unsplash.com/photo-1592078615290-033ee584e267?w=600' },
        ],
      },
      // ✅ محلات حقيقية زوّدها المستخدم بالاسم/الفئة/المدينة/أوقات الدوام
      // مباشرة (مو من بحث ويب زي فوق) - الشعارات: KFC/رامي ليفي من Wikimedia
      // Commons (شعار رسمي متاح عام)، و90s Burger/كاش ببلاش روابط Facebook
      // CDN بعتها المستخدم بنفسها - ملاحظة: روابط Facebook هاي موقّعة وبتنتهي
      // صلاحيتها بعد فترة (بحاجة استبدال برابط دائم لاحقًا).
      {
        email: 'khreimpharmacy@picknGo.test',
        storeName: 'صيدلية خريم',
        categoryIndex: 2, // صيدليات
        description: 'صيدلية معروفة بنابلس',
        image_url: 'https://images.unsplash.com/photo-1587854692152-cbe660dbde88?w=600',
        address: 'مقابل مستشفى الاتحاد، نابلس',
        location_lat: 32.2211, location_lng: 35.2544,
        city: 'نابلس',
        opening_time: '07:00:00', closing_time: '00:00:00', // يوميًا 7ص - 12 منتصف الليل
        delivery_fee: 8,
        products: [
          { name: 'أدوية بدون وصفة', description: 'مسكنات وأدوية زكام ورشح شائعة', price: 15, image_url: 'https://images.unsplash.com/photo-1550572017-edd951b55104?w=600' },
          { name: 'فيتامينات ومكملات', description: 'فيتامين سي وحديد ومكملات يومية', price: 20, image_url: 'https://images.unsplash.com/photo-1550572017-edd951b55104?w=600' },
        ],
      },
      {
        email: 'kfc@picknGo.test',
        storeName: 'KFC',
        categoryIndex: 0, // مطاعم
        description: 'سلسلة مطاعم دجاج مقلي عالمية',
        image_url: 'https://upload.wikimedia.org/wikipedia/commons/b/b8/KFC_logo.png',
        address: 'شارع الإرسال، رام الله',
        location_lat: 31.9038, location_lng: 35.2034,
        city: 'رام الله والبيرة',
        // ⚠️ الساعات المرسلة كانت "10:00 ص – 12:00 م" (يعني ضهرًا) وهاد غريب
        // لمطعم فاست فود - افترضت إنه المقصود منتصف الليل (00:00) زي باقي
        // المطاعم، عدّليها من لوحة الأدمن لو مو هيك
        opening_time: '10:00:00', closing_time: '00:00:00',
        delivery_fee: 10,
        products: [
          { name: 'وجبة دجاج مقرمش', description: 'قطع دجاج مقرمشة مع بطاطا وصوص', price: 32, image_url: 'https://images.unsplash.com/photo-1626645738196-c2a7c87a8f58?w=600' },
          { name: 'برجر زنجر', description: 'برجر دجاج حار مع جبنة', price: 28, image_url: 'https://images.unsplash.com/photo-1610614819513-58e34989848b?w=600' },
        ],
      },
      {
        email: 'ramilevy@picknGo.test',
        storeName: 'رامي ليفي',
        categoryIndex: 1, // سوبرماركت
        description: 'سلسلة سوبرماركت',
        image_url: 'https://upload.wikimedia.org/wikipedia/commons/c/cb/Levy_Corporate_Logo.png',
        address: 'شارع هعومان 15، تلبيوت، القدس',
        location_lat: 31.7683, location_lng: 35.2137,
        city: 'القدس', region: 'Israel',
        opening_time: '08:00:00', closing_time: '22:00:00',
        delivery_fee: 12,
        products: [
          { name: 'سلة خضار وفواكه', description: 'تشكيلة خضار وفواكه طازجة', price: 15, image_url: 'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=600' },
          { name: 'بقالة أساسية', description: 'أرز، سكر، زيت وبقوليات', price: 10, image_url: 'https://images.unsplash.com/photo-1596797882317-3600101927d1?w=600' },
        ],
      },
      {
        email: '90sburger@picknGo.test',
        storeName: '90s Burger',
        categoryIndex: 0, // مطاعم
        description: 'مطعم برجر بنابلس',
        image_url: 'https://scontent.fjrs10-1.fna.fbcdn.net/v/t39.30808-6/282099206_5491753117611790_1751136163365502597_n.jpg?stp=dst-jpg_tt6&cstp=mx1159x1159&ctp=s1159x1159&_nc_cat=103&ccb=1-7&_nc_sid=6ee11a&_nc_ohc=3SzhJ8QjYwIQ7kNvwGUQG56&_nc_oc=AdoslGJIHrM2fmID9OD5ZM8XXxfPQYreEEs_I4o_AfK140U7c8iT-sJzduc4GYs1eAQ&_nc_zt=23&_nc_ht=scontent.fjrs10-1.fna&_nc_gid=zUw1_S0xYxj-SZcUnPvwFQ&_nc_ss=7b2a8&oh=00_AQAdisrFccELGrJGbxBH_jGj21T7LREcF_pUB_sTvrEV3Q&oe=6A65AA5F',
        address: 'Rafidia, Blaibleh street, Nablus',
        location_lat: 32.2244, location_lng: 35.2350,
        city: 'نابلس',
        opening_time: '09:00:00', closing_time: '00:00:00', // يوميًا 9ص - 12 منتصف الليل
        delivery_fee: 8,
        products: [
          { name: 'برجر كلاسيك', description: 'برجر لحم بجبنة وخس وطماطم', price: 30, image_url: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=600' },
          { name: 'برجر مزدوج', description: 'برجر لحم دبل مع جبنة شيدر', price: 40, image_url: 'https://images.unsplash.com/photo-1553979459-d2229ba7433b?w=600' },
        ],
      },
      {
        email: 'cashbblash@picknGo.test',
        storeName: 'كاش ببلاش',
        // ملاحظة: بيبيع مفروشات وأدوات كهربائية ومنزلية - أقرب فئة متوفرة
        // بالتطبيق هي "أثاث"، ما في فئة مخصصة للأدوات الكهربائية لسا
        categoryIndex: 4, // أثاث
        description: 'مفروشات وأدوات كهربائية ومنزلية',
        image_url: 'https://scontent.fjrs10-1.fna.fbcdn.net/v/t39.30808-6/263151895_1064106704413419_4167064150266844223_n.jpg?stp=dst-jpg_tt6&cstp=mx960x960&ctp=s960x960&_nc_cat=100&ccb=1-7&_nc_sid=6ee11a&_nc_ohc=cNgte4eOUnIQ7kNvwFXjQ90&_nc_oc=Adr3J19IRObG609nCGqyEnJVQlcLHdkDFg9gCK9oUZUsSEhSkHjA9Hhg5OR0BVtkaRM&_nc_zt=23&_nc_ht=scontent.fjrs10-1.fna&_nc_gid=ETQ9yfbaA-NHVYfIWfUA8Q&_nc_ss=7b2a8&oh=00_AQDa-eEMqxI6eBPRGcQpQj0G2RJlBsZtPatSdiu-lWrAtA&oe=6A657DF3',
        address: 'بيت فوريك، الشارع الرئيسي، نابلس',
        location_lat: 32.2211, location_lng: 35.2544,
        city: 'نابلس',
        delivery_fee: 15,
        products: [
          { name: 'خلاط كهربائي', description: 'خلاط كهربائي متعدد السرعات', price: 120, image_url: 'https://images.unsplash.com/photo-1570222094114-d054a817e56b?w=600' },
          { name: 'طقم كنب', description: 'طقم كنب منزلي مريح', price: 900, image_url: 'https://images.unsplash.com/photo-1550254478-ead40cc54513?w=600' },
        ],
      },
    ];

    for (const s of realStoresData) {
      const hashedPw = await bcrypt.hash('123456', 10);
      const [ownerUser] = await User.findOrCreate({
        where: { email: s.email },
        defaults: {
          full_name: s.storeName,
          email: s.email,
          password: hashedPw,
          phone: s.phone || '0590000002',
          role: 'Restaurant',
          business_type: 'Restaurant',
          status: 'Approved',
          is_verified: true
        }
      });

      const [newStore] = await Restaurant.findOrCreate({
        where: { name: s.storeName },
        defaults: {
          user_id: ownerUser.user_id,
          category_id: categories[s.categoryIndex].category_id,
          description: s.description,
          image_url: s.image_url,
          address: s.address,
          location_lat: s.location_lat,
          location_lng: s.location_lng,
          city: s.city,
          region: s.region || 'West Bank',
          phone: s.phone || '0590000002',
          delivery_fee: s.delivery_fee,
          opening_time: s.opening_time || null,
          closing_time: s.closing_time || null,
          approval_status: 'Approved',
          is_active: true
        }
      });

      for (const p of s.products) {
        await Product.findOrCreate({
          where: { name: p.name, restaurant_id: newStore.restaurant_id },
          defaults: { ...p, restaurant_id: newStore.restaurant_id }
        });
      }

      console.log(`✅ Real store ready: ${newStore.name} (${s.products.length} products)`);
    }

    // 6) حسابات دائمة ثابتة لكل دور - بكلمات مرور معروفة، لتسريع التطوير
    // والاختبار اليدوي (بدل ما تنعاد كتابة حساب جديد كل مرة). findOrCreate
    // بالإيميل يعني بتضل موجودة بعد أي إعادة تشغيل لهاد السكربت.
    // Company (شركة توصيل) لازم تتعمل قبل Driver عشان نربطها بـ company_id.
    const devAccountsPassword = await bcrypt.hash('Dev@12345', 10);

    const [devAdmin] = await User.findOrCreate({
      where: { email: 'admin@dev.test' },
      defaults: {
        full_name: 'Dev Admin',
        email: 'admin@dev.test',
        password: devAccountsPassword,
        phone: '0590000010',
        role: 'Admin',
        status: 'Approved',
        is_verified: true
      }
    });

    const [devCustomer] = await User.findOrCreate({
      where: { email: 'customer@dev.test' },
      defaults: {
        full_name: 'Dev Customer',
        email: 'customer@dev.test',
        password: devAccountsPassword,
        phone: '0590000011',
        role: 'Customer',
        status: 'Approved',
        is_verified: true
      }
    });

    const [devRestaurantOwner] = await User.findOrCreate({
      where: { email: 'restaurant@dev.test' },
      defaults: {
        full_name: 'Dev Restaurant Owner',
        email: 'restaurant@dev.test',
        password: devAccountsPassword,
        phone: '0590000012',
        role: 'Restaurant',
        business_type: 'Restaurant',
        status: 'Approved',
        is_verified: true
      }
    });

    await Restaurant.findOrCreate({
      where: { name: 'متجر Dev التجريبي' },
      defaults: {
        user_id: devRestaurantOwner.user_id,
        category_id: categories[0].category_id,
        description: 'متجر ثابت لحساب المطور - لا يُحذف',
        image_url: 'https://images.unsplash.com/photo-1550547660-d9450f859349',
        address: 'عنوان تجريبي',
        location_lat: 31.9,
        location_lng: 35.2,
        city: 'رام الله والبيرة',
        region: 'West Bank',
        phone: '022960099',
        delivery_fee: 10.00,
        approval_status: 'Approved',
        is_active: true
      }
    });

    const [devCompany] = await User.findOrCreate({
      where: { email: 'company@dev.test' },
      defaults: {
        full_name: 'Dev Delivery Company',
        email: 'company@dev.test',
        password: devAccountsPassword,
        phone: '0590000013',
        role: 'Driver',
        business_type: 'Fleet / Company',
        status: 'Approved',
        is_verified: true
      }
    });

    await User.findOrCreate({
      where: { email: 'driver@dev.test' },
      defaults: {
        full_name: 'Dev Driver',
        email: 'driver@dev.test',
        password: devAccountsPassword,
        phone: '0590000014',
        role: 'Driver',
        business_type: 'Motorcycle',
        company_id: devCompany.user_id,
        company_join_status: 'Approved',
        status: 'Approved',
        is_verified: true
      }
    });

    console.log('✅ Dev seed accounts ready (password for all: Dev@12345):');
    console.log('   ├─ Admin:      admin@dev.test');
    console.log('   ├─ Customer:   customer@dev.test');
    console.log('   ├─ Restaurant: restaurant@dev.test');
    console.log('   ├─ Company:    company@dev.test');
    console.log('   └─ Driver:     driver@dev.test (joined to the Dev company above)');

    console.log('\n🎉 Seed completed successfully!');
    process.exit(0);
  } catch (error) {
    console.error('❌ Seed error:', error);
    process.exit(1);
  }
};

run();
