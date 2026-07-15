class WebsiteSetting {
  final String id;
  final String schoolId;
  final String key;
  final dynamic value;
  final DateTime createdAt;
  final DateTime updatedAt;

  const WebsiteSetting({
    required this.id,
    required this.schoolId,
    required this.key,
    required this.value,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WebsiteSetting.fromJson(Map<String, dynamic> json) => WebsiteSetting(
        id: json['id']?.toString() ?? '',
        schoolId: json['school_id']?.toString() ?? '',
        key: json['key'] as String? ?? '',
        value: json['value'],
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'school_id': schoolId,
        'key': key,
        'value': value,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

class WebsitePage {
  final String id;
  final String schoolId;
  final String slug;
  final String title;
  final bool isPublished;
  final String? metaDescription;
  final List<WebsiteSection>? sections;
  final DateTime createdAt;
  final DateTime updatedAt;

  const WebsitePage({
    required this.id,
    required this.schoolId,
    required this.slug,
    required this.title,
    required this.isPublished,
    this.metaDescription,
    this.sections,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WebsitePage.fromJson(Map<String, dynamic> json) => WebsitePage(
        id: json['id']?.toString() ?? '',
        schoolId: json['school_id']?.toString() ?? '',
        slug: json['slug'] as String? ?? '',
        title: json['title'] as String? ?? '',
        isPublished: json['is_published'] as bool? ?? false,
        metaDescription: json['meta_description'] as String?,
        sections: json['sections'] != null
            ? (json['sections'] as List)
                .map((e) => WebsiteSection.fromJson(e as Map<String, dynamic>))
                .toList()
            : null,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'school_id': schoolId,
        'slug': slug,
        'title': title,
        'is_published': isPublished,
        'meta_description': metaDescription,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

class WebsiteSection {
  final String id;
  final String pageId;
  final String schoolId;
  final String sectionType;
  final int order;
  final Map<String, dynamic> content;
  final Map<String, dynamic>? settings;
  final DateTime createdAt;
  final DateTime updatedAt;

  const WebsiteSection({
    required this.id,
    required this.pageId,
    required this.schoolId,
    required this.sectionType,
    required this.order,
    required this.content,
    this.settings,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WebsiteSection.fromJson(Map<String, dynamic> json) => WebsiteSection(
        id: json['id']?.toString() ?? '',
        pageId: json['page_id']?.toString() ?? '',
        schoolId: json['school_id']?.toString() ?? '',
        sectionType: json['section_type'] as String? ?? '',
        order: json['order'] as int? ?? 0,
        content: json['content'] as Map<String, dynamic>? ?? {},
        settings: json['settings'] as Map<String, dynamic>?,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'page_id': pageId,
        'school_id': schoolId,
        'section_type': sectionType,
        'order': order,
        'content': content,
        'settings': settings,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

class WebsiteMedia {
  final String id;
  final String schoolId;
  final String filename;
  final String url;
  final String? contentType;
  final int? sizeBytes;
  final String? altText;
  final DateTime createdAt;

  const WebsiteMedia({
    required this.id,
    required this.schoolId,
    required this.filename,
    required this.url,
    this.contentType,
    this.sizeBytes,
    this.altText,
    required this.createdAt,
  });

  factory WebsiteMedia.fromJson(Map<String, dynamic> json) => WebsiteMedia(
        id: json['id']?.toString() ?? '',
        schoolId: json['school_id']?.toString() ?? '',
        filename: json['filename'] as String? ?? '',
        url: json['url'] as String? ?? '',
        contentType: json['content_type'] as String?,
        sizeBytes: json['size_bytes'] as int?,
        altText: json['alt_text'] as String?,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'school_id': schoolId,
        'filename': filename,
        'url': url,
        'content_type': contentType,
        'size_bytes': sizeBytes,
        'alt_text': altText,
        'created_at': createdAt.toIso8601String(),
      };
}
