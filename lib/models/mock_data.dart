import 'package:flutter/foundation.dart';

/// 固定的示例数据 + 一个极小的全局状态容器（ValueNotifier，不引入状态管理库）。
///
/// 数据是「城市公共空间调研」，与实验四原型保持一致。

// ------------------------------------------------------------------ 状态
enum ModuleStatus { done, review, missing }

extension ModuleStatusX on ModuleStatus {
  /// 模块拆分 / 工作区里的说法
  String get label => switch (this) {
    ModuleStatus.done => '已确认',
    ModuleStatus.review => '待确认',
    ModuleStatus.missing => '待补充',
  };

  /// 交付检查里的说法：口径必须和模块状态一致，待确认不能写成「已完成」
  String get deliveryLabel => switch (this) {
    ModuleStatus.done => '已确认',
    ModuleStatus.review => '待确认',
    ModuleStatus.missing => '待补充',
  };

  ModuleStatus get next => switch (this) {
    ModuleStatus.done => ModuleStatus.review,
    ModuleStatus.review => ModuleStatus.missing,
    ModuleStatus.missing => ModuleStatus.done,
  };
}

// ------------------------------------------------------------------ 模块
class ProjectModule {
  const ProjectModule({
    required this.id,
    required this.title,
    required this.group,
    required this.desc,
    required this.pages,
    required this.source,
    required this.status,
  });

  final int id;
  final String title;
  final String group;
  final String desc;
  final int pages;
  final String source;
  final ModuleStatus status;

  String get number => id.toString().padLeft(2, '0');
}

const List<ProjectModule> moduleSeeds = <ProjectModule>[
  ProjectModule(
    id: 1,
    title: '场景与问题',
    group: '背景与问题',
    desc: '建立汇报背景与问题边界',
    pages: 1,
    source: '材料第 1 - 3 页',
    status: ModuleStatus.done,
  ),
  ProjectModule(
    id: 2,
    title: '冲突观察',
    group: '观察与冲突',
    desc: '三类高频使用冲突',
    pages: 2,
    source: '现场观察笔记',
    status: ModuleStatus.done,
  ),
  ProjectModule(
    id: 3,
    title: '原因分析',
    group: '原因分析',
    desc: '路径、边界与视线关系',
    pages: 2,
    source: '材料第 5 - 8 页',
    status: ModuleStatus.done,
  ),
  ProjectModule(
    id: 4,
    title: '设计建议',
    group: '建议与结论',
    desc: '把分析转成可执行建议',
    pages: 2,
    source: '材料第 9 页',
    status: ModuleStatus.review,
  ),
  ProjectModule(
    id: 5,
    title: '结论总结',
    group: '结论总结',
    desc: '补一条可以引用的结论',
    pages: 1,
    // 只有一套状态词：状态是「待补充」，来源写「尚缺材料」——
    // 不再把状态词再抄进来源，06 行内就不会出现「… · 待补充   待补充」两个同名标签
    source: '尚缺材料',
    status: ModuleStatus.missing,
  ),
];

// ------------------------------------------------------------------ 大纲
class OutlineItem {
  const OutlineItem({
    required this.title,
    required this.note,
    required this.pages,
    required this.points,
  });

  final String title;
  final String note;
  final String pages;
  final List<String> points;

  OutlineItem copyWith({
    String? title,
    String? note,
    String? pages,
    List<String>? points,
  }) => OutlineItem(
    title: title ?? this.title,
    note: note ?? this.note,
    pages: pages ?? this.pages,
    points: points ?? this.points,
  );
}

const List<OutlineItem> outlineSeeds = <OutlineItem>[
  OutlineItem(
    title: '封面：城市公共空间调研',
    note: '一句话讲清楚这次汇报研究的问题与范围',
    pages: '1 页',
    points: <String>['标题 + 副标题：有空间，为什么仍然不好用', '署名与调研时间'],
  ),
  OutlineItem(
    title: '背景：为什么“有空间”仍然不好用？',
    note: '从观察到的问题切入，不先堆背景数据',
    pages: '1 页',
    points: <String>['空间供给并不少', '真正缺的是连续可用的体验'],
  ),
  OutlineItem(
    // 初始 1 页：结构建议里「第 3 章拆成两页」还没被采纳，采纳后才变 2 页
    title: '观察：三类高频使用冲突',
    note: '通行、停留与活动之间的边界冲突',
    pages: '1 页',
    points: <String>['路径被占用', '边界模糊', '活动互相干扰'],
  ),
  OutlineItem(
    title: '分析：问题不只是设施数量',
    note: '路径连续性、边界清晰度与视线关系',
    pages: '2 页',
    points: <String>['路径不连续', '边界不可读', '视线没有落点'],
  ),
  OutlineItem(
    title: '建议：从“加法”转向可停留系统',
    note: '路径连续、边界可读、视线有落点',
    pages: '2 页',
    points: <String>['把“停留”作为设计单位', '三条建议按优先级排列'],
  ),
  OutlineItem(
    title: '结论：一套可复用的判断框架',
    note: '需要补充一条可引用的实地结论',
    pages: '1 页',
    points: <String>['结论句待补充', '不自动编造，标记为待补充'],
  ),
];

// ------------------------------------------------------------------ 幻灯片
class SlideColumn {
  const SlideColumn(this.title, this.text);
  final String title;
  final String text;
}

class SlideRow {
  const SlideRow(this.title, this.text);
  final String title;
  final String text;
}

class SlideContent {
  const SlideContent({
    required this.number,
    required this.group,
    required this.title,
    required this.accent,
    required this.subtitle,
    required this.columns,
    required this.source,
    required this.compressedTitle,
    required this.compressedAccent,
    required this.rows,
    required this.versionNote,
  });

  final String number;
  final String group;

  /// 修改前（版本 1）的标题，允许用 \n 断行
  final String title;
  final String accent;
  final String subtitle;
  final List<SlideColumn> columns;
  final String source;

  /// 修改后（版本 2，压缩版）
  final String compressedTitle;
  final String compressedAccent;
  final List<SlideRow> rows;
  final String versionNote;
}

const Map<int, SlideContent> slideContents = <int, SlideContent>{
  1: SlideContent(
    number: '01',
    group: '背景与问题',
    title: '城市公共空间不少，\n但真正',
    accent: '好用的并不多。',
    subtitle: '调研先确认问题边界：空间虽然存在，但通行、停留和活动之间经常互相挤占。',
    columns: <SlideColumn>[
      SlideColumn('空间存在', '周边并不缺广场、步道和绿化，缺的是连续可用的体验。'),
      SlideColumn('使用受阻', '路径被占用、边界不清晰，让人经过却不愿意停下来。'),
      SlideColumn('研究切口', '不从“有没有空间”开始，而从“能不能使用”开始。'),
    ],
    source: '来源：调研原句与现场观察笔记',
    compressedTitle: '先把问题缩小：从“有没有空间”',
    compressedAccent: '转向“能不能使用”。',
    rows: <SlideRow>[
      SlideRow('空间存在', '公共空间供给并不少，基础条件已经具备。'),
      SlideRow('使用受阻', '通行、停留与活动之间的关系没有处理好。'),
      SlideRow('问题定义', '把研究重点放到空间可用性与使用体验上。'),
    ],
    versionNote: '修改说明：压缩背景描述，突出“可用性”问题',
  ),
  2: SlideContent(
    number: '02',
    group: '观察与冲突',
    title: '三类高频冲突，\n都发生在',
    accent: '通行与停留之间。',
    subtitle: '现场观察显示，冲突集中在路径被占用、边界模糊和活动互相干扰三种场景。',
    columns: <SlideColumn>[
      SlideColumn('路径被占用', '停车、摊位和临时设施切断了原本连续的步行路线。'),
      SlideColumn('边界模糊', '通行区和停留区混在一起，人们不知道哪里适合停下来。'),
      SlideColumn('活动干扰', '不同活动共享同一块场地，却没有形成清楚的先后关系。'),
    ],
    source: '来源：现场观察笔记 3 条',
    compressedTitle: '把观察收成三类冲突，',
    compressedAccent: '先不急着解释原因。',
    rows: <SlideRow>[
      SlideRow('通行受阻', '原本连续的路径被停车、台阶和摊位打断。'),
      SlideRow('停留无处', '人们想停下来，但找不到清楚、安全的停留位置。'),
      SlideRow('活动互扰', '散步、聊天和儿童活动共享空间，却缺少边界。'),
    ],
    versionNote: '修改说明：把观察整理为三类冲突，减少重复描述',
  ),
  3: SlideContent(
    number: '03',
    group: '原因分析',
    title: '问题不只在设施数量，\n更在',
    accent: '路径、边界与视线。',
    subtitle: '同一块空间既能被看见，又很难被使用，原因需要从空间关系里找。',
    columns: <SlideColumn>[
      SlideColumn('路径不连续', '步行路线被停车、台阶和临时设施反复切断。'),
      SlideColumn('边界不可读', '通行区、停留区和活动区没有被清楚地区分出来。'),
      SlideColumn('视线无落点', '人虽然经过这里，却找不到自然停下来的理由。'),
    ],
    source: '来源：材料第 5 - 8 页与现场观察笔记',
    compressedTitle: '原因不是“设施不够”，',
    compressedAccent: '而是三个关系没有接上。',
    rows: <SlideRow>[
      SlideRow('路径断点', '步行路线缺少连续性，经过的人不愿意停留。'),
      SlideRow('边界模糊', '不同使用方式混在一起，空间秩序变得不清楚。'),
      SlideRow('视线失焦', '停留区没有形成可观看、可依靠的空间关系。'),
    ],
    versionNote: '修改说明：把原因归并为路径、边界和视线三条',
  ),
  4: SlideContent(
    number: '04',
    group: '建议与结论',
    title: '把“停留”作为设计单位，\n而不只是增加',
    accent: '设施数量。',
    subtitle: '当路径能停、边界可读、视线有落点，公共空间才真正从“经过的地方”变成“愿意使用的地方”。',
    columns: <SlideColumn>[
      SlideColumn('路径连续', '减少被停车、台阶和临时摊位切断的步行路线。'),
      SlideColumn('边界可读', '让停留区、通行区和活动区可以被一眼区分。'),
      SlideColumn('视线有落点', '用座椅朝向和界面开口形成自然的停留理由。'),
    ],
    source: '来源：调研原句与现场观察笔记',
    compressedTitle: '让公共空间先支持“停留”，',
    // 手动断行：35px 衬线标题在 632px 里放不下 21 个字，
    // 自动断行会把「丰富」拆成「丰 / 富」两个孤字
    compressedAccent: '\n再谈“丰富”。',
    rows: <SlideRow>[
      SlideRow('路径连续', '优先清除步行路线上的断点。'),
      SlideRow('边界可读', '用地面、绿植和家具把通行与停留说清楚。'),
      SlideRow('视线有落点', '让座椅、界面和活动区互相形成观看关系。'),
    ],
    versionNote: '修改说明：压缩文案，强化三项建议的先后关系',
  ),
  5: SlideContent(
    number: '05',
    group: '结论总结',
    title: '结论需要一条可引用的',
    accent: '实地判断。',
    subtitle: '已有观察和建议，但还没有形成可以写进汇报的总结句。',
    columns: <SlideColumn>[
      SlideColumn('已有观察', '三类使用冲突已经整理完成。'),
      SlideColumn('已有分析', '路径、边界与视线的关系已经说明。'),
      SlideColumn('仍缺少', '一条有原始材料支持的结论。'),
    ],
    source: '来源：待补充材料',
    compressedTitle: '结论：让空间支持停留，',
    compressedAccent: '而不只是提供场地。',
    rows: <SlideRow>[
      SlideRow('已就绪', '三类冲突、三条分析和三项设计建议。'),
      SlideRow('补充结论', '公共空间的质量取决于人能不能自然地停下来。'),
      SlideRow('下一步', '补充一条实地结论或现场证据图后确认。'),
    ],
    versionNote: '修改说明：补充结论，不改动前四个模块',
  ),
};

// ------------------------------------------------------------------ 工作台
class RecentProject {
  const RecentProject({
    required this.name,
    required this.kind,
    required this.modules,
    required this.edited,
    required this.done,
    required this.total,
    required this.route,
    required this.dark,
  });

  final String name;
  final String kind;
  final int modules;
  final String edited;
  final int done;
  final int total;
  final String route;
  final bool dark;
}

const List<RecentProject> recentProjects = <RecentProject>[
  RecentProject(
    name: '城市公共空间调研',
    kind: '课程汇报',
    modules: 5,
    edited: '刚刚编辑',
    done: 3,
    total: 5,
    route: '/modules',
    dark: false,
  ),
  RecentProject(
    name: '校园咖啡消费观察',
    kind: '竞赛答辩',
    modules: 4,
    edited: '昨天 21:40',
    done: 2,
    total: 4,
    route: '/workspace',
    dark: true,
  ),
];

// ------------------------------------------------------------------ 状态容器
class T0Store {
  T0Store._();

  static final T0Store instance = T0Store._();

  final String projectName = '城市公共空间调研';
  final String projectKind = '课程汇报';
  final String projectFile = '城市公共空间调研.docx';

  /// 模块状态：索引 = moduleSeeds 下标
  final ValueNotifier<List<ModuleStatus>> statuses =
      ValueNotifier<List<ModuleStatus>>(<ModuleStatus>[
        for (final ProjectModule module in moduleSeeds) module.status,
      ]);

  /// 模块排序（拖拽排序后生效）
  final ValueNotifier<List<int>> order = ValueNotifier<List<int>>(<int>[
    1,
    2,
    3,
    4,
    5,
  ]);

  /// 当前工作区模块 id
  final ValueNotifier<int> activeModuleId = ValueNotifier<int>(4);

  /// 画布缩放。
  ///
  /// 默认 0.71 不是审美值，是版面算出来的：画布可视高 900−72−48−69 = 711，
  /// 扣掉上下内边距剩 657；两页 405 高的 16:9 叠放 + 20px 间隙在 0.82 下要
  /// 405×0.82×2+20 = 684 > 657，末行必然顶到页脚分隔线。0.71 时
  /// 405×0.71×2+20 = 595，上下各留 28 后仍余 ≈34px。
  final ValueNotifier<double> zoom = ValueNotifier<double>(0.71);

  /// 已被 AI 改过的模块（展示压缩版 / 版本 2）
  final ValueNotifier<Set<int>> editedModules = ValueNotifier<Set<int>>(<int>{
    4,
  });

  /// 大纲章节
  final ValueNotifier<List<OutlineItem>> outline =
      ValueNotifier<List<OutlineItem>>(List<OutlineItem>.of(outlineSeeds));

  /// 结构建议卡是否还显示
  final ValueNotifier<bool> structureTipVisible = ValueNotifier<bool>(true);

  int get total => moduleSeeds.length;

  int get confirmedCount =>
      statuses.value.where((ModuleStatus s) => s == ModuleStatus.done).length;

  /// 交付口径：有内容（已确认或待确认）就算已完成
  int get settledCount => statuses.value
      .where((ModuleStatus s) => s != ModuleStatus.missing)
      .length;

  double get progress => confirmedCount / total;

  /// 待确认的模块数：交付口径里「已就绪」和「已确认」的差额
  int get reviewCount =>
      statuses.value.where((ModuleStatus s) => s == ModuleStatus.review).length;

  double get deliveryProgress => settledCount / total;

  int get pendingCount => total - settledCount;

  int get pageCount =>
      moduleSeeds.fold<int>(0, (int sum, ProjectModule m) => sum + m.pages);

  ProjectModule moduleOf(int id) =>
      moduleSeeds.firstWhere((ProjectModule m) => m.id == id);

  int indexOf(int id) =>
      moduleSeeds.indexWhere((ProjectModule m) => m.id == id);

  ModuleStatus statusOf(int id) => statuses.value[indexOf(id)];

  void setStatus(int id, ModuleStatus status) {
    final List<ModuleStatus> next = List<ModuleStatus>.of(statuses.value);
    next[indexOf(id)] = status;
    statuses.value = next;
  }

  void cycleStatus(int id) => setStatus(id, statusOf(id).next);

  void setActiveModule(int id) => activeModuleId.value = id;

  void setZoom(double value) => zoom.value = value.clamp(0.6, 1.2);

  bool hasEdits(int id) => editedModules.value.contains(id);

  void applyEdit(int id) {
    editedModules.value = <int>{...editedModules.value, id};
  }

  void revertEdit(int id) {
    editedModules.value = <int>{...editedModules.value}..remove(id);
  }

  void move(int oldIndex, int newIndex) {
    final List<int> next = List<int>.of(order.value);
    final int moved = next.removeAt(oldIndex);
    next.insert(newIndex.clamp(0, next.length), moved);
    order.value = next;
  }

  /// 采纳结构建议：要点写进大纲；[pages] 不为空时同时改页数
  /// （「第 3 章拆成两页」这类建议采纳后页数才从 1 页变 2 页）。
  void adoptSuggestion(int chapterIndex, String point, {String? pages}) {
    final List<OutlineItem> next = List<OutlineItem>.of(outline.value);
    if (chapterIndex < 0 || chapterIndex >= next.length) return;
    next[chapterIndex] = next[chapterIndex].copyWith(
      points: <String>[...next[chapterIndex].points, point],
      pages: pages,
    );
    outline.value = next;
  }

  /// 撤销采纳：把要点和页数一起撤回，别留下「已撤销但大纲还是 2 页」
  void revertSuggestion(int chapterIndex, String point, {String? pages}) {
    final List<OutlineItem> next = List<OutlineItem>.of(outline.value);
    if (chapterIndex < 0 || chapterIndex >= next.length) return;
    next[chapterIndex] = next[chapterIndex].copyWith(
      points: <String>[
        for (final String p in next[chapterIndex].points)
          if (p != point) p,
      ],
      pages: pages,
    );
    outline.value = next;
  }

  void addChapter() {
    outline.value = <OutlineItem>[
      ...outline.value,
      const OutlineItem(
        title: '新增章节：待命名',
        note: '双击标题可修改，或直接拆进已有模块',
        pages: '1 页',
        points: <String>['要点待补充'],
      ),
    ];
  }

  void removeChapter(int index) {
    final List<OutlineItem> next = List<OutlineItem>.of(outline.value)
      ..removeAt(index);
    outline.value = next;
  }

  /// 测试和演示重置用
  void reset() {
    statuses.value = <ModuleStatus>[
      for (final ProjectModule m in moduleSeeds) m.status,
    ];
    order.value = <int>[1, 2, 3, 4, 5];
    activeModuleId.value = 4;
    zoom.value = 0.71; // 与字段初值同一个数（05 纸张卡末行不能被页脚压住）
    editedModules.value = <int>{4};
    outline.value = List<OutlineItem>.of(outlineSeeds);
    structureTipVisible.value = true;
  }
}
