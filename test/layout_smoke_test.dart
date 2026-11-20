import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lab5_crossplatformvisualdesignpractice/main.dart';
import 'package:lab5_crossplatformvisualdesignpractice/models/mock_data.dart';

/// 六个界面在桌面（1440×900）与手机（500×900）下都不能溢出。
void main() {
  const List<String> routes = <String>[
    '/workbench',
    '/intake',
    '/outline',
    '/modules',
    '/workspace',
    '/delivery',
  ];

  setUp(T0Store.instance.reset);

  for (final String route in routes) {
    testWidgets('$route @ 1440x900 无溢出', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(T0App(initialRoute: route));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('$route @ 500x900 无溢出', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(500, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(T0App(initialRoute: route));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  }
}
