import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers/currency_provider.dart';

// ---------------------------------------------------------------------------
// Data model
// ---------------------------------------------------------------------------

class ParentInvoice {
  final String id;
  final String childId;
  final String childName;
  final DateTime referenceMonth;
  final double totalAmount;
  final String status;
  final DateTime? dueDate;
  final String? multicaixaEntity;
  final String? multicaixaRef;
  final double amountPaid;
  final double balance;

  const ParentInvoice({
    required this.id,
    required this.childId,
    required this.childName,
    required this.referenceMonth,
    required this.totalAmount,
    required this.status,
    this.dueDate,
    this.multicaixaEntity,
    this.multicaixaRef,
    required this.amountPaid,
    required this.balance,
  });

  factory ParentInvoice.fromJson(Map<String, dynamic> json) {
    return ParentInvoice(
      id: json['id']?.toString() ?? '',
      childId: json['child_id']?.toString() ?? '',
      childName: json['child_name'] as String? ?? 'Desconhecido',
      referenceMonth: json['reference_month'] != null
          ? DateTime.tryParse(json['reference_month'] as String) ?? DateTime.now()
          : DateTime.now(),
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'pending',
      dueDate: json['due_date'] != null
          ? DateTime.tryParse(json['due_date'] as String)
          : null,
      multicaixaEntity: json['multicaixa_entity'] as String?,
      multicaixaRef: json['multicaixa_ref'] as String?,
      amountPaid: (json['amount_paid'] as num?)?.toDouble() ?? 0.0,
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
    );
  }

  String get statusLabel {
    switch (status) {
      case 'paid':
        return 'Pago';
      case 'pending':
        return 'Pendente';
      case 'partially_paid':
        return 'Parcialmente Pago';
      case 'cancelled':
        return 'Cancelado';
      case 'overdue':
        return 'Em Atraso';
      default:
        return status;
    }
  }

  Color get statusColor {
    switch (status) {
      case 'paid':
        return Colors.green;
      case 'overdue':
        return Colors.red;
      case 'partially_paid':
        return Colors.orange;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final parentInvoicesProvider =
    FutureProvider.autoDispose<List<ParentInvoice>>((ref) async {
  final api = ref.read(apiClientProvider);
  final data = await api.get('/finance/parent/invoices') as List;
  return data
      .map((e) => ParentInvoice.fromJson(e as Map<String, dynamic>))
      .toList();
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class ParentInvoicesScreen extends ConsumerStatefulWidget {
  const ParentInvoicesScreen({super.key});

  @override
  ConsumerState<ParentInvoicesScreen> createState() =>
      _ParentInvoicesScreenState();
}

class _ParentInvoicesScreenState extends ConsumerState<ParentInvoicesScreen> {
  String _statusFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final invoicesAsync = ref.watch(parentInvoicesProvider);
    final currency = ref.watch(currencyFormatProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Faturas'),
      ),
      body: Column(
        children: [
          // Filter chips
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('all', 'Todas'),
                  const SizedBox(width: 8),
                  _buildFilterChip('pending', 'Pendentes'),
                  const SizedBox(width: 8),
                  _buildFilterChip('paid', 'Pagas'),
                  const SizedBox(width: 8),
                  _buildFilterChip('overdue', 'Em Atraso'),
                ],
              ),
            ),
          ),

          Expanded(
            child: invoicesAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: Colors.red),
                    const SizedBox(height: 8),
                    Text(e.toString(), textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => ref.invalidate(parentInvoicesProvider),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
              data: (invoices) {
                final filtered = _statusFilter == 'all'
                    ? invoices
                    : invoices
                        .where((i) => i.status == _statusFilter)
                        .toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long,
                            size: 64,
                            color: Theme.of(context)
                                .colorScheme
                                .outlineVariant),
                        const SizedBox(height: 16),
                        Text(
                          'Nenhuma fatura encontrada',
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(parentInvoicesProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 32),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      return _InvoiceCard(
                        invoice: filtered[i],
                        currency: currency,
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    return FilterChip(
      label: Text(label),
      selected: _statusFilter == value,
      showCheckmark: false,
      selectedColor:
          Theme.of(context).colorScheme.primaryContainer,
      onSelected: (_) => setState(() => _statusFilter = value),
    );
  }
}

// ---------------------------------------------------------------------------
// Invoice Card
// ---------------------------------------------------------------------------

class _InvoiceCard extends StatelessWidget {
  final ParentInvoice invoice;
  final NumberFormat currency;

  const _InvoiceCard({
    required this.invoice,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final monthLabel =
        DateFormat('MMMM yyyy', 'pt_PT').format(invoice.referenceMonth);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: child name + status chip
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invoice.childName,
                        style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        monthLabel,
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                _StatusBadge(
                    label: invoice.statusLabel,
                    color: invoice.statusColor),
              ],
            ),

            const SizedBox(height: 12),

            // Amount row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Valor total',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
                Text(
                  currency.format(invoice.totalAmount),
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),

            if (invoice.dueDate != null) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Data limite',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                  Text(
                    DateFormat('dd/MM/yyyy').format(invoice.dueDate!),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: invoice.status == 'overdue'
                          ? Colors.red
                          : null,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Multicaixa payment section
            if (invoice.multicaixaRef != null &&
                invoice.multicaixaEntity != null) ...[
              Row(
                children: [
                  const Icon(Icons.payment, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Pagar via Multicaixa',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _MulticaixaReceiptBox(
                entidade: invoice.multicaixaEntity!,
                referencia: invoice.multicaixaRef!,
                montante: currency.format(invoice.totalAmount),
              ),
            ] else ...[
              Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Referência de pagamento não disponível',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Multicaixa receipt box
// ---------------------------------------------------------------------------

class _MulticaixaReceiptBox extends StatelessWidget {
  final String entidade;
  final String referencia;
  final String montante;

  const _MulticaixaReceiptBox({
    required this.entidade,
    required this.referencia,
    required this.montante,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const borderColor = Color(0xFF005B9A); // Multicaixa brand blue

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor.withOpacity(0.4), width: 1.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.atm, color: borderColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'ATM / Multicaixa Express',
                style: theme.textTheme.labelMedium?.copyWith(
                    color: borderColor, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0x33005B9A)),
          const SizedBox(height: 14),
          _ReceiptRow(label: 'Entidade', value: entidade),
          const SizedBox(height: 10),
          _ReceiptRow(label: 'Referência', value: referencia),
          const SizedBox(height: 10),
          _ReceiptRow(label: 'Montante', value: montante, bold: true),
        ],
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const _ReceiptRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            letterSpacing: bold ? null : 1.4,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Status badge
// ---------------------------------------------------------------------------

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
