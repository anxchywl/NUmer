import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:numer_app/app/shell/android_tab_bar.dart';
import 'package:numer_app/app/shell/ios_tab_bar.dart';
import 'package:numer_app/app/shell/shell_hooks.dart';
import 'package:numer_app/app/shell/shell_tabs.dart';

// main navigation shell that hosts the bottom-tab pages
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _ShellState();
}

// keeps a tab page's state alive when the user switches between tabs
class _KeepAlivePage extends StatefulWidget {
  const _KeepAlivePage({required this.child});

  final Widget child;

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin<_KeepAlivePage> {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _ShellState extends State<AppShell> with ShellHooks {
  int _index = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabSelected(int index) {
    if (index == _index) return;
    final previousIndex = _index;
    setState(() => _index = index);
    final distance = (index - previousIndex).abs();
    if (_pageController.hasClients) {
      if (distance <= 1) {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      } else {
        // For non-adjacent tabs, switch directly to avoid scrolling through all pages.
        _pageController.jumpToPage(index);
      }
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) return;
      _pageController.jumpToPage(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tabs = buildShellTabs(context);
    final isIOS = !kIsWeb && Theme.of(context).platform == TargetPlatform.iOS;
    final tabPages = tabs
        .map((tab) => _KeepAlivePage(child: tab.builder(context)))
        .toList(growable: false);

    return Scaffold(
      extendBody: isIOS,
      body: Stack(
        children: [
          SafeArea(
            top: false,
            bottom: !isIOS,
            child: PageView(
              controller: _pageController,
              physics: const PageScrollPhysics(),
              onPageChanged: (index) {
                if (_index != index) {
                  setState(() => _index = index);
                }
              },
              children: tabPages,
            ),
          ),
          if (isIOS)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IosTabBar(
                currentIndex: _index,
                onTap: _onTabSelected,
                tabs: tabs,
              ),
            ),
        ],
      ),
      bottomNavigationBar: isIOS
          ? null
          : AndroidTabBar(
              currentIndex: _index,
              onTap: _onTabSelected,
              tabs: tabs,
            ),
    );
  }
}
