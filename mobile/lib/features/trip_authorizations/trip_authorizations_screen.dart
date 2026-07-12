import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_provider.dart';

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------
class TripAuth {
  final String id;
  final String title;
  final String? description;
  final DateTime tripDate;
  final String? destination;
  final String? departureTime;
  final String? returnTime;
  final DateTime? deadlineDate;
  final int respondedCount;
  final bool? childResponse; // null = not responded (parent view)

  const TripAuth({
    required this.id,
    required this.title,
    this.description,
    required this.tripDate,
    this.destination,
    this.departureTime,
    this.returnTime,
    this.deadlineDate,
    required this.respondedCount,
    this.childResponse,
  });

  factory TripAuth.fromJson(Map<String, dynamic> json) => TripAuth(
        id: json['id']?.toString() ?? '',
        title: json['title'] as String? ?? '',
        description: json['description'] as String?,
        tripDate: json['trip_date'] != null
            ? DateTime.tryParse(json['trip_date'] as String) ?? DateTime.now()
            : DateTime.now(),
        destination: json['destination'] as String?,
        departureTime: json['departure_time'] as String?,
        returnTime: json['return_time'] as String?,
        deadlineDate: json['deadline_date'] != null
            ? DateTime.tryParse(json['deadline_date'] as String)
            : null,
        respondedCount: json['responded_count'] as int? ?? 0,
        childResponse: json['child_response'] as bool?,
      );
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------
final tripAuthorizationsProvider =
    FutureProvider.autoDispose<List<TripAuth>>((ref) async {
  final api = ref.read(apiClientProvider);
  final data = await api.get('/trip-authorizations') as List;
  return data
      .map((e) => TripAuth.fromJson(e as Map<String, dynamic>))
      .toList();
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------
class TripAuthorizationsScreen extends ConsumerWidget {
  const TripAuthorizationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authsAsync = ref.watch(tripAuthorizationsProvider);
    final authState = ref.watch(authProvider);
    final canCreate = authState.isAdmin || authState.isTeacher;
    final isParent = authState.isParent;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Autorizações de Saída'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(tripAuthorizationsProvider),
          ),
        ],
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () => _showCreateDialog(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Nova Autorização'),
            )
          : null,
      body: authsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 8),
              Text(e.toString(), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(tripAuthorizationsProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
        data: (auths) {
          if (auths.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.assignment_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.outlineVariant),
                  const SizedBox(height: 16),
                  Text(
                    'Sem autorizações de saída',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(tripAuthorizationsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
              itemCount: auths.length,
              itemBuilder: (context, i) {
                final auth = auths[i];
                if (isParent) {
                  return _ParentTripCard(
                    trip: auth,
                    onResponded: () => ref.invalidate(tripAuthorizationsProvider),
                  );
                }
                return _AdminTripCard(
                  trip: auth,
                  onDeleted: () => ref.invalidate(tripAuthorizationsProvider),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
    await showDialog(
      context: context,
      builder: (_) => _CreateTripDialog(
        onCreated: () => ref.invalidate(tripAuthorizationsProvider),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Admin/Teacher card
// ---------------------------------------------------------------------------
class _AdminTripCard extends ConsumerWidget {
  final TripAuth trip;
  final VoidCallback onDeleted;

  const _AdminTripCard({required this.trip, required this.onDeleted});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateStr = DateFormat('dd/MM/yyyy').format(trip.tripDate);
    final isPast = trip.tripDate.isBefore(DateTime.now());

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    trip.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                if (isPast)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('Passada',
                        style:
                            TextStyle(fontSize: 11, color: Colors.grey)),
                  ),
                PopupMenuButton<String>(
                  onSelected: (action) async {
                    if (action == 'delete') {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Eliminar Autorização'),
                          content: const Text(
                              'Tem a certeza que deseja eliminar esta autorização?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancelar'),
                            ),
                            TextButton(
                              style: TextButton.styleFrom(
                                  foregroundColor: Colors.red),
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Eliminar'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true && context.mounted) {
                        try {
                          await ref
                              .read(apiClientProvider)
                              .delete('/trip-authorizations/${trip.id}');
                          onDeleted();
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Erro: $e')),
                            );
                          }
                        }
                      }
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Eliminar',
                          style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            _InfoRow(icon: Icons.calendar_today, text: dateStr),
            if (trip.destination != null)
              _InfoRow(icon: Icons.place_outlined, text: trip.destination!),
            if (trip.departureTime != null)
              _InfoRow(
                  icon: Icons.schedule,
                  text:
                      'Saída: ${trip.departureTime}${trip.returnTime != null ? '  •  Regresso: ${trip.returnTime}' : ''}'),
            if (trip.description != null && trip.description!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(trip.description!,
                  style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.how_to_reg_outlined,
                    size: 16, color: Colors.teal),
                const SizedBox(width: 6),
                Text('${trip.respondedCount} respostas',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Parent card with respond buttons
// ---------------------------------------------------------------------------
class _ParentTripCard extends ConsumerStatefulWidget {
  final TripAuth trip;
  final VoidCallback onResponded;

  const _ParentTripCard({required this.trip, required this.onResponded});

  @override
  ConsumerState<_ParentTripCard> createState() => _ParentTripCardState();
}

class _ParentTripCardState extends ConsumerState<_ParentTripCard> {
  bool _isResponding = false;

  Future<void> _respond(bool authorized) async {
    setState(() => _isResponding = true);
    try {
      final api = ref.read(apiClientProvider);
      // We need child_id — fetch current user's first child
      final childrenData =
          await api.get('/children/my') as List;
      if (childrenData.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('Nenhuma criança associada à sua conta')),
          );
        }
        return;
      }
      final childId = childrenData.first['id']?.toString();
      await api.post('/trip-authorizations/${widget.trip.id}/respond',
          data: {
            'child_id': childId,
            'authorized': authorized,
          });
      widget.onResponded();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isResponding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd/MM/yyyy').format(widget.trip.tripDate);
    final hasResponded = widget.trip.childResponse != null;
    final isDeadlinePast = widget.trip.deadlineDate != null &&
        widget.trip.deadlineDate!.isBefore(DateTime.now());

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: hasResponded ? 1 : 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: hasResponded
            ? BorderSide(
                color: widget.trip.childResponse!
                    ? Colors.green.shade300
                    : Colors.red.shade300,
                width: 1.5)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.trip.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                if (hasResponded)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: widget.trip.childResponse!
                          ? Colors.green.shade100
                          : Colors.red.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.trip.childResponse!
                              ? Icons.check_circle
                              : Icons.cancel,
                          size: 14,
                          color: widget.trip.childResponse!
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.trip.childResponse!
                              ? 'Autorizado'
                              : 'Não Autorizado',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: widget.trip.childResponse!
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _InfoRow(icon: Icons.calendar_today, text: dateStr),
            if (widget.trip.destination != null)
              _InfoRow(
                  icon: Icons.place_outlined, text: widget.trip.destination!),
            if (widget.trip.departureTime != null)
              _InfoRow(
                  icon: Icons.schedule,
                  text:
                      'Saída: ${widget.trip.departureTime}${widget.trip.returnTime != null ? '  •  Regresso: ${widget.trip.returnTime}' : ''}'),
            if (widget.trip.deadlineDate != null)
              _InfoRow(
                icon: Icons.event_busy_outlined,
                text:
                    'Prazo: ${DateFormat('dd/MM/yyyy').format(widget.trip.deadlineDate!)}',
                color: isDeadlinePast ? Colors.red : null,
              ),
            if (widget.trip.description != null &&
                widget.trip.description!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(widget.trip.description!,
                  style: TextStyle(
                      fontSize: 13,
                      color:
                          Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
            if (!hasResponded && !isDeadlinePast) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          _isResponding ? null : () => _respond(false),
                      icon: const Icon(Icons.close, color: Colors.red),
                      label: const Text('Não Autorizar',
                          style: TextStyle(color: Colors.red)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed:
                          _isResponding ? null : () => _respond(true),
                      icon: const Icon(Icons.check),
                      label: const Text('Autorizar'),
                      style: FilledButton.styleFrom(
                          backgroundColor: Colors.green),
                    ),
                  ),
                ],
              ),
            ] else if (isDeadlinePast && !hasResponded)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'Prazo de resposta ultrapassado',
                  style: TextStyle(
                      color: Colors.red.shade600,
                      fontSize: 12,
                      fontStyle: FontStyle.italic),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Create dialog
// ---------------------------------------------------------------------------
class _CreateTripDialog extends ConsumerStatefulWidget {
  final VoidCallback onCreated;
  const _CreateTripDialog({required this.onCreated});

  @override
  ConsumerState<_CreateTripDialog> createState() => _CreateTripDialogState();
}

class _CreateTripDialogState extends ConsumerState<_CreateTripDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _destCtrl = TextEditingController();
  DateTime _tripDate = DateTime.now().add(const Duration(days: 7));
  DateTime? _deadline;
  TimeOfDay? _departure;
  TimeOfDay? _returnTime;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _destCtrl.dispose();
    super.dispose();
  }

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/trip-authorizations', data: {
        'title': _titleCtrl.text.trim(),
        if (_descCtrl.text.trim().isNotEmpty) 'description': _descCtrl.text.trim(),
        'trip_date':
            '${_tripDate.year.toString().padLeft(4, '0')}-${_tripDate.month.toString().padLeft(2, '0')}-${_tripDate.day.toString().padLeft(2, '0')}',
        if (_destCtrl.text.trim().isNotEmpty) 'destination': _destCtrl.text.trim(),
        if (_departure != null) 'departure_time': '${_fmtTime(_departure!)}:00',
        if (_returnTime != null) 'return_time': '${_fmtTime(_returnTime!)}:00',
        if (_deadline != null)
          'deadline_date':
              '${_deadline!.year.toString().padLeft(4, '0')}-${_deadline!.month.toString().padLeft(2, '0')}-${_deadline!.day.toString().padLeft(2, '0')}',
      });
      widget.onCreated();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nova Autorização de Saída'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_error != null)
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(_error!,
                        style: TextStyle(color: Colors.red.shade800)),
                  ),
                TextFormField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Título *', border: OutlineInputBorder()),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _destCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Destino', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      labelText: 'Descrição', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: Text(
                      'Data da saída: ${DateFormat('dd/MM/yyyy').format(_tripDate)}'),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _tripDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setState(() => _tripDate = picked);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.schedule),
                  title: Text(_departure != null
                      ? 'Partida: ${_fmtTime(_departure!)}'
                      : 'Hora de partida'),
                  onTap: () async {
                    final t = await showTimePicker(
                        context: context,
                        initialTime:
                            _departure ?? const TimeOfDay(hour: 8, minute: 0));
                    if (t != null) setState(() => _departure = t);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.keyboard_return),
                  title: Text(_returnTime != null
                      ? 'Regresso: ${_fmtTime(_returnTime!)}'
                      : 'Hora de regresso'),
                  onTap: () async {
                    final t = await showTimePicker(
                        context: context,
                        initialTime: _returnTime ??
                            const TimeOfDay(hour: 17, minute: 0));
                    if (t != null) setState(() => _returnTime = t);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.event_busy_outlined),
                  title: Text(_deadline != null
                      ? 'Prazo: ${DateFormat('dd/MM/yyyy').format(_deadline!)}'
                      : 'Prazo de resposta (opcional)'),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _deadline ?? _tripDate,
                      firstDate: DateTime.now(),
                      lastDate: _tripDate,
                    );
                    if (picked != null) setState(() => _deadline = picked);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Criar'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared helper
// ---------------------------------------------------------------------------
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;

  const _InfoRow({required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: c),
          const SizedBox(width: 6),
          Expanded(
              child: Text(text,
                  style: TextStyle(fontSize: 13, color: c))),
        ],
      ),
    );
  }
}
