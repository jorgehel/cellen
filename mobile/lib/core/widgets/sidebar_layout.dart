import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api/api_client.dart';
import '../theme/app_theme.dart';

/// Responsive shell: sidebar on wide screens, bottom nav on narrow
class SidebarLayout extends StatelessWidget {
  final Widget child;
  final List<SidebarItem> items;
  final String currentPath;
  final String title;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  /// School branding — when provided, the sidebar header shows these
  /// instead of the generic Cellen logo.
  final String? schoolName;
  final String? schoolLogoUrl;

  /// Called when the user taps the school name/logo area in the sidebar.
  /// Typically navigates to the school profile screen (admin only).
  final VoidCallback? onSchoolTap;

  const SidebarLayout({
    super.key,
    required this.child,
    required this.items,
    required this.currentPath,
    required this.title,
    this.actions,
    this.floatingActionButton,
    this.schoolName,
    this.schoolLogoUrl,
    this.onSchoolTap,
  });

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    if (isWide) {
      return _WideLayout(
        child: child,
        items: items,
        currentPath: currentPath,
        title: title,
        actions: actions,
        floatingActionButton: floatingActionButton,
        schoolName: schoolName,
        schoolLogoUrl: schoolLogoUrl,
        onSchoolTap: onSchoolTap,
      );
    }
    return _NarrowLayout(
      child: child,
      items: items,
      currentPath: currentPath,
      title: title,
      actions: actions,
      floatingActionButton: floatingActionButton,
      schoolName: schoolName,
    );
  }
}

class SidebarItem {
  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final int? badge;

  const SidebarItem({
    required this.path,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.badge,
  });
}

// ---------------------------------------------------------------------------
// Shared: school logo avatar
// ---------------------------------------------------------------------------
class _SchoolAvatar extends StatelessWidget {
  final String? logoUrl;

  const _SchoolAvatar({this.logoUrl});

  @override
  Widget build(BuildContext context) {
    if (logoUrl != null && logoUrl!.isNotEmpty) {
      final full = logoUrl!.startsWith('http') ? logoUrl! : '$kMediaBase$logoUrl';
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: full,
          width: 32,
          height: 32,
          fit: BoxFit.cover,
          placeholder: (_, __) => _defaultIcon(),
          errorWidget: (_, __, ___) => _defaultIcon(),
        ),
      );
    }
    return _defaultIcon();
  }

  Widget _defaultIcon() => Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppTheme.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.school_rounded, color: Colors.white, size: 18),
      );
}

// ---------------------------------------------------------------------------
// Wide layout
// ---------------------------------------------------------------------------
class _WideLayout extends StatelessWidget {
  final Widget child;
  final List<SidebarItem> items;
  final String currentPath;
  final String title;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final String? schoolName;
  final String? schoolLogoUrl;
  final VoidCallback? onSchoolTap;

  const _WideLayout({
    required this.child,
    required this.items,
    required this.currentPath,
    required this.title,
    this.actions,
    this.floatingActionButton,
    this.schoolName,
    this.schoolLogoUrl,
    this.onSchoolTap,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 220,
            color: Colors.white,
            child: Column(
              children: [
                // School branding header
                GestureDetector(
                  onTap: onSchoolTap,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    height: 64,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: AppTheme.border)),
                    ),
                    child: Row(
                      children: [
                        _SchoolAvatar(logoUrl: schoolLogoUrl),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            schoolName ?? 'Cellen',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        if (onSchoolTap != null)
                          const Icon(Icons.edit_outlined,
                              size: 14, color: AppTheme.textSecondary),
                      ],
                    ),
                  ),
                ),

                // Nav items
                Expanded(
                  child: ListView(
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                    children: items.map((item) {
                      final selected = currentPath.startsWith(item.path);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 2),
                        child: ListTile(
                          onTap: () => context.go(item.path),
                          selected: selected,
                          selectedTileColor: AppTheme.primaryLight,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 0),
                          minVerticalPadding: 0,
                          visualDensity: VisualDensity.compact,
                          leading: Icon(
                            selected ? item.selectedIcon : item.icon,
                            color: selected
                                ? AppTheme.primary
                                : AppTheme.textSecondary,
                            size: 20,
                          ),
                          title: Text(
                            item.label,
                            style: TextStyle(
                              color: selected
                                  ? AppTheme.primary
                                  : AppTheme.textSecondary,
                              fontSize: 14,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                          ),
                          trailing: item.badge != null && item.badge! > 0
                              ? Container(
                                  width: 20,
                                  height: 20,
                                  decoration: const BoxDecoration(
                                    color: AppTheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      item.badge! > 9 ? '9+' : '${item.badge}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ),

                // Powered by Cellen footer
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: AppTheme.border)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Powered by ',
                        style: TextStyle(
                            color: Colors.grey.shade400, fontSize: 10),
                      ),
                      Text(
                        'Cellen',
                        style: TextStyle(
                          color: AppTheme.primary.withOpacity(0.6),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Vertical divider
          const VerticalDivider(width: 1, thickness: 1, color: AppTheme.border),

          // Main content
          Expanded(
            child: Column(
              children: [
                // Top bar
                Container(
                  height: 60,
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const Spacer(),
                      if (actions != null) ...actions!,
                    ],
                  ),
                ),
                const Divider(height: 1, thickness: 1, color: AppTheme.border),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}

// ---------------------------------------------------------------------------
// Narrow layout
// ---------------------------------------------------------------------------
class _NarrowLayout extends StatelessWidget {
  final Widget child;
  final List<SidebarItem> items;
  final String currentPath;
  final String title;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final String? schoolName;

  const _NarrowLayout({
    required this.child,
    required this.items,
    required this.currentPath,
    required this.title,
    this.actions,
    this.floatingActionButton,
    this.schoolName,
  });

  @override
  Widget build(BuildContext context) {
    final navItems = items.take(5).toList();
    final currentIndex =
        navItems.indexWhere((i) => currentPath.startsWith(i.path));

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Text(title),
        actions: actions,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: AppTheme.border),
        ),
      ),
      body: child,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex < 0 ? 0 : currentIndex,
        onDestinationSelected: (i) => context.go(navItems[i].path),
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppTheme.primaryLight,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: navItems
            .map((item) => NavigationDestination(
                  icon: Icon(item.icon, color: AppTheme.textSecondary),
                  selectedIcon:
                      Icon(item.selectedIcon, color: AppTheme.primary),
                  label: item.label,
                ))
            .toList(),
      ),
    );
  }
}
