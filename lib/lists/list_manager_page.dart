// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:uni_links/uni_links.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../common/appbars.dart';
import '../common/edit_list.dart';
import '../common/lists.dart';
import '../common/offline_indicator.dart';
import '../common/value_builders.dart';
import '../extensions.dart';
import '../registry.dart';
import '../settings/settings_page.dart';
import 'list_provider.dart';
import 'to_do_list_page.dart';
import 'to_do_list_tile.dart';

class ListManagerPage extends StatefulWidget {
  const ListManagerPage({Key? key}) : super(key: key);

  @override
  State<ListManagerPage> createState() => _ListManagerPageState();
}

class _ListManagerPageState extends State<ListManagerPage> {
  late final OfflineIndicator _offlineIndicator;
  final _bottomOfList = GlobalKey();

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _offlineIndicator = OfflineIndicator(context);
    });
    _monitorDeeplinks();

    _checkForUpdates();
  }

  @override
  void dispose() {
    _offlineIndicator.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarIconBrightness: context.theme.brightness.invert,
      ),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: BlurredAppBar(
          title: Stack(
            alignment: Alignment.center,
            children: [
              Image.asset(
                'assets/images/tudo_rainbow_bold.png',
                height: 40,
              ),
              Image.asset(
                'assets/images/tudo.png',
                height: 40,
                color: context.theme.textTheme.bodyLarge!.color,
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.qr_code_scanner),
              tooltip: t.scanQrCode,
              onPressed: () => _launchQrScanner(context),
            ),
            ValueStreamBuilder<bool>(
              stream: Registry.contactProvider.isNameSet,
              initialValue: true,
              builder: (_, isNameSet) => IconButton(
                icon: Badge(
                  smallSize: isNameSet ? 0 : null,
                  child: const Icon(Icons.tune_rounded),
                ),
                tooltip: t.settings,
                onPressed: () => context.push(() => const SettingsPage()),
              ),
            ),
          ],
        ),
        body: ValueStreamBuilder<List<ToDoList>>(
          stream: Registry.listProvider.lists,
          builder: (_, lists) => AnimatedReorderableListBuilder(
            lists,
            padding: context.padding.add(const EdgeInsets.only(bottom: 80)),
            onReorder: (from, to) => _swap(lists, from, to),
            builder: (context, i, item) => ToDoListTile(
              key: ValueKey(item.id),
              list: item,
              onTap: () => _openList(context, item),
              onLongPress: () => _editList(context, item),
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          clipBehavior: Clip.antiAlias,
          backgroundColor: Colors.transparent,
          onPressed: _createList,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Image.asset('assets/images/icon_bg.png'),
              Image.asset(
                'assets/images/t.png',
                height: 32,
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchQrScanner(BuildContext context) async {
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        content: AspectRatio(
          aspectRatio: 1.0,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: MobileScanner(
              placeholderBuilder: (p0, p1) => Container(
                color: Colors.black,
                alignment: Alignment.center,
                child: const Icon(Icons.qr_code_scanner_rounded),
              ),
              fit: BoxFit.cover,
              controller: MobileScannerController(
                  detectionSpeed: DetectionSpeed.noDuplicates),
              onDetect: (barcodes) =>
                  context.pop(barcodes.barcodes.first.rawValue),
            ),
          ),
        ),
      ),
    );

    if (code == null) return;
    'Read QR: $code'.log;
    final uri = Uri.parse(code);
    if (context.mounted) {
      await Registry.listProvider.import(uri.pathSegments.last);
    }
  }

  Future<void> _createList() async {
    final result = await editToDoList(context);
    if (result ?? false) {
      // Scroll to the new item
      await Future.delayed(const Duration(milliseconds: 100));
      _scrollToLastItem();
    }
  }

  void _openList(BuildContext context, ToDoList list) async {
    final action = await context.push(() => ToDoListPage(list: list));
    if (action != null && action == ListAction.delete) {
      Future.delayed(
        // Wait for pop animation to complete
        const Duration(milliseconds: 310),
        () => _deleteList(context, list),
      );
    }
  }

  void _editList(BuildContext context, ToDoList list) =>
      editToDoList(context, list);

  Future<void> _deleteList(BuildContext context, ToDoList list) async {
    final listManager = Registry.listProvider;
    await listManager.removeList(list.id);
    if (context.mounted) {
      context.showSnackBar(
        context.t.listDeleted(list.name),
        () => listManager.undoRemoveList(list.id),
      );
    }
  }

  void _scrollToLastItem() {
    final itemContext = _bottomOfList.currentContext;
    if (itemContext != null) {
      Scrollable.ensureVisible(
        itemContext,
        duration: const Duration(milliseconds: 300),
      );
    }
  }

  void _swap(List<ToDoList> lists, int from, int to) {
    final item = lists.removeAt(from);
    lists.insert(to, item);
    Registry.listProvider.setListOrder(lists);
  }

  void _monitorDeeplinks() {
    try {
      if (PlatformX.isMobile) {
        getInitialUri().then((uri) async {
          if (uri != null) {
            'Initial link: $uri'.log;
            await Registry.listProvider.import(uri.pathSegments.last);
          }
        });
        uriLinkStream.where((e) => e != null).listen((uri) async {
          if (uri != null) {
            'Stream link: $uri'.log;
            await Registry.listProvider.import(uri.pathSegments.last);
          }
        }).onError((e) => e.log);
      }
    } catch (e) {
      e.toString().log;
    }
  }

  Future<void> _checkForUpdates() async {
    if (await Registry.syncProvider.isUpdateRequired()) {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.t.updateRequired),
          content: Text(context.t.updateRequiredMessage),
          actions: [
            TextButton(
              child: Text(context.t.close),
              onPressed: () => context.pop(false),
            ),
            if (PlatformX.isMobile)
              TextButton(
                child: Text(context.t.update),
                onPressed: () => context.pop(true),
              ),
          ],
        ),
      );

      if (result == true) {
        if (Platform.isAndroid) {
          await InAppUpdate.performImmediateUpdate();
        } else {
          await launchUrlString(
              'https://apps.apple.com/us/app/tudo-lists/id1550819275');
        }
      }
    }
  }
}