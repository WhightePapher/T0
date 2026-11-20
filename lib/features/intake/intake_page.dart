import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../../theme/tokens.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/ghost_button.dart';
import '../../widgets/paper_background.dart';
import '../../widgets/primary_button.dart';

/// 2 · 材料输入：左侧粘贴 / 拖入，右侧解析结果预览，底部主按钮。
class IntakePage extends StatefulWidget {
  const IntakePage({super.key});

  static const String routeName = '/intake';

  @override
  State<IntakePage> createState() => _IntakePageState();
}

class _IntakePageState extends State<IntakePage> {
  int _mode = 0; // 0 上传文档 / 1 粘贴文本 / 2 直接输入主题
  bool _uploaded = true;
  bool _failed = false;

  late final TextEditingController _paste = TextEditingController(
    text:
        '本次调研围绕校园公共空间的使用冲突展开。我们在三个时段观察了主教学楼前的广场，'
        '记录到三类高频问题：路径被停车和临时摊位切断、通行区与停留区边界模糊、'
        '不同活动共享同一场地却没有先后关系。\n\n'
        '调研同时整理了六位使用者的访谈记录，其中四位提到"想坐一会儿但不知道坐哪里"。',
  );
  late final TextEditingController _topic = TextEditingController(
    text: '校园公共空间调研：为什么有空间，却仍然不好用？',
  );
  late final TextEditingController _must = TextEditingController(
    text: '保留调研的方法、三类冲突、原因判断和最终建议；不要写成泛泛的设计原则。',
  );

  @override
  void dispose() {
    _paste.dispose();
    _topic.dispose();
    _must.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final T0Metrics m = context.metrics;
    return AppShell(
      // 材料输入已经在项目里（五步第 1 步），导航高亮归到「当前项目」，
      // 不再是「工作台」—— 顶栏右边既然显示项目名 + 已自动保存，高亮就得一致。
      activeNav: '/workspace',
      step: FlowStep.input,
      child: PageBody(
        children: <Widget>[
          const FlowHead(
            eyebrow: 'Step 01 · Input',
            title: '把材料交给我，先梳理结构。',
            note: '材料不足处标「待补充」，不会替你编。',
          ),
          const SizedBox(height: 26),
          if (m.isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(child: _inputCard(context)),
                const SizedBox(width: 24),
                SizedBox(width: 300, child: _aside(context)),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _inputCard(context),
                const SizedBox(height: 20),
                _aside(context),
              ],
            ),
        ],
      ),
    );
  }

  Widget _inputCard(BuildContext context) {
    final T0Metrics m = context.metrics;
    return PaperCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            // 三段式轨道与下方内容区同一条左边线（原来 10px，比内容区宽出 14px）
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
            child: _ModeTabs(
              value: _mode,
              onChanged: (int index) => setState(() => _mode = index),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
            child: switch (_mode) {
              1 => _pastePanel(context),
              2 => _topicPanel(context),
              _ => _uploadPanel(context),
            },
          ),
          const SizedBox(height: 20),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 20, 16),
            child: m.isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text('生成大纲后仍可修改章节、顺序和重点。', style: context.tMeta),
                      const SizedBox(height: 12),
                      PrimaryButton(
                        label: '生成大纲',
                        arrow: true,
                        expand: true,
                        onPressed: () => go(context, '/outline'),
                      ),
                    ],
                  )
                : Row(
                    children: <Widget>[
                      Expanded(
                        child: Text('生成大纲后仍可修改章节、顺序和重点。', style: context.tMeta),
                      ),
                      PrimaryButton(
                        label: '生成大纲',
                        arrow: true,
                        onPressed: () => go(context, '/outline'),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ 上传文档
  Widget _uploadPanel(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (!_uploaded && !_failed)
          DashedBox(
            radius: 16,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 42),
            child: Column(
              children: <Widget>[
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: context.pal.accentSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_upward,
                    size: 20,
                    color: context.pal.accent,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '拖入课程论文、周报或会议纪要',
                  style: context.tH3,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '支持 DOCX、PDF、TXT、Markdown；单文件不超过 50 MB。',
                  style: context.tMeta,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: <Widget>[
                    SecondaryButton(
                      label: '使用示例材料',
                      icon: Icons.description_outlined,
                      dense: true,
                      onPressed: () => setState(() {
                        _uploaded = true;
                        _failed = false;
                      }),
                    ),
                    SecondaryButton(
                      label: '模拟解析失败',
                      dense: true,
                      // 和左右两个次要按钮同形（胶囊 + 1px 描边），只用 danger 字色
                      // 标明它是危险 / 演示动作，不再是一条无边框文本
                      tone: context.pal.danger,
                      onPressed: () => setState(() {
                        _uploaded = false;
                        _failed = true;
                      }),
                    ),
                  ],
                ),
              ],
            ),
          )
        else
          DashedBox(
            radius: 16,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
            child: Column(
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: context.pal.accentSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_upward,
                    size: 18,
                    color: context.pal.accent,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '拖入课程论文、周报或会议纪要',
                  style: context.tH3,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  '支持 DOCX、PDF、TXT、Markdown；单文件不超过 50 MB。',
                  style: context.tMeta,
                ),
              ],
            ),
          ),
        if (_uploaded) ...<Widget>[
          const SizedBox(height: 16),
          _fileCard(context),
        ],
        if (_failed) ...<Widget>[
          const SizedBox(height: 16),
          _errorCard(context),
        ],
        if (_uploaded || _failed) ...<Widget>[
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: <Widget>[
              SecondaryButton(
                label: '使用示例材料',
                icon: Icons.description_outlined,
                dense: true,
                onPressed: () => setState(() {
                  _uploaded = true;
                  _failed = false;
                }),
              ),
              SecondaryButton(
                label: '模拟解析失败',
                dense: true,
                tone: context.pal.danger,
                onPressed: () => setState(() {
                  _uploaded = false;
                  _failed = true;
                }),
              ),
              SecondaryButton(
                label: '重新开始',
                dense: true,
                onPressed: () => setState(() {
                  _uploaded = false;
                  _failed = false;
                }),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _fileCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: context.pal.accentSoft,
        borderRadius: BorderRadius.circular(T0.fieldRadius),
        border: Border.all(color: context.pal.accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.pal.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'DOCX',
              style: context.tMono.copyWith(
                fontSize: 8,
                color: context.pal.accent,
                letterSpacing: 0.4,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '城市公共空间调研.docx',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.tBody.copyWith(
                    fontSize: 13 * context.s,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '14 页 · 3.2 MB · 已提取 6 个主要观点',
                  // 文件卡底是 accentSoft（#DFF0E9）：ink2 只有 4.16，走 mutedOnTint（4.97）
                  style: context.tMeta.copyWith(
                    fontSize: 11 * context.s,
                    color: context.pal.mutedOnTint,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // 28×28 命中区，视觉右边缘落在 14px 内边距上，与左侧图标起点对称
          _CloseButton(
            tooltip: '移除文件',
            onTap: () => setState(() {
              _uploaded = false;
              _failed = false;
            }),
          ),
        ],
      ),
    );
  }

  Widget _errorCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.pal.dangerSoft,
        borderRadius: BorderRadius.circular(T0.fieldRadius),
        border: Border.all(color: context.pal.danger.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '未能读取这份材料',
            style: context.tBody.copyWith(
              fontSize: 13 * context.s,
              fontWeight: FontWeight.w600,
              color: context.pal.danger,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '文件可能是扫描图片或已损坏。你的输入没有被清空，可以改为粘贴正文。',
            style: context.tMeta.copyWith(
              fontSize: 11.5 * context.s,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: GhostButton(
              label: '改为粘贴文本 →',
              color: context.pal.danger,
              onPressed: () => setState(() {
                _mode = 1;
                _failed = false;
              }),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ 粘贴 / 主题
  Widget _pastePanel(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('粘贴正文', style: context.tLabel),
        const SizedBox(height: 8),
        TextField(
          controller: _paste,
          minLines: 9,
          maxLines: 16,
          style: context.tBody.copyWith(fontSize: 13 * context.s, height: 1.8),
          decoration: AppTheme.field(
            context,
            hint: '例如：本次调研围绕校园公共空间的使用冲突展开……',
            padding: const EdgeInsets.all(16),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '已识别 ${_paste.text.characters.length} 个字 · 6 个章节候选 · 1 项素材缺失',
          style: context.tMeta.copyWith(fontSize: 11.5 * context.s),
        ),
      ],
    );
  }

  Widget _topicPanel(BuildContext context) {
    final T0Metrics m = context.metrics;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('这次要做什么', style: context.tLabel),
        const SizedBox(height: 8),
        TextField(
          controller: _topic,
          style: context.tBody.copyWith(fontSize: 13 * context.s),
          decoration: AppTheme.field(context),
        ),
        const SizedBox(height: 16),
        if (m.isMobile)
          const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _StaticSelect(label: '听众', value: '课程老师与同学'),
              SizedBox(height: 14),
              _StaticSelect(label: '预计页数', value: '8 - 12 页'),
            ],
          )
        else
          const Row(
            children: <Widget>[
              Expanded(
                child: _StaticSelect(label: '听众', value: '课程老师与同学'),
              ),
              SizedBox(width: 16),
              Expanded(
                child: _StaticSelect(label: '预计页数', value: '8 - 12 页'),
              ),
            ],
          ),
        const SizedBox(height: 16),
        Text('必须覆盖的内容', style: context.tLabel),
        const SizedBox(height: 8),
        TextField(
          controller: _must,
          minLines: 3,
          maxLines: 6,
          style: context.tBody.copyWith(fontSize: 13 * context.s, height: 1.8),
          decoration: AppTheme.field(
            context,
            padding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------ 右侧
  Widget _aside(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        PaperCard(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '本次制作设置',
                style: context.tH3.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const _SettingRow(label: '目标场景', value: '课程汇报'),
              const _SettingRow(label: '输出比例', value: '16 : 9'),
              const _SettingRow(label: '内容策略', value: '只整理原文观点'),
              const _SettingRow(label: '修改范围', value: '默认只改当前模块', last: true),
            ],
          ),
        ),
      ],
    );
  }
}

class _ModeTabs extends StatelessWidget {
  const _ModeTabs({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  static const List<String> _labels = <String>['上传文档', '粘贴文本', '直接输入主题'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.pal.canvas,
        borderRadius: BorderRadius.circular(T0.fieldRadius),
      ),
      child: Row(
        children: <Widget>[
          for (int i = 0; i < _labels.length; i++)
            Expanded(
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(i),
                  child: AnimatedContainer(
                    duration: context.anim(const Duration(milliseconds: 160)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: i == value ? context.pal.surface : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: i == value ? context.pal.line : Colors.transparent,
                      ),
                    ),
                    child: Text(
                      _labels[i],
                      textAlign: TextAlign.center,
                      style: context.tBody.copyWith(
                        fontSize: 12.5 * context.s,
                        fontWeight: i == value
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: i == value ? context.pal.ink : context.pal.mutedOnTint,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StaticSelect extends StatelessWidget {
  const _StaticSelect({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: context.tLabel),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: context.pal.surface,
            borderRadius: BorderRadius.circular(T0.fieldRadius),
            border: Border.all(color: context.pal.line),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  value,
                  style: context.tBody.copyWith(fontSize: 13 * context.s),
                ),
              ),
              Icon(Icons.expand_more, size: 16, color: context.pal.ink2),
            ],
          ),
        ),
      ],
    );
  }
}

/// 28×28 的紧凑关闭按钮：命中区小、视觉重心与左侧图标对齐。
class _CloseButton extends StatefulWidget {
  const _CloseButton({required this.onTap, this.tooltip});

  final VoidCallback onTap;
  final String? tooltip;

  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final Widget button = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _hover ? context.pal.surface : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.close, size: 16, color: _hover ? context.pal.ink : context.pal.ink2),
        ),
      ),
    );
    if (widget.tooltip == null) return button;
    return Tooltip(message: widget.tooltip!, child: button);
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.label,
    required this.value,
    this.last = false,
  });

  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: context.pal.line)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: context.tMeta.copyWith(fontSize: 11.5 * context.s),
            ),
          ),
          Text(
            value,
            style: context.tMeta.copyWith(
              fontSize: 11.5 * context.s,
              color: context.pal.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
