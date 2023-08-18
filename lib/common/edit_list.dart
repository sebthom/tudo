import 'package:clipboard/clipboard.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../extensions.dart';
import '../lists/list_provider.dart';
import '../registry.dart';
import 'color_selector.dart';

Future<bool?> editToDoList(BuildContext context, [ToDoList? list]) {
  return showModalBottomSheet<bool>(
    enableDrag: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    context: context,
    builder: (context) => _EditListForm(
      list: list,
    ),
  );
}

class _EditListForm extends StatefulWidget {
  final ToDoList? list;

  const _EditListForm({Key? key, this.list}) : super(key: key);

  @override
  State<_EditListForm> createState() => _EditListFormState();
}

class _EditListFormState extends State<_EditListForm> {
  late final TextEditingController _textController;
  late final ColorController _colorController;

  ToDoList? get list => widget.list;

  bool get editMode => list != null;

  String get name => _textController.text.trim();

  Color get color => _colorController.color;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: list?.name);
    _colorController = ColorController(color: list?.color);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    return Theme(
      data: context.theme.copyWith(
        colorScheme: context.theme.colorScheme.copyWith(primary: color),
        primaryColor: color,
      ),
      child: Builder(
        builder: (context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (editMode) _MemberList(list!),
            const SizedBox(height: 20),
            Material(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28)),
              child: Padding(
                padding: const EdgeInsets.only(
                    left: 24, right: 24, top: 24, bottom: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _textController,
                      textCapitalization: TextCapitalization.sentences,
                      autofocus: !editMode,
                      decoration: InputDecoration(
                        hintText: t.name,
                      ),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _create(context),
                    ),
                    const SizedBox(height: 20),
                    ColorSelector(
                      controller: _colorController,
                      onColorSelected: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      // style: FilledButton.styleFrom(
                      //   padding: EdgeInsets.all(24)
                      // ),
                      onPressed: name.isEmpty ? null : () => _create(context),
                      child: Text(
                        (editMode ? t.update : t.create).toUpperCase(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      style: FilledButton.styleFrom(
                          foregroundColor: context.theme.colorScheme.error),
                      onPressed: () {},
                      child: Text(
                        (widget.list!.isShared ? t.leaveList : t.removeList)
                            .toUpperCase(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: keyboardInset + context.padding.bottom),
          ],
        ),
      ),
    );
  }

  void _create(BuildContext context) {
    if (name.isEmpty) return;

    if (editMode) {
      if (widget.list!.name != name) {
        Registry.listProvider.setName(widget.list!.id, name);
      }
      if (widget.list!.color != color) {
        Registry.listProvider.setColor(widget.list!.id, color);
      }
    } else {
      Registry.listProvider.createList(name, color);
    }

    context.pop(true);
  }
}

class _MemberList extends StatelessWidget {
  final ToDoList list;

  const _MemberList(this.list);

  @override
  Widget build(BuildContext context) {
    return Material(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const SizedBox(width: 20),
                  ...list.members.map(
                    (e) => Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 8),
                      child: InputChip(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24)),
                        backgroundColor: context.theme.primaryColor
                            .withOpacity(e.isCurrentUser ? 0.2 : 0.1),
                        label: Text(e.nameOr(context)),
                        onPressed: e.isCurrentUser ? () {} : null,
                        onDeleted: e.isCurrentUser
                            ? null
                            : () => _removeMember(context, e),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: () => _inviteMember(context),
            color: context.theme.primaryColor,
            icon: const Icon(Icons.person_add_alt_1_rounded),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }

  void _inviteMember(BuildContext context) {
    final t = context.t;
    final shareUrl = 'https://tudo.cachapa.net/list/${list.id}';

    showDialog(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        content: Container(
          clipBehavior: Clip.antiAlias,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          alignment: Alignment.center,
          width: 240,
          height: 240,
          child: QrImageView(
            data: shareUrl,
            version: QrVersions.auto,
            backgroundColor: ThemeData.light().canvasColor,
          ),
        ),
        actions: [
          TextButton.icon(
            style: ButtonStyle(
                foregroundColor: MaterialStateProperty.all(list.color)),
            icon: const Icon(Icons.copy),
            label: Text(t.copyLink.toUpperCase()),
            onPressed: () {
              FlutterClipboard.copy(shareUrl);
              Navigator.pop(context);
            },
          ),
          TextButton.icon(
            style: ButtonStyle(
                foregroundColor: MaterialStateProperty.all(list.color)),
            icon: Icon(Icons.adaptive.share),
            label: Text(context.t.share.toUpperCase()),
            onPressed: () {
              Share.share(t.listShareMessage(list.name, shareUrl));
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _removeMember(BuildContext context, Member member) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: Text(member.nameOr(context)),
        content: Text(context.t.removeConfirmation),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: Text(context.t.cancel.toUpperCase()),
          ),
          TextButton(
            onPressed: () => context.pop(true),
            child: Text(context.t.remove.toUpperCase()),
          ),
        ],
      ),
    );
    if (result == true) {
      await Registry.listProvider.removeUser(member.id, list.id);
    }
  }
}
