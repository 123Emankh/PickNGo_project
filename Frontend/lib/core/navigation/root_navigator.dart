// lib/core/navigation/root_navigator.dart
//
// مفتاح Navigator عام - لازم لأي widget مبني داخل MaterialApp.builder (زي
// ChatFloatingButton) يحتاج يفتح شاشة جديدة. الـ context يلي بيوصل builder
// هو فوق الـ Navigator الحقيقي بالشجرة (child يلي بيستقبله builder هو
// أصلًا الـ Navigator نفسه)، فـ Navigator.of(context) من هناك بيفشل
// (Null check operator used on a null value) - راجع main.dart.
import 'package:flutter/material.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
