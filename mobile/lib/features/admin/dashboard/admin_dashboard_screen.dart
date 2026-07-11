import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/models/attendance.dart';
import '../../../core/theme/app_theme.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------
final adminChildrenCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
  final api = ref.read(apiClientProvider);
  final data = await api.get('/children');
  if (data is List) return data.length;
  if (data is Map) {
    return data['count'] as int? ?? data['total'] as int? ?? 0;
  }
  return 0;
});

final adminAttendanceTodayProvider =
    FutureProvider.autoDispose<AttendanceSummary>((ref) async {
  final api = ref.read(apiClientProvider);
  final data = await api.get('/attendance/today');
  if (data is Map<String, dynamic>) {
    return AttendanceSummary.fromJson(data);
  }
  if (data is List) {
    final records = data
        .map((e) => AttendanceRecord.fromJson(e as Map<String, dynamic>))
        .toList();
    final checkedIn =
        records.where((r) => r.status == 'present' || r.status == 'late').length;
    final absent = records.where((r) => r.status == 'absent').length;
    return AttendanceSummary(
      totalEnrolled: records.length,
      checkedIn: checkedIn,
      checkedOut: 0,
      absent: absent,
      records: records,
    );
  }
  return const AttendanceSummary(
      totalEnrolled: 0, checkedIn: 0, checkedOut: 0, absent: 0, records: []);
});

final adminUnreadNotifProvider =
    FutureProvider.autoDispose<int>((ref) async {
  final api = ref.read(apiClientProvider);
  final data = await api.get('/notifications/unread-count');
  if (data is Map) {
    return data['count'] as int? ?? data['unread_count'] as int? ?? 0;
  }
  if (data is int) return data;
  return 0;
});

final adminFinanceProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.read(apiClientProvider);
  try {
    final data = await api.get('/finance/dashboard');
    if (data is Map<String, dynamic>) return data;
  } catch (_) {}
  return {};
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------
class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final auth = ref.read(authProvider);
    final childrenAsync = ref.watch(adminChildrenCountProvider);
    final attendanceAsync = ref.watch(adminAttendanceTodayProvider);
    final unreadAsync = ref.watch(adminUnreadNotifProvider);
    final financeAsync = ref.watch(adminFinanceProvider);
    final theme = Theme.of(context);

    final now = DateTime.now();
    final hour = now.hour;
    final greeting = hour < 12
        ? 'Bom dia'
        : hour < 18
            ? 'Boa tarde'
            : 'Boa noite';
    final dateStr =
        DateFormat('EEEE, d \'de\' MMMM yyyy', 'pt_PT').format(now);

    void refresh() {
      ref.invalidate(adminChildrenCountProvider);
      ref.invalidate(adminAttendanceTodayProvider);
      ref.invalidate(adminUnreadNotifProvider);
      ref.invalidate(adminFinanceProvider);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          unreadAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (count) => Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () => context.push('/notifications'),
                ),
                if (count > 0)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: AppTheme.danger,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          count > 9 ? '9+' : '$count',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => refresh(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header card ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$greeting, ${auth.username ?? 'Administrador'}!',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1E1B4B),
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            dateStr,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                            ),
                          ),
                          if (auth.schoolId != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.school_outlined,
                                    size: 14,
                                    color: AppTheme.primary),
                                const SizedBox(width: 4),
                                Text(
                                  auth.schoolId!,
                                  style: TextStyle(
                                    color: AppTheme.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: AppTheme.gradientBlue,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.admin_panel_settings,
                          color: Colors.white, size: 28),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Stat cards ──
              Text(
                'Resumo do Dia',
                style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade800),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount:
                    MediaQuery.of(context).size.width >= 600 ? 4 : 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.35,
                children: [
                  _StatCard(
                    label: 'Crianças Activas',
                    gradient: AppTheme.gradientBlue,
                    icon: Icons.child_care,
                    valueWidget: childrenAsync.when(
                      loading: () => const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white)),
                      error: (_, __) =>
                          const Icon(Icons.error, color: Colors.white70),
                      data: (count) => Text(
                        '$count',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                    onTap: () => context.go('/admin/children'),
                  ),
                  _StatCard(
                    label: 'Presenças Hoje',
                    gradient: AppTheme.gradientGreen,
                    icon: Icons.how_to_reg,
                    valueWidget: attendanceAsync.when(
                      loading: () => const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white)),
                      error: (_, __) =>
                          const Icon(Icons.error, color: Colors.white70),
                      data: (s) => Text(
                        '${s.checkedIn}/${s.totalEnrolled}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                    onTap: () => context.push('/teacher/attendance'),
                  ),
                  _StatCard(
                    label: 'Faturas Pendentes',
                    gradient: AppTheme.gradientAmber,
                    icon: Icons.receipt_long,
                    valueWidget: financeAsync.when(
                      loading: () => const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white)),
                      error: (_, __) =>
                          const Icon(Icons.error, color: Colors.white70),
                      data: (finance) {
                        final pending =
                            finance['outstanding_invoices'] as int? ??
                                finance['pending_invoices'] as int? ??
                                0;
                        return Text(
                          '$pending',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w800),
                        );
                      },
                    ),
                    onTap: () => context.go('/admin/finance/invoices'),
                  ),
                  _StatCard(
                    label: 'Mensagens',
                    gradient: AppTheme.gradientRose,
                    icon: Icons.chat_bubble_outline,
                    valueWidget: unreadAsync.when(
                      loading: () => const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white)),
                      error: (_, __) =>
                          const Icon(Icons.error, color: Colors.white70),
                      data: (count) => Text(
                        '$count',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                    onTap: () => context.push('/messages'),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ── Quick Actions ──
              Text(
                'Acções Rápidas',
                style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade800),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 4,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 0.9,
                children: [
                  _QuickAction(
                    icon: Icons.how_to_reg,
                    label: 'Presenças',
                    color: AppTheme.success,
                    onTap: () => context.push('/teacher/attendance'),
                  ),
                  _QuickAction(
                    icon: Icons.receipt,
                    label: 'Nova Fatura',
                    color: AppTheme.warning,
                    onTap: () => context.go('/admin/finance/invoices'),
                  ),
                  _QuickAction(
                    icon: Icons.warning_amber_rounded,
                    label: 'Ocorrências',
                    color: AppTheme.danger,
                    onTap: () => context.push('/incidents'),
                  ),
                  _QuickAction(
                    icon: Icons.event,
                    label: 'Calendário',
                    color: const Color(0xFF8B5CF6),
                    onTap: () => context.push('/events'),
                  ),
                  _QuickAction(
                    icon: Icons.child_care,
                    label: 'Crianças',
                    color: AppTheme.primary,
                    onTap: () => context.go('/admin/children'),
                  ),
                  _QuickAction(
                    icon: Icons.people,
                    label: 'Funcionários',
                    color: const Color(0xFF0EA5E9),
                    onTap: () => context.go('/admin/employees'),
                  ),
                  _QuickAction(
                    icon: Icons.chat_bubble_outline,
                    label: 'Mensagens',
                    color: AppTheme.info,
                    onTap: () => context.push('/messages'),
                  ),
                  _QuickAction(
                    icon: Icons.account_balance_wallet,
                    label: 'Finanças',
                    color: AppTheme.success,
                    onTap: () => context.go('/admin/finance'),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ── Recent Activity ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Actividade Recente',
                    style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade800),
                  ),
                  TextButton(
                    onPressed: () => context.push('/teacher/attendance'),
                    child: const Text('Ver todas'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              attendanceAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text(
                  'Erro ao carregar actividade: $e',
                  style: TextStyle(
                      color: theme.colorScheme.error),
                ),
                data: (summary) {
                  final recent = summary.records.take(5).toList();
                  if (recent.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.how_to_reg,
                                size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text('Sem registos de presença hoje',
                                style: TextStyle(
                                    color: Colors.grey.shade500)),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: refresh,
                              child: const Text('Actualizar'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: recent
                          .asMap()
                          .entries
                          .map((entry) {
                        final isLast = entry.key == recent.length - 1;
                        return Column(
                          children: [
                            _AttendanceActivityTile(
                                record: entry.value),
                            if (!isLast)
                              Divider(
                                  height: 1,
                                  color: Colors.grey.shade100),
                          ],
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Widgets
// ---------------------------------------------------------------------------

class _StatCard extends StatelessWidget {
  final String label;
  final Widget valueWidget;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback? onTap;

  const _StatCard({
    required this.label,
    required this.valueWidget,
    required this.icon,
    required this.gradient,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: gradient.first.withOpacity(0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Spacer(),
                Icon(icon, color: Colors.white.withOpacity(0.8), size: 22),
              ],
            ),
            const Spacer(),
            valueWidget,
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _AttendanceActivityTile extends StatelessWidget {
  final AttendanceRecord record;

  const _AttendanceActivityTile({required this.record});

  @override
  Widget build(BuildContext context) {
    final initials = record.childName.isNotEmpty
        ? record.childName.trim().split(' ').take(2).map((w) => w[0]).join()
        : '?';

    Color bgColor;
    Color textColor;
    String statusLabel;
    switch (record.status) {
      case 'present':
        bgColor = const Color(0xFFD1FAE5);
        textColor = const Color(0xFF065F46);
        statusLabel = 'Presente';
        break;
      case 'late':
        bgColor = const Color(0xFFFEF3C7);
        textColor = const Color(0xFF92400E);
        statusLabel = 'Tarde';
        break;
      case 'absent':
        bgColor = const Color(0xFFFEE2E2);
        textColor = const Color(0xFF991B1B);
        statusLabel = 'Ausente';
        break;
      default:
        bgColor = Colors.grey.shade100;
        textColor = Colors.grey.shade700;
        statusLabel = record.status;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppTheme.primary.withOpacity(0.1),
            child: Text(
              initials.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(record.childName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                if (record.checkInTime != null)
                  Text('Entrada: ${record.checkInTime}',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500)),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                  color: textColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
