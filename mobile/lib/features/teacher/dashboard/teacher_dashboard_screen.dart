import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/models/attendance.dart';
import '../../../core/models/caderneta.dart';
import '../../../core/models/child.dart';
import '../../../core/theme/app_theme.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------
final teacherAttendanceTodayProvider =
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
    final checkedOut = records
        .where((r) => r.checkOutTime != null && r.checkOutTime!.isNotEmpty)
        .length;
    final absent = records.where((r) => r.status == 'absent').length;
    return AttendanceSummary(
      totalEnrolled: records.length,
      checkedIn: checkedIn,
      checkedOut: checkedOut,
      absent: absent,
      records: records,
    );
  }
  return const AttendanceSummary(
      totalEnrolled: 0, checkedIn: 0, checkedOut: 0, absent: 0, records: []);
});

final teacherRecentCadernetsProvider =
    FutureProvider.autoDispose<List<Caderneta>>((ref) async {
  final api = ref.read(apiClientProvider);
  final data = await api.get('/cadernetas/my',
      queryParameters: {'limit': '5', 'ordering': '-report_date'}) as List;
  return data
      .map((e) => Caderneta.fromJson(e as Map<String, dynamic>))
      .toList();
});

final teacherChildrenProvider =
    FutureProvider.autoDispose<List<Child>>((ref) async {
  final api = ref.read(apiClientProvider);
  final data = await api.get('/children/my') as List;
  return data
      .map((e) => Child.fromJson(e as Map<String, dynamic>))
      .toList();
});

final teacherUnreadMsgProvider =
    FutureProvider.autoDispose<int>((ref) async {
  final api = ref.read(apiClientProvider);
  final data = await api.get('/notifications/unread-count');
  if (data is Map) {
    return data['count'] as int? ?? data['unread_count'] as int? ?? 0;
  }
  if (data is int) return data;
  return 0;
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------
class TeacherDashboardScreen extends ConsumerStatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  ConsumerState<TeacherDashboardScreen> createState() =>
      _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState
    extends ConsumerState<TeacherDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final auth = ref.read(authProvider);
    final attendanceAsync = ref.watch(teacherAttendanceTodayProvider);
    final cadernetasAsync = ref.watch(teacherRecentCadernetsProvider);
    final childrenAsync = ref.watch(teacherChildrenProvider);
    final unreadAsync = ref.watch(teacherUnreadMsgProvider);
    final theme = Theme.of(context);

    final now = DateTime.now();
    final hour = now.hour;
    final greeting = hour < 12
        ? 'Bom dia'
        : hour < 18
            ? 'Boa tarde'
            : 'Boa noite';
    final dateStr =
        DateFormat('EEEE, d \'de\' MMMM', 'pt_PT').format(now);

    void refresh() {
      ref.invalidate(teacherAttendanceTodayProvider);
      ref.invalidate(teacherRecentCadernetsProvider);
      ref.invalidate(teacherChildrenProvider);
      ref.invalidate(teacherUnreadMsgProvider);
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
                  gradient: LinearGradient(
                    colors: AppTheme.gradientBlue,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$greeting, ${auth.username ?? 'Educador(a)'}!',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Aqui está o resumo de hoje',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateStr,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Attendance summary card ──
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Presenças — ',
                          style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Colors.grey.shade800),
                        ),
                        Text(
                          DateFormat('d MMM', 'pt_PT').format(now),
                          style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    attendanceAsync.when(
                      loading: () => const Center(
                          child: CircularProgressIndicator()),
                      error: (_, __) => Text('Erro ao carregar',
                          style: TextStyle(color: AppTheme.danger)),
                      data: (s) => Row(
                        children: [
                          _AttendStat(
                            value: '${s.totalEnrolled}',
                            label: 'Total',
                            color: const Color(0xFF4F46E5),
                          ),
                          _dividerLine(),
                          _AttendStat(
                            value: '${s.checkedIn}',
                            label: 'Presentes',
                            color: AppTheme.success,
                          ),
                          _dividerLine(),
                          _AttendStat(
                            value: '${s.absent}',
                            label: 'Ausentes',
                            color: AppTheme.danger,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            context.push('/teacher/attendance'),
                        icon: const Icon(Icons.how_to_reg, size: 18),
                        label: const Text('Ver Presenças'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          side: BorderSide(color: AppTheme.primary),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Caderneta & Messages cards side by side ──
              Row(
                children: [
                  Expanded(
                    child: _ActionCard(
                      icon: Icons.edit_note,
                      label: 'Caderneta',
                      subtitle: 'Preencher relatório',
                      color: const Color(0xFF8B5CF6),
                      onTap: () =>
                          context.push('/teacher/caderneta/new'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: unreadAsync.when(
                      loading: () => _ActionCard(
                        icon: Icons.chat_bubble_outline,
                        label: 'Mensagens',
                        subtitle: 'A carregar...',
                        color: AppTheme.info,
                        onTap: () => context.push('/messages'),
                      ),
                      error: (_, __) => _ActionCard(
                        icon: Icons.chat_bubble_outline,
                        label: 'Mensagens',
                        subtitle: 'Abrir',
                        color: AppTheme.info,
                        onTap: () => context.push('/messages'),
                      ),
                      data: (count) => _ActionCard(
                        icon: Icons.chat_bubble_outline,
                        label: 'Mensagens',
                        subtitle: count > 0
                            ? '$count não lida(s)'
                            : 'Sem mensagens novas',
                        color: AppTheme.info,
                        badge: count > 0 ? count : null,
                        onTap: () => context.push('/messages'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── My Children ──
              Text(
                'As Minhas Crianças',
                style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade800),
              ),
              const SizedBox(height: 12),
              childrenAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Erro: $e',
                    style: TextStyle(
                        color: theme.colorScheme.error)),
                data: (children) {
                  if (children.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Center(
                        child: Text('Nenhuma criança atribuída.',
                            style: TextStyle(
                                color: Colors.grey.shade500)),
                      ),
                    );
                  }
                  return SizedBox(
                    height: 90,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: children.length,
                      itemBuilder: (context, i) {
                        final child = children[i];
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Column(
                            children: [
                              _ChildAvatar(
                                name: child.fullName,
                                photoUrl: child.photoUrl,
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                width: 56,
                                child: Text(
                                  child.firstName,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              // ── Recent cadernetas ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Cadernetas Recentes',
                    style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade800),
                  ),
                  TextButton(
                    onPressed: () => context.go('/teacher/caderneta'),
                    child: const Text('Ver todas'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              cadernetasAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Erro: $e'),
                data: (cadernetas) {
                  if (cadernetas.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.book_outlined,
                                size: 48, color: Colors.grey.shade300),
                            const SizedBox(height: 8),
                            Text('Nenhuma caderneta preenchida ainda',
                                style: TextStyle(
                                    color: Colors.grey.shade500)),
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
                      children: cadernetas
                          .asMap()
                          .entries
                          .map((entry) {
                        final isLast =
                            entry.key == cadernetas.length - 1;
                        final c = entry.value;
                        return Column(
                          children: [
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 4),
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF8B5CF6)
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.book_outlined,
                                    color: Color(0xFF8B5CF6), size: 20),
                              ),
                              title: Text(
                                c.childName ??
                                    'Criança ${c.childId.substring(0, 6)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14),
                              ),
                              subtitle: Text(
                                DateFormat('dd/MM/yyyy')
                                    .format(c.reportDate),
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500),
                              ),
                              trailing: _RatingBadge(
                                  rating: c.lunchRating ??
                                      c.breakfastRating),
                              onTap: () => context.push(
                                  '/teacher/caderneta/${c.id}/edit'),
                            ),
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

  Widget _dividerLine() {
    return Container(
      width: 1,
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: Colors.grey.shade200,
    );
  }
}

// ---------------------------------------------------------------------------
// Widgets
// ---------------------------------------------------------------------------

class _AttendStat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _AttendStat({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final int? badge;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                if (badge != null && badge! > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppTheme.danger,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        badge! > 9 ? '9+' : '$badge',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                  fontSize: 12, color: Colors.grey.shade500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChildAvatar extends StatelessWidget {
  final String name;
  final String? photoUrl;

  const _ChildAvatar({required this.name, this.photoUrl});

  @override
  Widget build(BuildContext context) {
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 26,
        backgroundImage: NetworkImage(photoUrl!),
        onBackgroundImageError: (_, __) {},
      );
    }
    final initials = name.isNotEmpty
        ? name.trim().split(' ').take(2).map((w) => w[0]).join()
        : '?';
    return CircleAvatar(
      radius: 26,
      backgroundColor: AppTheme.primary.withOpacity(0.1),
      child: Text(
        initials.toUpperCase(),
        style: TextStyle(
          color: AppTheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _RatingBadge extends StatelessWidget {
  final String? rating;

  const _RatingBadge({this.rating});

  @override
  Widget build(BuildContext context) {
    if (rating == null) return const SizedBox.shrink();
    Color color;
    switch (rating) {
      case 'Muito Bem':
        color = AppTheme.success;
        break;
      case 'Bem':
        color = const Color(0xFF14B8A6);
        break;
      case 'Mal':
        color = AppTheme.danger;
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        rating!,
        style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
