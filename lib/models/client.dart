class Client {
  final String? id;
  final String name;
  final String phone;
  final String email;
  final String address;
  final String city;
  final String postalCode;
  final String contactPerson;

  Client({
    this.id,
    required this.name,
    this.phone = '',
    this.email = '',
    this.address = '',
    this.city = '',
    this.postalCode = '',
    this.contactPerson = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'city': city,
      'postalCode': postalCode,
      'contactPerson': contactPerson,
    };
  }

  factory Client.fromMap(Map<String, dynamic> map) {
    return Client(
      id: map['id'] as String?,
      name: map['name'] as String,
      phone: map['phone'] as String? ?? '',
      email: map['email'] as String? ?? '',
      address: map['address'] as String? ?? '',
      city: map['city'] as String? ?? '',
      postalCode: map['postalCode'] as String? ?? '',
      contactPerson: map['contactPerson'] as String? ?? '',
    );
  }

  Client copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? address,
    String? city,
    String? postalCode,
    String? contactPerson,
  }) {
    return Client(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      city: city ?? this.city,
      postalCode: postalCode ?? this.postalCode,
      contactPerson: contactPerson ?? this.contactPerson,
    );
  }
}
