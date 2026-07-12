import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/api_client.dart';
import '../../core/providers/currency_provider.dart';
import '../../core/theme/app_theme.dart';

class SchoolProfileScreen extends ConsumerStatefulWidget {
  const SchoolProfileScreen({super.key});

  @override
  ConsumerState<SchoolProfileScreen> createState() =>
      _SchoolProfileScreenState();
}

class _SchoolProfileScreenState extends ConsumerState<SchoolProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _nameLoaded = false;
  bool _saving = false;
  bool _uploading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  // Pre-fill the name field once school data arrives
  void _populateName(String name) {
    if (!_nameLoaded) {
      _nameCtrl.text = name;
      _nameLoaded = true;
    }
  }

  Future<void> _pickAndUploadLogo() async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 90,
    );
    if (xFile == null) return;

    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      await ref.read(apiClientProvider).uploadFile('/schools/logo', xFile);
      ref.invalidate(schoolInfoProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logótipo actualizado')),
        );
      }
    } catch (e) {
      setState(() => _error = 'Erro ao carregar logótipo: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _saveName() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(apiClientProvider).patch(
        '/schools/me',
        data: {'name': _nameCtrl.text.trim()},
      );
      ref.invalidate(schoolInfoProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dados guardados')),
        );
      }
    } catch (e) {
      setState(() => _error = 'Erro ao guardar: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final schoolAsync = ref.watch(schoolInfoProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil da Escola'),
      ),
      body: schoolAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: AppTheme.danger),
              const SizedBox(height: 8),
              Text(e.toString(), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(schoolInfoProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
        data: (school) {
          _populateName(school.name);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ----- Logo section -----
                    Text(
                      'Logótipo',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _LogoPreview(
                          logoUrl: school.logoUrl,
                          uploading: _uploading,
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ElevatedButton.icon(
                                onPressed:
                                    _uploading ? null : _pickAndUploadLogo,
                                icon: const Icon(Icons.upload_outlined,
                                    size: 18),
                                label: Text(_uploading
                                    ? 'A carregar…'
                                    : 'Carregar Logótipo'),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'JPEG ou PNG, máx. 5 MB.\nRecomendado: 512 × 512 px.',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),
                    const Divider(),
                    const SizedBox(height: 24),

                    // ----- Name section -----
                    Text(
                      'Dados da Escola',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),
                    Form(
                      key: _formKey,
                      child: TextFormField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nome da Escola *',
                          prefixIcon: Icon(Icons.school_outlined),
                        ),
                        validator: (v) =>
                            v == null || v.trim().isEmpty
                                ? 'Obrigatório'
                                : null,
                      ),
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.danger.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: AppTheme.danger, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: const TextStyle(
                                    color: AppTheme.danger, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _saving ? null : _saveName,
                        child: _saving
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Guardar'),
                      ),
                    ),

                    const SizedBox(height: 48),

                    // ----- Preview -----
                    Text(
                      'Pré-visualização',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    _SidebarPreview(
                      schoolName: school.name,
                      logoUrl: school.logoUrl,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Logo preview widget
// ---------------------------------------------------------------------------
class _LogoPreview extends StatelessWidget {
  final String? logoUrl;
  final bool uploading;

  const _LogoPreview({this.logoUrl, required this.uploading});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (uploading) {
      return const Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white));
    }
    if (logoUrl != null && logoUrl!.isNotEmpty) {
      final full =
          logoUrl!.startsWith('http') ? logoUrl! : '$kMediaBase$logoUrl';
      return CachedNetworkImage(
        imageUrl: full,
        fit: BoxFit.cover,
        width: 90,
        height: 90,
        placeholder: (_, __) => const Center(
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
        errorWidget: (_, __, ___) => const Icon(
            Icons.school_rounded, color: Colors.white, size: 40),
      );
    }
    return const Icon(Icons.school_rounded, color: Colors.white, size: 40);
  }
}

// ---------------------------------------------------------------------------
// Sidebar preview
// ---------------------------------------------------------------------------
class _SidebarPreview extends StatelessWidget {
  final String schoolName;
  final String? logoUrl;

  const _SidebarPreview({required this.schoolName, this.logoUrl});

  @override
  Widget build(BuildContext context) {
    Widget avatar;
    if (logoUrl != null && logoUrl!.isNotEmpty) {
      final full =
          logoUrl!.startsWith('http') ? logoUrl! : '$kMediaBase$logoUrl';
      avatar = ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: CachedNetworkImage(
          imageUrl: full,
          width: 28,
          height: 28,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => _defaultAvatar(),
        ),
      );
    } else {
      avatar = _defaultAvatar();
    }

    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                avatar,
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    schoolName,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Fake nav items
          for (final label in ['Dashboard', 'Crianças', 'Finanças'])
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              child: Row(
                children: [
                  Container(
                      width: 14,
                      height: 14,
                      color: AppTheme.border,
                      margin: const EdgeInsets.only(right: 8)),
                  Text(label,
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textSecondary)),
                ],
              ),
            ),
          const Divider(height: 1),
          // Footer
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Powered by ',
                    style: TextStyle(
                        color: Colors.grey.shade400, fontSize: 9)),
                Text('Cellen',
                    style: TextStyle(
                        color: AppTheme.primary.withOpacity(0.6),
                        fontSize: 9,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _defaultAvatar() => Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: AppTheme.primary,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(Icons.school_rounded, color: Colors.white, size: 14),
      );
}
