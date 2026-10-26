import 'package:flutter_test/flutter_test.dart';
import 'package:medicare_flutter/services/ocr_service.dart';

void main() {
  group('OCRService Medicine Parser Tests', () {
    final ocrService = OCRService();

    test('Parses Dolo 650 blister pack correctly', () {
      const rawText = """
DOLO 650
Paracetamol Tablets IP 650 mg
Each uncoated tablet contains:
Paracetamol IP 650 mg
Dosage: As directed by the physician.
Take after meals with water.
Mfg. Lic. No.: M/520/2010
Batch No.: DL8392
Mfg. Date: 03/2024
Exp. Date: 12/2026
M.R.P. Rs. 34.00
Micro Labs Limited
""";

      final result = ocrService.parseMedicineText(rawText, language: 'en-US');

      expect(result['name'], 'Dolo 650');
      expect(result['strength'], '650 mg');
      expect(result['form'], 'Tablet');
      expect(result['expiry_date'], '2026-12-31');
      expect(result['instructions'], contains('after meals'));
      expect(result['confidence'], 'high');
      expect(result['spoken_summary'], contains('Dolo 650'));
      expect(result['spoken_summary'], contains('2026'));
    });

    test('Parses Augmentin 625 Duo packaging correctly', () {
      const rawText = """
Augmentin 625 Duo
Amoxycillin and Potassium Clavulanate Tablets IP
Each film coated tablet contains:
Amoxycillin Trihydrate IP eq. to Amoxycillin 500 mg
Potassium Clavulanate Diluted IP eq. to Clavulanic Acid 125 mg
Dosage: As directed by the physician.
Take twice daily.
Keep out of reach of children.
Mfg: 11/2024
Exp: 10/2026
GlaxoSmithKline Pharmaceuticals Ltd.
""";

      final result = ocrService.parseMedicineText(rawText, language: 'en-US');

      expect(result['name'], 'Augmentin 625 Duo');
      expect(result['strength'], '500 mg');
      expect(result['form'], 'Tablet');
      expect(result['expiry_date'], '2026-10-31');
      expect(result['instructions'], contains('twice daily'));
      expect(result['confidence'], 'high');
    });

    test('Parses Pan 40 gastro-resistant tablets correctly', () {
      const rawText = """
PAN 40
Pantoprazole Gastro-resistant Tablets IP
Each tablet contains:
Pantoprazole Sodium IP eq. to Pantoprazole 40 mg
Take on an empty stomach with water.
EXP: 09/2026
MFD: 10/2024
Alkem Laboratories Ltd.
""";

      final result = ocrService.parseMedicineText(rawText, language: 'en-US');

      expect(result['name'], 'Pan 40');
      expect(result['strength'], '40 mg');
      expect(result['form'], 'Tablet');
      expect(result['expiry_date'], '2026-09-30');
      expect(result['instructions'], contains('empty stomach'));
    });

    test('Parses cough syrup bottle with dosage in ml correctly', () {
      const rawText = """
Benadryl Cough Syrup
Diphenhydramine HCl, Ammonium Chloride
Each 5ml contains 14.08 mg
100 ml
Take three times daily
Use before: 08/2026
""";

      final result = ocrService.parseMedicineText(rawText, language: 'en-US');

      expect(result['name'], 'Benadryl');
      expect(result['form'], 'Syrup');
      expect(result['expiry_date'], '2026-08-31');
      expect(result['instructions'], contains('three times'));
    });

    test('Parses multi-language spoken summaries correctly', () {
      const rawText = """
DOLO 650
Paracetamol Tablets IP 650 mg
Exp. Date: 12/2026
Take after meals with water.
""";

      final knResult = ocrService.parseMedicineText(rawText, language: 'kn-IN');
      expect(knResult['spoken_summary'], contains('ನಾನು Dolo 650'));

      final hiResult = ocrService.parseMedicineText(rawText, language: 'hi-IN');
      expect(hiResult['spoken_summary'], contains('मैंने Dolo 650'));
    });

    test('Parses doctor prescription with multiple medicines correctly', () {
      const prescText = """
Dr. R. K. Sharma, MBBS, MD
Senior Consultant Physician
Apollo Hospital
Patient: Ramesh Kumar
Rx:
1. Tab. Dolo 650 - 1-0-1 x 5 days
2. Tab. Pan 40 - 1-0-0 x 14 days
3. Cap. Augmentin 625 Duo - 1-0-1 x 7 days
""";

      final result = ocrService.parsePrescriptionText(prescText, language: 'en-US');

      expect(result['doctor_name'], contains('Dr. R. K. Sharma'));
      final medicines = result['medicines'] as List;
      expect(medicines.length, 3);
      expect(medicines.any((m) => m['name'] == 'Dolo 650'), isTrue);
      expect(medicines.any((m) => m['name'] == 'Pan 40'), isTrue);
      expect(medicines.any((m) => m['name'] == 'Augmentin 625 Duo'), isTrue);
    });

    test('Parses Betadine ointment format correctly', () {
      const rawText = """
Betadine 5% w/w
Povidone-Iodine Ointment USP
For external use only.
Apply gently to the affected area.
Exp: 04/2027
""";

      final result = ocrService.parseMedicineText(rawText, language: 'en-US');

      expect(result['name'], 'Betadine');
      expect(result['strength'], '5% w/w');
      expect(result['form'], 'Cream / Ointment');
      expect(result['expiry_date'], '2027-04-30');
    });

    test('Parses Ciplox Eye/Ear Drops correctly', () {
      const rawText = """
Ciplox Eye Drops
Ciprofloxacin Ophthalmic Solution 0.3% w/v
10 ml
Use before: 09/2026
Instill 1 to 2 drops as advised.
""";

      final result = ocrService.parseMedicineText(rawText, language: 'en-US');

      expect(result['name'], 'Ciplox');
      expect(result['form'], 'Drops');
      expect(result['expiry_date'], '2026-09-30');
      expect(result['dosage'], '1 to 2 drops');
    });

    test('Parses Fever-X 650 (Dr. Morepen Paracetamol 650 mg) blister pack correctly', () {
      const rawText = """
Paracetamol Tablets IP 650 mg
Dr. Morepen
Fever-X 650 फीवर-X 650
Composition:
Each uncoated tablet contains:
Paracetamol IP 650 mg
Dosage: 1 to 2 tablets, 3 to 4 times a day, Minimum dosing interval 4 hours or as directed by the Physician.
Do not exceed the recommended dose, if symptoms persist seek medical advice.
Store protected from light & moisture, at a temperature not exceeding 30°C.
""";

      final result = ocrService.parseMedicineText(rawText, language: 'en-US');

      expect(result['name'], 'Fever-X 650');
      expect(result['strength'], '650 mg');
      expect(result['form'], 'Tablet');
      expect(result['dosage'], '1 to 2 tablets');
      expect(result['instructions'], contains('3 to 4 times'));
      expect(result['spoken_summary'], contains('Fever-X 650'));
    });

    test('Parses Doxinate (Doxylamine Succinate & Pyridoxine Hydrochloride) strip correctly', () {
      const rawText = """
Doxylamine Succinate & Pyridoxine Hydrochloride Tablets
Doxinate®
Each enteric coated tablet contains:
Doxylamine Succinate USP 10 mg
Pyridoxine Hydrochloride IP 10 mg
Appropriate overages of vitamin added
Dosage: As directed by the physician
SCHEDULE H PRESCRIPTION DRUG
Store in a cool dry place away from light
Mfg. Lic. No.: MB/09/747
Maneesh Pharmaceuticals Ltd.
""";

      final result = ocrService.parseMedicineText(rawText, language: 'en-US');

      expect(result['name'], 'Doxinate');
      expect(result['strength'], '10 mg');
      expect(result['form'], 'Tablet');
      expect(result['spoken_summary'], contains('Doxinate'));
    });

    test('Returns clear guidance when text is empty/unreadable without mock data', () {
      final result = ocrService.parseMedicineText("", language: 'en-US');

      expect(result['name'], isEmpty);
      expect(result['confidence'], 'low');
      expect(result['spoken_summary'], contains('Could not read'));
    });

    test('Parses various real-world Indian medicine expiry formats correctly', () {
      final t1 = ocrService.parseMedicineText("Dolo 650 EXP. 15/08/2026");
      expect(t1['expiry_date'], '2026-08-15');

      final t2 = ocrService.parseMedicineText("Pan 40 EXP: 11/2026");
      expect(t2['expiry_date'], '2026-11-30');

      final t3 = ocrService.parseMedicineText("Augmentin 625 Duo EXP. 05 / 2026");
      expect(t3['expiry_date'], '2026-05-31');

      final t4 = ocrService.parseMedicineText("Ciplox EXP: DEC.26");
      expect(t4['expiry_date'], '2026-12-31');

      final t5 = ocrService.parseMedicineText("Cough Syrup USE BEFORE: 04/2027");
      expect(t5['expiry_date'], '2027-04-30');

      final t6 = ocrService.parseMedicineText("Betadine B.No. 401 MFD. 01/24 EXP. 12/26");
      expect(t6['expiry_date'], '2026-12-31');

      final t7 = ocrService.parseMedicineText("Fever-X 650 EXP. DATE: 2026-08");
      expect(t7['expiry_date'], '2026-08-31');
    });
  });
}
