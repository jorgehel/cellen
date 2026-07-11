import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/models/child.dart';
import '../../../core/models/caderneta.dart';
import '../../../core/models/invoice.dart';
import '../../../core/theme/app_theme.dart';

// ---------------------------------------------------------------------------
// Providers — FIXED API paths
// ---------------------------------------------------------------------------
final parentChildrenProvider =
    FutureProvider.autoDispose<List<Child>>((ref) async {
  final api = ref.read(apiClientProvider);
  final data = await api.get('/children/my') as List;
  return data
      .map((e) => Child.fromJson(e as Map<String, dynamic>))
      .toList();
});

final parentRecentCadernetsProvider =
    FutureProvider.autoDispose<List<Caderneta>>((ref) async {
  final api = ref.read(apiClientProvider);
  final data = await api.get('/cadernetas',
      queryParameters: {'limit': '5', 'ordering': '-report_date'}) as List;
  return data
      .map((e) => Caderneta.fromJson(e as Map<String, dynamic>))
      .toList();
});

final parentOutstandingInvoicesProvider =
    FutureProvider.autoDispose<List<Invoice>>((ref) async {
  final api = ref.read(apiClientProvider);
  final data = await api.get('/invoices',
      queryParameters: {
        'limit': '5',
        'ordering': '-invoice_date',
        'status': 'pending,overdue',
      }) as List;
  return data
      .map((e) => Invoice.fromJson(e as Map<String, dynamic>))
      .toList();
});

final parentUnreadMessagesProvider =
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
class ParentDashboardScreen extends ConsumerStatefulWidget {
  const ParentDashboardScreen({super.key});

  @override
  ConsumerState<ParentDashboardScreen> createState() =>
      _ParentDashboardScreenState();
}

class _ParentDashboardScreenState
    extends ConsumerState<ParentDashboardScreen> {
  bool _dismissedInvoiceBanner = false;

  @override
  Widget build(BuildContext context) {
    final auth = ref.read(authProvider);
    final childrenAsync = ref.watch(parentChildrenProvider);
    final cadernetasAsync = ref.watch(parentRecentCadernetsProvider);
    final invoicesAsync = ref.watch(parentOutstandingInvoicesProvider);
    final unreadAsync = ref.watch(parentUnreadMessagesProvider);
    final currency = NumberFormat.currency(locale: 'pt_PT', symbol: '€');
    final now = DateTime.now();
    final theme = Theme.of(context);

    void refresh() {
      ref.invalidate(parentChildrenProvider);
      ref.invalidate(parentRecentCadernetsProvider);
      ref.invalidate(parentOutstandingInvoicesProvider);
      ref.invalidate(parentUnreadMessagesProvider);
      setState(() => _dismissedInvoiceBanner = false);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Início'),
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
              // ── Greeting ──
              Text(
                'Olá, ${auth.username ?? 'Encarregado'}!',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1E1B4B),
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                DateFormat('EEEE, d \'de\' MMMM', 'pt_PT').format(now),
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),

              // ── Finance alert banner ──
              if (!_dismissedInvoiceBanner)
                invoicesAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (invoices) {
                    if (invoices.isEmpty) return const SizedBox.shrink();
                    final total = invoices.fold<double>(
                        0.0, (sum, i) => sum + i.totalAmount);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: AppTheme.warning.withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppTheme.warning.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.warning_amber_rounded,
                                color: AppTheme.warning, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${invoices.length} fatura(s) por pagar',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color:
                                          const Color(0xFF92400E),
                                      fontSize: 13),
                                ),
                                Text(
                                  'Total: ${currency.format(total)}',
                                  style: TextStyle(
                                      color: Colors.amber.shade700,
                                      fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close,
                                size: 18, color: Colors.amber.shade700),
                            onPressed: () => setState(
                                () => _dismissedInvoiceBanner = true),
                          ),
                        ],
                      ),
                    );
                  },
                ),

              // ── Children cards ──
              Text(
                'As Minhas Crianças',
                style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade800),
              ),
              const SizedBox(height: 12),
              childrenAsync.when(
                loading: () => const SizedBox(
                  height: 120,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Text('Erro: $e'),
                ),
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
                        child: Text('Nenhuma criança associada',
                            style:
                                TextStyle(color: Colors.grey.shade500)),
                      ),
                    );
                  }
                  return Column(
                    children: children
                        .map((child) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _ChildCard(child: child),
                            ))
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 20),

              // ── Quick links ──
              Text(
                'Acesso Rápido',
                style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade800),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _QuickLinkCard(
                      icon: Icons.chat_bubble_outline,
                      label: 'Mensagens',
                      color: AppTheme.info,
                      badge: unreadAsync.valueOrNull,
                      onTap: () => context.push('/messages'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _QuickLinkCard(
                      icon: Icons.photo_library_outlined,
                      label: 'Galeria',
                      color: AppTheme.success,
                      onTap: () => context.push('/photos'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _QuickLinkCard(
                      icon: Icons.book_outlined,
                      label: 'Caderneta',
                      color: const Color(0xFF8B5CF6),
                      onTap: () => context.go('/parent/caderneta'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Recent cadernetas ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Relatórios Recentes',
                    style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade800),
                  ),
                  TextButton(
                    onPressed: () => context.go('/parent/caderneta'),
                    child: const Text('Ver todos'),
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
                            Text('Nenhum relatório disponível ainda',
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
                                DateFormat('dd/MM/yyyy')
                                    .format(c.reportDate),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14),
                              ),
                              subtitle:
                                  _buildRatingSummary(c),
                              trailing: const Icon(Icons.chevron_right,
                                  size: 18,
                                  color: Colors.grey),
                              onTap: () =>
                                  context.go('/parent/caderneta'),
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

              const SizedBox(height: 24),

              // ── Invoices ──
              Text(
                'Faturas',
                style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade800),
              ),
              const SizedBox(height: 8),
              invoicesAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (invoices) {
                  if (invoices.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppTheme.success.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.check_circle,
                                color: AppTheme.success, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Sem faturas pendentes',
                            style: TextStyle(
                                color: Colors.grey.shade600),
                          ),
                        ],
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
                      children: invoices.take(3).toList().asMap().entries.map((entry) {
                        final isLast =
                            entry.key == (invoices.length < 3 ? invoices.length - 1 : 2);
                        final inv = entry.value;
                        final isOverdue = inv.status == 'overdue';
                        return Column(
                          children: [
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 4),
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppTheme.warning
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.receipt_long,
                                    color: AppTheme.warning, size: 20),
                              ),
                              title: Text(
                                inv.description ??
                                    inv.childName ??
                                    'Fatura',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14),
                              ),
                              subtitle: Text(
                                currency.format(inv.totalAmount),
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500),
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isOverdue
                                      ? AppTheme.danger.withOpacity(0.1)
                                      : AppTheme.warning.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  isOverdue ? 'Em Atraso' : 'Pendente',
                                  style: TextStyle(
                                      color: isOverdue
                                          ? AppTheme.danger
                                          : AppTheme.warning,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
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

  Widget _buildRatingSummary(Caderneta c) {
    final parts = <String>[];
    if (c.lunchRating != null) parts.add('Almoço: ${c.lunchRating}');
    if (c.hadNap == true) parts.add('Dormiu');
    if (parts.isEmpty) return const Text('Ver detalhes');
    return Text(parts.join(' · '),
        style: TextStyle(fontSize: 12, color: Colors.grey.shade500));
  }
}

// ---------------------------------------------------------------------------
// Widgets
// ---------------------------------------------------------------------------

class _ChildCard extends StatelessWidget {
  final Child child;

  const _ChildCard({required this.child});

  @override
  Widget build(BuildContext context) {
    String? ageStr;
    if (child.birthDate != null) {
      final now = DateTime.now();
      final diff = now.difference(child.birthDate!);
      final years = (diff.inDays / 365.25).floor();
      final months = ((diff.inDays % 365.25) / 30.44).floor();
      if (years > 0) {
        ageStr = '$years ${years == 1 ? 'ano' : 'anos'}';
      } else {
        ageStr = '$months ${months == 1 ? 'mês' : 'meses'}';
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          // Accent bar
          Container(
            width: 4,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
            ),
          ),
          const SizedBox(width: 16),
          _ChildAvatar(name: child.fullName, photoUrl: child.photoUrl),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    child.fullName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Color(0xFF1E1B4B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (child.turmaName != null)
                    Text(
                      child.turmaName!,
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 12),
                    ),
                  if (ageStr != null)
                    Text(
                      ageStr,
                      style: TextStyle(
                          color: Colors.grey.shade400, fontSize: 11),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Icon(Icons.chevron_right,
                color: Colors.grey.shade400, size: 20),
          ),
        ],
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
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: photoUrl!,
            width: 52,
            height: 52,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => _initialsAvatar(),
          ),
        ),
      );
    }
    return _initialsAvatar();
  }

  Widget _initialsAvatar() {
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

class _QuickLinkCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final int? badge;
  final VoidCallback onTap;

  const _QuickLinkCard({
    required this.icon,
    required this.label,
    required this.color,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                if (badge != null && badge! > 0)
                  Positioned(
                    top: -5,
                    right: -5,
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
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
