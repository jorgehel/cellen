import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/models/website.dart';

class WebsiteSectionEditorScreen extends ConsumerStatefulWidget {
  final String sectionId;
  final String pageId;

  const WebsiteSectionEditorScreen({
    super.key,
    required this.sectionId,
    required this.pageId,
  });

  @override
  ConsumerState<WebsiteSectionEditorScreen> createState() =>
      _WebsiteSectionEditorScreenState();
}

class _WebsiteSectionEditorScreenState
    extends ConsumerState<WebsiteSectionEditorScreen> {
  WebsiteSection? _section;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  late TextEditingController _nameCtrl;
  final List<_FieldController> _contentFields = [];
  final List<_FieldController> _settingsFields = [];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    for (final f in _contentFields) {
      f.controller.dispose();
    }
    for (final f in _settingsFields) {
      f.controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.get('/website/admin/sections/${widget.sectionId}');
      final section = WebsiteSection.fromJson(data as Map<String, dynamic>);
      setState(() {
        _section = section;
        _loading = false;
      });
      _buildForm();
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  void _buildForm() {
    _nameCtrl.text = _section!.name;

    // Dispose old controllers
    for (final f in _contentFields) {
      f.controller.dispose();
    }
    for (final f in _settingsFields) {
      f.controller.dispose();
    }
    _contentFields.clear();
    _settingsFields.clear();

    // Build content fields based on section type
    final content = Map<String, dynamic>.from(_section!.content);
    final settings = Map<String, dynamic>.from(_section!.settings);

    switch (_section!.sectionType) {
      case 'hero':
        _addContentField('badge', 'Badge', content['badge']?.toString() ?? '');
        _addContentField('title', 'Título', content['title']?.toString() ?? '');
        _addContentField('subtitle', 'Subtítulo', content['subtitle']?.toString() ?? '');
        _addContentField('cta_primary_text', 'CTA Primário (texto)',
            content['cta_primary']?['text']?.toString() ?? '');
        _addContentField('cta_primary_link', 'CTA Primário (link)',
            content['cta_primary']?['link']?.toString() ?? '');
        _addContentField('cta_secondary_text', 'CTA Secundário (texto)',
            content['cta_secondary']?['text']?.toString() ?? '');
        _addContentField('cta_secondary_link', 'CTA Secundário (link)',
            content['cta_secondary']?['link']?.toString() ?? '');
        _addSettingsField('background', 'Fundo', settings['background']?.toString() ?? '');
        break;

      case 'features':
        _addContentField('title', 'Título', content['title']?.toString() ?? '');
        _addContentField('subtitle', 'Subtítulo', content['subtitle']?.toString() ?? '');
        _addSettingsField('background', 'Fundo (gray ou vazio)', settings['background']?.toString() ?? '');
        _addContentField('items_json', 'Itens (JSON)', _formatJson(content['items']));
        break;

      case 'steps':
        _addContentField('title', 'Título', content['title']?.toString() ?? '');
        _addContentField('subtitle', 'Subtítulo', content['subtitle']?.toString() ?? '');
        _addContentField('items_json', 'Itens (JSON)', _formatJson(content['items']));
        break;

      case 'benefits':
        _addContentField('title', 'Título', content['title']?.toString() ?? '');
        _addContentField('subtitle', 'Subtítulo', content['subtitle']?.toString() ?? '');
        _addContentField('metrics_title', 'Título métricas', content['metrics_title']?.toString() ?? '');
        _addContentField('metrics_subtitle', 'Subtítulo métricas', content['metrics_subtitle']?.toString() ?? '');
        _addContentField('items_json', 'Itens (JSON)', _formatJson(content['items']));
        _addContentField('metrics_json', 'Métricas (JSON)', _formatJson(content['metrics']));
        _addSettingsField('background', 'Fundo', settings['background']?.toString() ?? '');
        break;

      case 'pricing':
        _addContentField('title', 'Título', content['title']?.toString() ?? '');
        _addContentField('subtitle', 'Subtítulo', content['subtitle']?.toString() ?? '');
        _addContentField('plans_json', 'Planos (JSON)', _formatJson(content['plans']));
        break;

      case 'contact':
        _addContentField('title', 'Título', content['title']?.toString() ?? '');
        _addContentField('subtitle', 'Subtítulo', content['subtitle']?.toString() ?? '');
        _addContentField('submit_text', 'Texto do botão', content['submit_text']?.toString() ?? '');
        _addContentField('form_fields_json', 'Campos (JSON)', _formatJson(content['form_fields']));
        _addSettingsField('background', 'Fundo', settings['background']?.toString() ?? '');
        break;

      default:
        _addContentField('content_json', 'Conteúdo (JSON)', _formatJson(content));
        _addSettingsField('settings_json', 'Configurações (JSON)', _formatJson(settings));
    }

    setState(() {});
  }

  void _addContentField(String key, String label, String value) {
    final ctrl = TextEditingController(text: value);
    _contentFields.add(_FieldController(key: key, label: label, controller: ctrl));
  }

  void _addSettingsField(String key, String label, String value) {
    final ctrl = TextEditingController(text: value);
    _settingsFields.add(_FieldController(key: key, label: label, controller: ctrl));
  }

  String _formatJson(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    return _prettyJson(value);
  }

  String _prettyJson(dynamic obj) {
    return const JsonEncoder.withIndent('  ').convert(obj);
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    // Build content map from form fields
    final content = <String, dynamic>{};
    for (final f in _contentFields) {
      final key = f.key;
      final text = f.controller.text.trim();
      if (text.isEmpty) continue;

      if (key.endsWith('_json')) {
        // Parse JSON fields
        try {
          content[key.replaceAll('_json', '')] = const JsonDecoder().convert(text);
        } catch (_) {
          setState(() {
            _error = 'JSON inválido em "${f.label}"';
            _saving = false;
          });
          return;
        }
      } else if (key.startsWith('cta_primary_')) {
        final cta = (content['cta_primary'] as Map<String, dynamic>?) ?? {};
        cta[key.replaceAll('cta_primary_', '')] = text;
        content['cta_primary'] = cta;
      } else if (key.startsWith('cta_secondary_')) {
        final cta = (content['cta_secondary'] as Map<String, dynamic>?) ?? {};
        cta[key.replaceAll('cta_secondary_', '')] = text;
        content['cta_secondary'] = cta;
      } else {
        content[key] = text;
      }
    }

    final settings = <String, dynamic>{};
    for (final f in _settingsFields) {
      final key = f.key;
      final text = f.controller.text.trim();
      if (text.isEmpty) continue;

      if (key.endsWith('_json')) {
        try {
          settings[key.replaceAll('_json', '')] = const JsonDecoder().convert(text);
        } catch (_) {
          setState(() {
            _error = 'JSON inválido em "${f.label}"';
            _saving = false;
          });
          return;
        }
      } else {
        settings[key] = text;
      }
    }

    try {
      final api = ref.read(apiClientProvider);
      await api.patch('/website/admin/sections/${widget.sectionId}', data: {
        'name': _nameCtrl.text.trim(),
        'content': content,
        'settings': settings,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Secção guardada')),
        );
        Navigator.pop(context);
      }
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_section?.name ?? 'Editar secção'),
        actions: [
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Guardar'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _section == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      TextButton(
                        onPressed: _load,
                        child: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                )
              : _section == null
                  ? const Center(child: Text('Secção não encontrada'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_error != null)
                            Card(
                              color: Theme.of(context).colorScheme.errorContainer,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(_error!,
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onErrorContainer)),
                              ),
                            ),
                          // Section info
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Tipo: ${_section!.sectionType}',
                                    style: Theme.of(context).textTheme.labelLarge,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Text('Visível: '),
                                      Switch(
                                        value: _section!.isVisible,
                                        onChanged: _toggleVisible,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Name
                          TextField(
                            controller: _nameCtrl,
                            decoration: const InputDecoration(labelText: 'Nome da secção'),
                          ),
                          const SizedBox(height: 16),
                          // Content fields
                          Text('Conteúdo',
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          ..._contentFields.map(_buildField),
                          if (_settingsFields.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Text('Configurações',
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 8),
                            ..._settingsFields.map(_buildField),
                          ],
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildField(_FieldController f) {
    final isJson = f.key.endsWith('_json');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: f.controller,
        decoration: InputDecoration(
          labelText: f.label,
          alignLabelWithHint: isJson,
        ),
        maxLines: isJson ? 8 : 1,
        style: isJson
            ? const TextStyle(fontFamily: 'monospace', fontSize: 12)
            : null,
      ),
    );
  }

  Future<void> _toggleVisible(bool value) async {
    try {
      final api = ref.read(apiClientProvider);
      await api.patch('/website/admin/sections/${widget.sectionId}', data: {
        'is_visible': value,
      });
      setState(() {
        _section = WebsiteSection(
          id: _section!.id,
          pageId: _section!.pageId,
          sectionType: _section!.sectionType,
          name: _section!.name,
          content: _section!.content,
          settings: _section!.settings,
          sortOrder: _section!.sortOrder,
          isVisible: value,
          createdAt: _section!.createdAt,
          updatedAt: _section!.updatedAt,
        );
      });
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }
}

class _FieldController {
  final String key;
  final String label;
  final TextEditingController controller;

  const _FieldController({
    required this.key,
    required this.label,
    required this.controller,
  });
}
