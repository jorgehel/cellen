class WebsiteSetting {
  final String id;
  final String key;
  final Map<String, dynamic> value;
  final String? updatedAt;

  const WebsiteSetting({
    required this.id,
    required this.key,
    required this.value,
    this.updatedAt,
  });

  factory WebsiteSetting.fromJson(Map<String, dynamic> json) {
    return WebsiteSetting(
      id: json['id']?.toString() ?? '',
      key: json['key'] as String? ?? '',
      value: (json['value'] as Map<String, dynamic>?) ?? {},
      updatedAt: json['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'key': key,
        'value': value,
        'updated_at': updatedAt,
      };
}

class WebsitePage {
  final String id;
  final String slug;
  final String title;
  final String? metaDescription;
  final bool isPublished;
  final int sortOrder;
  final String? createdAt;
  final String? updatedAt;
  final List<WebsiteSection> sections;

  const WebsitePage({
    required this.id,
    required this.slug,
    required this.title,
    this.metaDescription,
    required this.isPublished,
    required this.sortOrder,
    this.createdAt,
    this.updatedAt,
    this.sections = const [],
  });

  factory WebsitePage.fromJson(Map<String, dynamic> json) {
    return WebsitePage(
      id: json['id']?.toString() ?? '',
      slug: json['slug'] as String? ?? '',
      title: json['title'] as String? ?? '',
      metaDescription: json['meta_description'] as String?,
      isPublished: json['is_published'] as bool? ?? false,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
      sections: (json['sections'] as List<dynamic>?)
              ?.map((e) => WebsiteSection.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'slug': slug,
        'title': title,
        'meta_description': metaDescription,
        'is_published': isPublished,
        'sort_order': sortOrder,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };
}

class WebsiteSection {
  final String id;
  final String pageId;
  final String sectionType;
  final String name;
  final Map<String, dynamic> content;
  final Map<String, dynamic> settings;
  final int sortOrder;
  final bool isVisible;
  final String? createdAt;
  final String? updatedAt;

  const WebsiteSection({
    required this.id,
    required this.pageId,
    required this.sectionType,
    required this.name,
    required this.content,
    required this.settings,
    required this.sortOrder,
    required this.isVisible,
    this.createdAt,
    this.updatedAt,
  });

  factory WebsiteSection.fromJson(Map<String, dynamic> json) {
    return WebsiteSection(
      id: json['id']?.toString() ?? '',
      pageId: json['page_id']?.toString() ?? '',
      sectionType: json['section_type'] as String? ?? '',
      name: json['name'] as String? ?? '',
      content: (json['content'] as Map<String, dynamic>?) ?? {},
      settings: (json['settings'] as Map<String, dynamic>?) ?? {},
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      isVisible: json['is_visible'] as bool? ?? true,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'page_id': pageId,
        'section_type': sectionType,
        'name': name,
        'content': content,
        'settings': settings,
        'sort_order': sortOrder,
        'is_visible': isVisible,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };
}

class WebsiteMedia {
  final String id;
  final String filename;
  final String url;
  final String? altText;
  final String category;
  final int? fileSize;
  final String? contentType;
  final String? createdAt;

  const WebsiteMedia({
    required this.id,
    required this.filename,
    required this.url,
    this.altText,
    required this.category,
    this.fileSize,
    this.contentType,
    this.createdAt,
  });

  factory WebsiteMedia.fromJson(Map<String, dynamic> json) {
    return WebsiteMedia(
      id: json['id']?.toString() ?? '',
      filename: json['filename'] as String? ?? '',
      url: json['url'] as String? ?? '',
      altText: json['alt_text'] as String?,
      category: json['category'] as String? ?? 'general',
      fileSize: (json['file_size'] as num?)?.toInt(),
      contentType: json['content_type'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'filename': filename,
        'url': url,
        'alt_text': altText,
        'category': category,
        'file_size': fileSize,
        'content_type': contentType,
        'created_at': createdAt,
      };
}
