/*
 *     Copyright (C) 2025  w568w
 *
 *     This program is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     This program is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 *
 *     You should have received a copy of the GNU General Public License
 *     along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'package:dan_xi/common/constant.dart';
import 'package:dan_xi/generated/l10n.dart';
import 'package:dan_xi/page/platform_subpage.dart';
import 'package:dan_xi/page/subpage_forum.dart';
import 'package:dan_xi/provider/forum_provider.dart';
import 'package:dan_xi/provider/state_provider.dart';
import 'package:dan_xi/repository/forum/forum_repository.dart';
import 'package:dan_xi/util/browser_util.dart';
import 'package:dan_xi/util/master_detail_view.dart';
import 'package:dan_xi/util/noticing.dart';
import 'package:dan_xi/util/platform_universal.dart';
import 'package:dan_xi/util/public_extension_methods.dart';
import 'package:dan_xi/util/stream_listener.dart';
import 'package:dan_xi/widget/libraries/error_page_widget.dart';
import 'package:dan_xi/widget/libraries/future_widget.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:nil/nil.dart';
import 'package:provider/provider.dart';

class BankSubPage extends PlatformSubpage<BankSubPage> {
  @override
  BankSubPageState createState() => BankSubPageState();

  const BankSubPage({super.key});

  @override
  Create<Widget> get title => (cxt) => Text("创意银行");

  @override
  Create<List<AppBarButtonItem>> get trailing {
    return (cxt) => [
          AppBarButtonItem(S.of(cxt).refresh, Icon(PlatformIcons(cxt).refresh),
              () {
            RefreshPageEvent().fire();
          }),
          AppBarButtonItem(
              S.of(cxt).reset,
              Icon(PlatformX.isMaterial(cxt)
                  ? Icons.medical_services_outlined
                  : CupertinoIcons.rays), () {
            ResetWebViewEvent().fire();
          }),
        ];
  }
}

class RefreshPageEvent {}

class ResetWebViewEvent {}

const ALLOW_HOSTS = [
  "fduhole.com",
  "danta.tech",
  "danta.fudan.edu.cn",
];

class BankSubPageState extends PlatformSubpageState<BankSubPage> {
  InAppWebViewController? webViewController;
  static final StateStreamListener<RefreshPageEvent> _refreshSubscription =
      StateStreamListener();
  static final StateStreamListener<ResetWebViewEvent> _resetSubscription =
      StateStreamListener();

  URLRequest get urlRequest => URLRequest(
          url: WebUri.uri(Uri.https('danta.fudan.edu.cn', '/jump', {
        'access': ForumProvider.getInstance().token?.access,
        'refresh': ForumProvider.getInstance().token?.refresh,
      })));

  @override
  void initState() {
    super.initState();
    _refreshSubscription.bindOnlyInvalid(
        Constant.eventBus
            .on<RefreshPageEvent>()
            .listen((event) => webViewController?.reload()),
        hashCode);
    _resetSubscription.bindOnlyInvalid(
        Constant.eventBus.on<ResetWebViewEvent>().listen((event) async {
          if (!mounted) return;
          bool? confirmed = await Noticing.showConfirmationDialog(
              context, "使用创意银行中遇到了白屏/无法加载的问题？点击好以修复。",
              title: S.of(context).fix);
          if (confirmed == true) {
            try {
              await InAppWebViewController.clearAllCache();
            } catch (_) {}

            if (PlatformX.isAndroid) {
              await WebStorageManager.instance().deleteAllData();
            }
            if (PlatformX.isIOS) {
              final manager = WebStorageManager.instance();
              var records = await manager.fetchDataRecords(
                  dataTypes: WebsiteDataType.values);
              await manager.removeDataFor(
                  dataTypes: WebsiteDataType.values,
                  dataRecords: records.filter((element) =>
                      element.displayName?.contains("fudan.edu.cn") ?? false));
            }

            try {
              await HttpAuthCredentialDatabase.instance()
                  .clearAllAuthCredentials();
            } catch (_) {}

            await CookieManager.instance().deleteAllCookies();

            await webViewController?.loadUrl(urlRequest: urlRequest);
          }
        }),
        hashCode);
  }

  @override
  void dispose() {
    super.dispose();
    _refreshSubscription.cancel();
    _resetSubscription.cancel();
  }

  @override
  Widget buildPage(BuildContext context) {
    return SafeArea(
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (bool didPop, result) async {
          if (webViewController != null &&
              await webViewController!.canGoBack()) {
            await webViewController!.goBack();
          } else {
            if (context.mounted) Navigator.pop(context);
          }
        },
        child: FutureWidget<void>(
          // We directly call the method during each build, because the method is idempotent and very cheap.
          future: ForumRepository.getInstance().initializeUser(),
          nullable: true,
          successBuilder: (_, __) {
            return InAppWebView(
              initialSettings: InAppWebViewSettings(
                  userAgent: Constant.version,
                  useShouldOverrideUrlLoading: true),
              initialUrlRequest: urlRequest,
              onWebViewCreated: (InAppWebViewController controller) {
                webViewController = controller;
              },
              shouldOverrideUrlLoading: (InAppWebViewController controller,
                  NavigationAction navigationAction) {
                final host = navigationAction.request.url?.host;
                if (host != null && !ALLOW_HOSTS.contains(host)) {
                  BrowserUtil.openUrl(
                      navigationAction.request.url!.toString(), context);
                  return NavigationActionPolicy.CANCEL;
                }
                return NavigationActionPolicy.ALLOW;
              },
            );
          },
          errorBuilder: (cxt, AsyncSnapshot<void> snapshot) {
            if (snapshot.error is NotLoginError) {
              return Center(
                child: Column(children: [
                  Text(S.of(context).require_login),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: PlatformElevatedButton(
                      onPressed: () async {
                        await smartNavigatorPush(context, "/bbs/login",
                            arguments: {
                              "info": StateProvider.personInfo.value!
                            });
                        onLogin();
                      },
                      child: Text(S.of(context).login),
                    ),
                  ),
                ]),
              );
            } else {
              return ErrorPageWidget.buildWidget(context, snapshot.error,
                  stackTrace: snapshot.stackTrace,
                  onTap: () => setState(() {}));
            }
          },
          loadingBuilder: nil,
        ),
      ),
    );
  }
}
