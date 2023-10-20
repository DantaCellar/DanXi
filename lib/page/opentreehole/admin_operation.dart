import 'package:dan_xi/generated/l10n.dart';
import 'package:dan_xi/model/opentreehole/floor.dart';
import 'package:dan_xi/model/opentreehole/history.dart';
import 'package:dan_xi/model/opentreehole/punishment.dart';
import 'package:dan_xi/provider/settings_provider.dart';
import 'package:dan_xi/repository/opentreehole/opentreehole_repository.dart';
import 'package:dan_xi/util/master_detail_view.dart';
import 'package:dan_xi/util/noticing.dart';
import 'package:dan_xi/util/opentreehole/human_duration.dart';
import 'package:dan_xi/util/platform_universal.dart';
import 'package:dan_xi/widget/libraries/future_widget.dart';
import 'package:dan_xi/widget/libraries/material_x.dart';
import 'package:dan_xi/widget/libraries/platform_app_bar_ex.dart';
import 'package:dan_xi/widget/libraries/platform_context_menu.dart';
import 'package:dan_xi/widget/opentreehole/treehole_widgets.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

Future<bool> showAdminOperation(BuildContext context, OTFloor floor) async {
  final dynamic result =
      await smartNavigatorPush(context, '/bbs/admin', arguments: {
    "floor": floor,
  });

  if (result == null) return false;

  try {} catch (e, st) {
    Noticing.showErrorDialog(context, e,
        trace: st, title: S.of(context).reply_failed);
    return false;
  }
  return true;
}

class AdminOperationPage extends StatefulWidget {
  final Map<String, dynamic>? arguments;

  const AdminOperationPage({Key? key, this.arguments}) : super(key: key);

  @override
  AdminOperationPageState createState() => AdminOperationPageState();
}

class AdminOperationPageState extends State<AdminOperationPage> {
  late OTFloor _floor;
  // Don't show penalty menu if multi-floor
  late String _title;
  FileImage? _backgroundImage;
  List<String>? _punishmentHistory;
  List<OTHistory>? _modifyHistory;

  late TextEditingController _reasonController;
  final ValueNotifier<bool> _punishUser = ValueNotifier(false);
  final ValueNotifier<bool> _deletePost = ValueNotifier(true);
  final ValueNotifier<int> _punishmentDays = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _reasonController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    _title =
        widget.arguments!['title'] ?? S.of(context).forum_post_enter_content;
    _floor = widget.arguments!['floor']!;

    super.didChangeDependencies();
  }

  Future<List<String>> getPunishmentHistory() async {
    _punishmentHistory ??= await OpenTreeHoleRepository.getInstance()
        .adminGetPunishmentHistory(_floor.floor_id!);

    return _punishmentHistory!;
  }

  Future<List<OTHistory>> getModifyHistory() async {
    _modifyHistory ??=
        await OpenTreeHoleRepository.getInstance().getHistory(_floor.floor_id);

    return _modifyHistory!;
  }

  @override
  Widget build(BuildContext context) {
    _backgroundImage = SettingsProvider.getInstance().backgroundImage;

    return PlatformScaffold(
      iosContentBottomPadding: false,
      iosContentPadding: false,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: PlatformAppBarX(
        title: Text(_title),
        trailingActions: [
          PlatformIconButton(
            padding: EdgeInsets.zero,
            icon: PlatformX.isMaterial(context)
                ? const Icon(Icons.send)
                : const Icon(CupertinoIcons.paperplane),
            onPressed: () async => _sendDocument(),
          ),
        ],
      ),
      body: SafeArea(
          bottom: false,
          child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: SingleChildScrollView(
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    OTFloorWidget(
                        floor: _floor,
                        showBottomBar: false,
                        hasBackgroundImage: _backgroundImage != null),
                    const Divider(),
                    FutureFoledListWidget(
                        future: getModifyHistory(),
                        itemBuilder: (e) => Card(
                            child: ListTile(
                                subtitle: Text(HumanDuration.tryFormat(context,
                                    DateTime.tryParse(e.time_updated ?? ""))),
                                title: Text(e.content!))),
                        text: "历史修改"),
                    const Divider(),
                    PlatformTextField(
                      hintText: "输入删帖/折叠理由",
                      material: (_, __) => MaterialTextFieldData(
                          decoration: const InputDecoration(
                              border: OutlineInputBorder(gapPadding: 2.0))),
                      keyboardType: TextInputType.multiline,
                      maxLines: 1,
                      expands: false,
                      autofocus: true,
                      textAlignVertical: TextAlignVertical.top,
                      onChanged: (text) {},
                      controller: _reasonController,
                    ),
                    const Divider(),
                    Card(
                        child: Column(children: [
                      ValueListenableBuilder(
                          valueListenable: _deletePost,
                          builder: (context, value, child) => ListTile(
                                title: const Text("帖子操作"),
                                leading: const Icon(CupertinoIcons.hand_draw),
                                subtitle: Text(_deletePost.value ? "删除" : "折叠"),
                                onTap: () => showPlatformModalSheet(
                                    context: context,
                                    builder: (BuildContext context) =>
                                        PlatformContextMenu(
                                            actions: [
                                              PlatformContextMenuItem(
                                                menuContext: context,
                                                child: const Text("删除"),
                                                onPressed: () =>
                                                    _deletePost.value = true,
                                              ),
                                              PlatformContextMenuItem(
                                                menuContext: context,
                                                child: const Text("折叠"),
                                                onPressed: () =>
                                                    _deletePost.value = false,
                                              )
                                            ],
                                            cancelButton:
                                                CupertinoActionSheetAction(
                                                    child: Text(
                                                        S.of(context).cancel),
                                                    onPressed: () =>
                                                        Navigator.of(context)
                                                            .pop()))),
                              )),
                      ValueListenableBuilder(
                          valueListenable: _punishUser,
                          builder: (context, value, child) =>
                              SwitchListTile.adaptive(
                                title: const Text("封禁用户"),
                                secondary: const Icon(CupertinoIcons.nosign),
                                value: _punishUser.value,
                                onChanged: (bool value) {
                                  _punishUser.value = value;
                                },
                              )),
                      ValueListenableBuilder(
                          valueListenable: _punishmentDays,
                          builder: (context, value, child) => SpinBoxTile(
                                secondary: const Icon(CupertinoIcons.calendar),
                                title: Text("封禁时长: ${_punishmentDays.value}"),
                                onChanged: (int delta) {
                                  _punishmentDays.value =
                                      (_punishmentDays.value + delta)
                                          // PS: I admit this is ugly
                                          .clamp(0, 0x7fffffff);
                                },
                              )),
                    ])),
                    const Divider(),
                    FutureFoledListWidget(
                        future: getPunishmentHistory(),
                        itemBuilder: (e) =>
                            Card(child: ListTile(title: Text(e))),
                        text: "违规记录")
                  ])))),
    );
  }

  Future<void> _sendDocument() async {
    Navigator.pop<OTPunishment>(context, null);
  }
}

/// Same to SwitchListTile, the widget itself doesn't maintain any state
/// The value is passed and modified via [onChanged] and [value]
class SpinBoxTile extends StatelessWidget {
  final int? value;
  final Widget? secondary;
  final Widget? title;
  // Parameter is
  final void Function(int) onChanged;

  const SpinBoxTile(
      {super.key,
      this.secondary,
      this.title,
      this.value,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: secondary,
      title: title,
      contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      trailing: Card(
          color: Theme.of(context).secondaryHeaderColor,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                  icon: const Icon(Icons.remove),
                  iconSize: 15,
                  padding: EdgeInsets.zero,
                  onPressed: () => onChanged(-1)),
              const Divider(),
              IconButton(
                  icon: const Icon(Icons.add),
                  iconSize: 15,
                  padding: EdgeInsets.zero,
                  onPressed: () => onChanged(1)),
            ],
          )),
    );
  }
}

class FutureFoledListWidget<T> extends StatefulWidget {
  final bool? initiallyExpanded;
  final Future<List<T>> future;
  final Widget Function(T) itemBuilder;
  final String text;

  const FutureFoledListWidget(
      {super.key,
      this.initiallyExpanded,
      required this.future,
      required this.itemBuilder,
      required this.text});

  @override
  FutureFoldedListWidgetState<T> createState() =>
      FutureFoldedListWidgetState<T>();
}

class FutureFoldedListWidgetState<T> extends State<FutureFoledListWidget<T>> {
  late bool _expanded;
  late String _text;
  late Future<List<T>> _future;
  late Widget Function(T) _itemBuilder;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded ?? false;
    _future = widget.future;
    _text = widget.text;
    _itemBuilder = widget.itemBuilder;
  }

  @override
  void didUpdateWidget(covariant FutureFoledListWidget<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _expanded = widget.initiallyExpanded ?? _expanded;
    _future = widget.future;
    _text = widget.text;
    _itemBuilder = widget.itemBuilder;
  }

  @override
  Widget build(BuildContext context) {
    return FutureWidget<List<T>>(
      future: _future,
      loadingBuilder: Center(
        child: PlatformCircularProgressIndicator(),
      ),
      successBuilder: (BuildContext context, AsyncSnapshot<List<T>> snapshot) {
        return ExpansionTileX(
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            expandedAlignment: Alignment.topLeft,
            childrenPadding: const EdgeInsets.symmetric(vertical: 4),
            tilePadding: EdgeInsets.zero,
            initiallyExpanded: _expanded,
            onExpansionChanged: (value) => _expanded = value,
            title: Row(
              children: [
                const Icon(CupertinoIcons.person_badge_minus),
                const SizedBox(width: 8),
                Text("$_text: ${snapshot.data!.length} 条")
              ],
            ),
            children: [...snapshot.data!.map(_itemBuilder)]);
      },
      errorBuilder: () => Icon(
        PlatformIcons(context).error,
        color: Theme.of(context).colorScheme.error,
      ),
    );
  }
}
