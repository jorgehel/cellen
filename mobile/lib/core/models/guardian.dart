class Guardian {
  final String id;
  final String childId;
  final String firstName;
  final String? middleName;
  final String lastName;
  final String relationship;
  final DateTime? birthDate;
  final String? placeOfBirth;
  final String? sex;
  final String? civilState;
  final String? nationality;
  final String? naturality;
  final String? nif;
  final String? idCardNumber;
  final String? profession;
  final String? qualifications;
  final String? photoUrl;
  // Address
  final String? street;
  final String? houseNumber;
  final String? buildingNumber;
  final String? aptNumber;
  final String? city;
  final String? municipio;
  final String? bairro;
  // Contacts
  final String? mobileFirst;
  final String? mobileSecond;
  final String? email;
  final bool isPrimary;
  final bool authorizedPickup;

  const Guardian({
    required this.id,
    required this.childId,
    required this.firstName,
    this.middleName,
    required this.lastName,
    required this.relationship,
    this.birthDate,
    this.placeOfBirth,
    this.sex,
    this.civilState,
    this.nationality,
    this.naturality,
    this.nif,
    this.idCardNumber,
    this.profession,
    this.qualifications,
    this.photoUrl,
    this.street,
    this.houseNumber,
    this.buildingNumber,
    this.aptNumber,
    this.city,
    this.municipio,
    this.bairro,
    this.mobileFirst,
    this.mobileSecond,
    this.email,
    required this.isPrimary,
    required this.authorizedPickup,
  });

  String get fullName =>
      [firstName, middleName, lastName].whereType<String>().join(' ');

  String get relationshipLabel {
    switch (relationship) {
      case 'mother':
        return 'Mãe';
      case 'father':
        return 'Pai';
      case 'grandparent':
        return 'Avó/Avô';
      case 'legal_guardian':
        return 'Tutor(a) Legal';
      case 'sibling':
        return 'Irmão/Irmã';
      case 'other':
        return 'Outro';
      default:
        return relationship;
    }
  }

  // Convenience getters for backward-compat
  String? get phone => mobileFirst;
  String? get cedula => idCardNumber;

  String? get fullAddress {
    final parts = [street, houseNumber, buildingNumber, aptNumber, bairro, municipio, city]
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .toList();
    return parts.isEmpty ? null : parts.join(', ');
  }

  factory Guardian.fromJson(Map<String, dynamic> json) {
    return Guardian(
      id: json['id']?.toString() ?? '',
      childId: json['child_id']?.toString() ?? '',
      firstName: json['first_name'] as String? ?? '',
      middleName: json['middle_name'] as String?,
      lastName: json['last_name'] as String? ?? '',
      relationship: json['relationship_type'] as String? ?? json['relationship'] as String? ?? '',
      birthDate: json['birth_date'] != null
          ? DateTime.tryParse(json['birth_date'] as String)
          : null,
      placeOfBirth: json['place_of_birth'] as String?,
      sex: json['sex'] as String?,
      civilState: json['civil_state'] as String?,
      nationality: json['nationality'] as String?,
      naturality: json['naturality'] as String?,
      nif: json['nif'] as String?,
      idCardNumber: json['id_card_number'] as String?,
      profession: json['profession'] as String?,
      qualifications: json['qualifications'] as String?,
      photoUrl: json['photo_url'] as String?,
      street: json['street'] as String?,
      houseNumber: json['house_number'] as String?,
      buildingNumber: json['building_number'] as String?,
      aptNumber: json['apt_number'] as String?,
      city: json['city'] as String?,
      municipio: json['municipio'] as String?,
      bairro: json['bairro'] as String?,
      mobileFirst: json['mobile_first'] as String? ?? json['phone'] as String?,
      mobileSecond: json['mobile_second'] as String?,
      email: json['email'] as String?,
      isPrimary: json['is_primary_contact'] as bool? ?? json['is_primary'] as bool? ?? false,
      authorizedPickup: json['authorized_pickup'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'child_id': childId,
        'first_name': firstName,
        if (middleName != null) 'middle_name': middleName,
        'last_name': lastName,
        'relationship_type': relationship,
        if (birthDate != null) 'birth_date': birthDate!.toIso8601String().substring(0, 10),
        if (placeOfBirth != null) 'place_of_birth': placeOfBirth,
        if (sex != null) 'sex': sex,
        if (civilState != null) 'civil_state': civilState,
        if (nationality != null) 'nationality': nationality,
        if (naturality != null) 'naturality': naturality,
        if (nif != null) 'nif': nif,
        if (idCardNumber != null) 'id_card_number': idCardNumber,
        if (profession != null) 'profession': profession,
        if (qualifications != null) 'qualifications': qualifications,
        if (photoUrl != null) 'photo_url': photoUrl,
        if (street != null) 'street': street,
        if (houseNumber != null) 'house_number': houseNumber,
        if (buildingNumber != null) 'building_number': buildingNumber,
        if (aptNumber != null) 'apt_number': aptNumber,
        if (city != null) 'city': city,
        if (municipio != null) 'municipio': municipio,
        if (bairro != null) 'bairro': bairro,
        if (mobileFirst != null) 'mobile_first': mobileFirst,
        if (mobileSecond != null) 'mobile_second': mobileSecond,
        if (email != null) 'email': email,
        'is_primary_contact': isPrimary,
        'authorized_pickup': authorizedPickup,
      };
}
