import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lab5_crossplatformvisualdesignpractice/main.dart';
import 'package:lab5_crossplatformvisualdesignpractice/models/mock_data.dart';
import 'package:lab5_crossplatformvisualdesignpractice/theme/palette.dart';

/// r3 顶栏契约：
/// 1. 右上角的「肖 / 王 / 何 +1」头像组彻底不存在；
/// 2. 项目名 + 已自动保存只在五个流程路由上出现，工作台 / 首页态隐藏；
/// 3. 右侧元素顺序固定，相邻间距统一 16px，顶栏高度全程 72px；
/// 4. 切主题时这一段的颜色跟着主题走，位置不变。
const List<String> _projectRoutes = <String>[
  '/intake',
  '/outline',
  '/modules',
  '/workspace',
  '/delivery',
];

const List<String> _allRoutes = <String>[
  '/workbench',
  '/intake',
  '/outline',
  '/modules',
  '/workspace',
  '/delivery',
];

const Key _topbar = Key('topbar');
const Key _name = Key('topbar-project-name');
const Key _save = Key('topbar-save');
const Key _theme = Key('topbar-theme');
const Key _add = Key('topbar-add');

Future<void> _pumpAt(
  WidgetTester tester,
  String route, {
  Size size = const Size(1440, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  // 每次给一个新的 key：同一测试里连 pump 两次时，T0App 会被当成同一个 widget
  // 复用，initialRoute 改了也不会重新导航（之前的「高度一致」会量到同一个页面）。
  await tester.pumpWidget(
    T0App(key: ValueKey<String>('$route-${size.width}'), initialRoute: route),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(T0Store.instance.reset);

  group('头像组已删除', () {
    for (final String route in _allRoutes) {
      testWidgets('$route 顶栏没有姓氏头像 / +1', (WidgetTester tester) async {
        await _pumpAt(tester, route);
        for (final String glyph in <String>['肖', '王', '何', '翊', '+1']) {
          expect(
            find.text(glyph),
            findsNothing,
            reason: '$route 上还残留头像「$glyph」',
          );
        }
      });
    }
  });

  group('项目名 + 已自动保存只在项目内显示', () {
    testWidgets('工作台隐藏，右侧只剩主题按钮 + 加号', (WidgetTester tester) async {
      await _pumpAt(tester, '/workbench');
      expect(find.byKey(_name), findsNothing);
      expect(find.text('已自动保存'), findsNothing);
      expect(find.byKey(_save), findsNothing);
      expect(find.byKey(_theme), findsOneWidget);
      expect(find.byKey(_add), findsOneWidget);
    });

    testWidgets('首页态（/ 落到工作台）同样隐藏', (WidgetTester tester) async {
      await _pumpAt(tester, '/');
      expect(find.byKey(_name), findsNothing);
      expect(find.text('已自动保存'), findsNothing);
      expect(find.byKey(_theme), findsOneWidget);
      expect(find.byKey(_add), findsOneWidget);
    });

    for (final String route in _projectRoutes) {
      testWidgets('$route 显示项目名 + 已自动保存', (WidgetTester tester) async {
        await _pumpAt(tester, route);
        expect(find.byKey(_name), findsOneWidget);
        // 工作区画布里也有项目标题，所以按 key 取文本，不按全页文本计数
        expect(
          tester.widget<Text>(find.byKey(_name)).data,
          T0Store.instance.projectName,
        );
        expect(find.text('已自动保存'), findsOneWidget);
        expect(find.byKey(_save), findsOneWidget);
      });
    }

    testWidgets('从项目 pop 回工作台后收起', (WidgetTester tester) async {
      await _pumpAt(tester, '/intake');
      expect(find.byKey(_name), findsOneWidget);

      final NavigatorState nav = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      nav.pop();
      await tester.pumpAndSettle();

      expect(find.byKey(_name), findsNothing);
      expect(find.text('已自动保存'), findsNothing);
      expect(find.byKey(_theme), findsOneWidget);
      expect(find.byKey(_add), findsOneWidget);
    });
  });

  group('右侧布局：顺序 / 间距 / 高度', () {
    testWidgets('1440 下顺序为 项目名 → 已自动保存 → 主题 → 加号，间距均 16px', (
      WidgetTester tester,
    ) async {
      await _pumpAt(tester, '/intake');
      final Rect name = tester.getRect(find.byKey(_name));
      final Rect save = tester.getRect(find.byKey(_save));
      final Rect theme = tester.getRect(find.byKey(_theme));
      final Rect add = tester.getRect(find.byKey(_add));

      // 从左到右
      expect(name.right, lessThanOrEqualTo(save.left));
      expect(save.right, lessThanOrEqualTo(theme.left));
      expect(theme.right, lessThanOrEqualTo(add.left));

      // 统一 16px
      expect(save.left - name.right, moreOrLessEquals(16, epsilon: 0.01));
      expect(theme.left - save.right, moreOrLessEquals(16, epsilon: 0.01));
      expect(add.left - theme.right, moreOrLessEquals(16, epsilon: 0.01));

      // 同一水平中线
      final double midY = name.center.dy;
      for (final Rect r in <Rect>[save, theme, add]) {
        expect(r.center.dy, moreOrLessEquals(midY, epsilon: 0.01));
      }

      // 加号贴右边距 24
      expect(1440 - add.right, moreOrLessEquals(24, epsilon: 0.01));
    });

    testWidgets('工作台上主题按钮与加号的间距同样是 16px', (WidgetTester tester) async {
      await _pumpAt(tester, '/workbench');
      final Rect theme = tester.getRect(find.byKey(_theme));
      final Rect add = tester.getRect(find.byKey(_add));
      expect(add.left - theme.right, moreOrLessEquals(16, epsilon: 0.01));
      expect(1440 - add.right, moreOrLessEquals(24, epsilon: 0.01));
    });

    testWidgets('四个状态顶栏高度一致（72）', (WidgetTester tester) async {
      final Map<String, double> heights = <String, double>{};
      for (final String route in _allRoutes) {
        await _pumpAt(tester, route);
        heights[route] = tester.getRect(find.byKey(_topbar)).height;
        expect(heights[route], moreOrLessEquals(72, epsilon: 0.01));
      }
    });

    testWidgets('手机宽度下：工作台不显示项目名，材料输入显示', (WidgetTester tester) async {
      await _pumpAt(tester, '/workbench', size: const Size(500, 900));
      expect(find.byKey(_name), findsNothing);
      expect(find.byKey(_theme), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _pumpAt(tester, '/intake', size: const Size(500, 900));
      expect(find.byKey(_name), findsOneWidget);
      expect(find.byKey(_theme), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // 平板断点（700..1100）上右侧多出「项目名 + 已保存」，最窄处不能挤出黄条
    for (final double width in <double>[700, 800, 1099]) {
      testWidgets('平板 ${width.toInt()} 宽：项目内顶栏不溢出', (
        WidgetTester tester,
      ) async {
        await _pumpAt(tester, '/intake', size: Size(width, 900));
        expect(find.byKey(_name), findsOneWidget);
        expect(find.byKey(_theme), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('导航高亮与项目态一致', () {
    // 顶栏右边显示项目名 + 已自动保存时，导航高亮必须是「当前项目」；
    // 在工作台上则相反。颜色取自 palette：active = ink，其余 = muted。
    testWidgets('/workbench：高亮工作台', (WidgetTester tester) async {
      await _pumpAt(tester, '/workbench');
      expect(_navColor(tester, '工作台'), T0Palette.light.ink);
      expect(_navColor(tester, '当前项目'), T0Palette.light.muted);
    });

    for (final String route in _projectRoutes) {
      testWidgets('$route：高亮当前项目', (WidgetTester tester) async {
        await _pumpAt(tester, route);
        expect(_navColor(tester, '当前项目'), T0Palette.light.ink);
        expect(_navColor(tester, '工作台'), T0Palette.light.muted);
      });
    }
  });

  group('顶栏圆形按钮尺寸统一', () {
    testWidgets('1440 下主题与加号都是 36×36', (WidgetTester tester) async {
      await _pumpAt(tester, '/intake');
      expect(tester.getSize(find.byKey(_theme)), const Size(36, 36));
      expect(tester.getSize(find.byKey(_add)), const Size(36, 36));
    });

    testWidgets('500 下主题与菜单按钮也都是 36×36', (WidgetTester tester) async {
      await _pumpAt(tester, '/intake', size: const Size(500, 900));
      expect(tester.getSize(find.byKey(_theme)), const Size(36, 36));
      expect(tester.getSize(find.byKey(_add)), const Size(36, 36));
      expect(tester.takeException(), isNull);
    });
  });

  group('切主题', () {
    testWidgets('白天 ↔ 黑夜：这一段的字色 / 底色跟着变，位置不变', (WidgetTester tester) async {
      await _pumpAt(tester, '/intake');
      final Rect before = tester.getRect(find.byKey(_name));
      final Color nameColorLight = tester
          .widget<Text>(find.byKey(_name))
          .style!
          .color!;
      final Color surfaceLight = _topbarColor(tester);

      await tester.tap(find.byKey(_theme));
      await tester.pumpAndSettle();

      final Color nameColorDark = tester
          .widget<Text>(find.byKey(_name))
          .style!
          .color!;
      final Color surfaceDark = _topbarColor(tester);

      expect(nameColorDark, isNot(equals(nameColorLight)));
      expect(surfaceDark, isNot(equals(surfaceLight)));

      final Rect after = tester.getRect(find.byKey(_name));
      expect(after, before);
    });

    group('窄屏（372×812）右侧不能跟项目名粘在一起', () {
      testWidgets('项目页：主题 + 菜单贴住右边缘，与项目名之间留出空白', (WidgetTester tester) async {
        await _pumpAt(tester, '/intake', size: const Size(372, 812));
        final double w =
            tester.view.physicalSize.width / tester.view.devicePixelRatio;
        final Rect name = tester.getRect(find.byKey(_name));
        final Rect theme = tester.getRect(find.byKey(_theme));
        final Rect add = tester.getRect(find.byKey(_add));

        // 手机端水平内边距 14：菜单按钮右边缘应贴着 w - 14
        expect(add.right, moreOrLessEquals(w - 14, epsilon: 0.8));
        // 主题与菜单之间 8px 不变
        expect(add.left - theme.right, moreOrLessEquals(8, epsilon: 0.01));
        // 项目名与主题按钮之间必须有明显空白（不是连在一起）
        expect(theme.left - name.right, greaterThan(20));
      });
    });
  });
}

Color _topbarColor(WidgetTester tester) {
  final Container box = tester.widget<Container>(find.byKey(_topbar));
  return (box.decoration! as BoxDecoration).color!;
}

Color _navColor(WidgetTester tester, String label) {
  // 顶栏在最前面，同文案若页面正文也有，取第一个就是导航项
  final Text text = tester.widget<Text>(find.text(label).first);
  return text.style!.color!;
}
