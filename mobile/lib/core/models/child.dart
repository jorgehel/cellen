class Child {
  final String id;
  final String schoolId;
  final String cedula;
  final String firstName;
  final String? middleName;
  final String lastName;
  final DateTime? birthDate;
  final String? placeOfBirth;
  final String? sex;
  final String? nationality;
  final String? naturality;
  final double? height;
  final String? specialNeeds;
  final String? medicalPrescription;
  final String? photoUrl;
  final bool isActive;
  final String? turmaId;
  final String? turmaName;
  // Address
  final String? street;
  final String? houseNumber;
  final String? buildingNumber;
  final String? aptNumber;
  final String? city;
  final String? municipio;
  final String? bairro;
  // Emergency contact
  final String? emergencyContactName;
  final String? emergencyContactPhone;

  const Child({
    required this.id,
    required this.schoolId,
    required this.cedula,
    required this.firstName,
    this.middleName,
    required this.lastName,
    this.birthDate,
    this.placeOfBirth,
    this.sex,
    this.nationality,
    this.naturality,
    this.height,
    this.specialNeeds,
    this.medicalPrescription,
    this.photoUrl,
    required this.isActive,
    this.turmaId,
    this.turmaName,
    this.street,
    this.houseNumber,
    this.buildingNumber,
    this.aptNumber,
    this.city,
    this.municipio,
    this.bairro,
    this.emergencyContactName,
    this.emergencyContactPhone,
  });

  String get fullName =>
      [firstName, middleName, lastName].whereType<String>().join(' ');

  String get sexLabel => sex == 'M' ? 'Masculino' : sex == 'F' ? 'Feminino' : '';

  String? get fullAddress {
    final parts = [street, houseNumber, buildingNumber, aptNumber, bairro, municipio, city]
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .toList();
    return parts.isEmpty ? null : parts.join(', ');
  }

  factory Child.fromJson(Map<String, dynamic> json) {
    return Child(
      id: json['id']?.toString() ?? '',
      schoolId: json['school_id']?.toString() ?? '',
      cedula: json['cedula'] as String? ?? '',
      firstName: json['first_name'] as String? ?? '',
      middleName: json['middle_name'] as String?,
      lastName: json['last_name'] as String? ?? '',
      birthDate: json['birth_date'] != null
          ? DateTime.tryParse(json['birth_date'] as String)
          : null,
      placeOfBirth: json['place_of_birth'] as String?,
      sex: json['sex'] as String?,
      nationality: json['nationality'] as String?,
      naturality: json['naturality'] as String?,
      height: json['height'] != null
          ? (json['height'] is num
              ? (json['height'] as num).toDouble()
              : double.tryParse(json['height'].toString()))
          : null,
      specialNeeds: json['special_needs'] as String?,
      medicalPrescription: json['medical_prescription'] as String?,
      photoUrl: json['photo_url'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      turmaId: json['turma_id']?.toString(),
      turmaName: json['turma_name'] as String?,
      street: json['street'] as String?,
      houseNumber: json['house_number'] as String?,
      buildingNumber: json['building_number'] as String?,
      aptNumber: json['apt_number'] as String?,
      city: json['city'] as String?,
      municipio: json['municipio'] as String?,
      bairro: json['bairro'] as String?,
      emergencyContactName: json['emergency_contact_name'] as String?,
      emergencyContactPhone: json['emergency_contact_phone'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'school_id': schoolId,
        'cedula': cedula,
        'first_name': firstName,
        if (middleName != null) 'middle_name': middleName,
        'last_name': lastName,
        if (birthDate != null)
          'birth_date':
              '${birthDate!.year.toString().padLeft(4, '0')}-${birthDate!.month.toString().padLeft(2, '0')}-${birthDate!.day.toString().padLeft(2, '0')}',
        if (placeOfBirth != null) 'place_of_birth': placeOfBirth,
        if (sex != null) 'sex': sex,
        if (nationality != null) 'nationality': nationality,
        if (naturality != null) 'naturality': naturality,
        if (height != null) 'height': height,
        if (specialNeeds != null) 'special_needs': specialNeeds,
        if (medicalPrescription != null) 'medical_prescription': medicalPrescription,
        if (photoUrl != null) 'photo_url': photoUrl,
        'is_active': isActive,
        if (turmaId != null) 'turma_id': turmaId,
        if (street != null) 'street': street,
        if (houseNumber != null) 'house_number': houseNumber,
        if (buildingNumber != null) 'building_number': buildingNumber,
        if (aptNumber != null) 'apt_number': aptNumber,
        if (city != null) 'city': city,
        if (municipio != null) 'municipio': municipio,
        if (bairro != null) 'bairro': bairro,
        if (emergencyContactName != null) 'emergency_contact_name': emergencyContactName,
        if (emergencyContactPhone != null) 'emergency_contact_phone': emergencyContactPhone,
      };
}
