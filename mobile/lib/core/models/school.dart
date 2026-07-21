class School {
  final String id;
  final String name;
  final String slug;
  final String? address;
  final String? phone;
  final String? email;
  final String? logoUrl;
  final String currency;
  final bool isActive;
  final bool waEnabled;
  final String? waPhoneNumberId;

  const School({
    required this.id,
    required this.name,
    required this.slug,
    this.address,
    this.phone,
    this.email,
    this.logoUrl,
    this.currency = 'AOA',
    required this.isActive,
    this.waEnabled = false,
    this.waPhoneNumberId,
  });

  factory School.fromJson(Map<String, dynamic> json) {
    return School(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      logoUrl: json['logo_url'] as String?,
      currency: json['currency'] as String? ?? 'AOA',
      isActive: json['is_active'] as bool? ?? true,
      waEnabled: json['wa_enabled'] as bool? ?? false,
      waPhoneNumberId: json['wa_phone_number_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slug': slug,
        if (address != null) 'address': address,
        if (phone != null) 'phone': phone,
        if (email != null) 'email': email,
        if (logoUrl != null) 'logo_url': logoUrl,
        'currency': currency,
        'is_active': isActive,
      };
}
