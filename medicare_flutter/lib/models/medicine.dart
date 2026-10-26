class Medicine {
  final String id;
  final String name;
  final String? dosage;
  final String? form;
  final String? strength;
  final String? expiryDate;
  final String? instructions;
  final String? photoUrl;
  final String? scannedText;
  final String? notes;

  Medicine({
    required this.id,
    required this.name,
    this.dosage,
    this.form,
    this.strength,
    this.expiryDate,
    this.instructions,
    this.photoUrl,
    this.scannedText,
    this.notes,
  });

  factory Medicine.fromJson(Map<String, dynamic> json) {
    return Medicine(
      id: json['id'],
      name: json['name'],
      dosage: json['dosage'],
      form: json['form'],
      strength: json['strength'],
      expiryDate: json['expiry_date'],
      instructions: json['instructions'],
      photoUrl: json['photo_url'],
      scannedText: json['scanned_text'],
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'dosage': dosage,
      'form': form,
      'strength': strength,
      'expiry_date': expiryDate,
      'instructions': instructions,
      'photo_url': photoUrl,
      'scanned_text': scannedText,
      'notes': notes,
    };
  }
}
