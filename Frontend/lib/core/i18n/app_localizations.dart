import 'package:flutter/material.dart';
import 'translations/auth_translations.dart';
import 'translations/shopping_translations.dart';
import 'translations/checkout_translations.dart';
import 'translations/business_translations.dart';
import 'translations/admin_translations.dart';
import 'translations/landing_extra_translations.dart';
import 'translations/settings_translations.dart';
import 'translations/chatbot_translations.dart';
import 'translations/loyalty_translations.dart';

class AppLocalizations {
  static const Map<String, Map<String, String>> _baseTranslations = {
    'en': {
      'app_name': 'PickNGo',
      'features': 'Features',
      'how_it_works': 'How It Works',
      'for_you': 'For You',
      'stores': 'Stores',
      'log_in': 'Log in',
      'get_started': 'Get Started',
      'fast_delivery': 'Fast delivery from local stores',
      'headline': 'Pick anything.\nAnd *Go* anywhere',
      'description': 'Shop from restaurants, supermarkets, pharmacies, bookstores, and more — all in one place.',
      'browse_stores': 'Browse Stores',
      'view_categories': 'View Categories',
      'language_en': 'English',
      'language_ar': 'العربية',
      'language_fr': 'Français',
    },
    'ar': {
      'app_name': 'بيك إن قو',
      'features': 'الميزات',
      'how_it_works': 'كيف تعمل',
      'for_you': 'لك',
      'stores': 'المحلات',
      'log_in': 'تسجيل دخول',
      'get_started': 'ابدأ الآن',
      'fast_delivery': 'توصيل سريع من المحلات المحلية',
      'headline': 'اختار أي شي.\nو *Go* لأي مكان',
      'description': 'تسوق من المطاعم، السوبرماركت، الصيدليات، المكتبات والمزيد — في مكان واحد.',
      'browse_stores': 'تصفح المتاجر',
      'view_categories': 'عرض الفئات',
      'language_en': 'English',
      'language_ar': 'العربية',
      'language_fr': 'Français',
    },
    'fr': {
      'app_name': 'PickNGo',
      'features': 'Fonctionnalités',
      'how_it_works': 'Comment ça marche',
      'for_you': 'Pour vous',
      'stores': 'Magasins',
      'log_in': 'Se connecter',
      'get_started': 'Commencer',
      'fast_delivery': 'Livraison rapide des commerces locaux',
      'headline': "Choisis n'importe quoi.\nEt *Go* n'importe où",
      'description': 'Achetez dans des restaurants, supermarchés, pharmacies, librairies et plus — tout en un seul endroit.',
      'browse_stores': 'Parcourir les magasins',
      'view_categories': 'Voir les catégories',
      'language_en': 'English',
      'language_ar': 'العربية',
      'language_fr': 'Français',
    }
  };

  static final Map<String, Map<String, String>> _translations = _merge([
    _baseTranslations,
    authTranslations,
    shoppingTranslations,
    checkoutTranslations,
    businessTranslations,
    adminTranslations,
    landingExtraTranslations,
    settingsTranslations,
    chatbotTranslations,
    loyaltyTranslations,
  ]);

  static Map<String, Map<String, String>> _merge(
    List<Map<String, Map<String, String>>> parts,
  ) {
    final result = <String, Map<String, String>>{'en': {}, 'ar': {}, 'fr': {}};
    for (final part in parts) {
      for (final lang in part.keys) {
        result[lang] = {...?result[lang], ...part[lang]!};
      }
    }
    return result;
  }

  static String t(Locale locale, String key) {
    final lang = locale.languageCode;
    return _translations[lang]?[key] ?? _translations['en']![key] ?? key;
  }
}
