import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OCRService {
  static final OCRService _instance = OCRService._internal();
  factory OCRService() => _instance;
  OCRService._internal();

  /// Known common medicines & active pharmaceutical ingredients (brand and generic)
  static final List<String> _knownMedicines = [
    // Pain, Fever & Inflammation
    "Fever-X 650", "Fever-X", "Paracetamol", "Dolo 650", "Dolo", "Crocin 650", "Crocin Advance", "Crocin", 
    "Calpol 650", "Calpol 500", "Calpol", "Ibuprofen", "Combiflam", "Brufen", 
    "Aspirin", "Disprin", "Diclofenac", "Voveran", "Aceclofenac", "Zerodol-SP", 
    "Zerodol-P", "Zerodol", "Tramadol", "Ultracet", "Mefenamic Acid", "Meftal-Spas", 
    "Meftal", "Naproxen", "Piroxicam", "Ketorolac", "Nimesulide", "Morepen",
    
    // Nausea, Pregnancy, Anti-emetic & Vitamins
    "Doxinate", "Doxylamine Succinate & Pyridoxine Hydrochloride", "Doxylamine Succinate", 
    "Pyridoxine Hydrochloride", "Doxylamine", "Pyridoxine", "Pregnidoxin", "Vomikind", 
    "Perinorm", "Metoclopramide",
    
    // Antibiotics & Antivirals & Antifungals
    "Amoxicillin and Potassium Clavulanate", "Amoxicillin", "Amoxyclav", "Augmentin 625 Duo", 
    "Augmentin 625", "Augmentin", "Moxikind-CV", "Azithromycin", "Azithral 500", "Azithral", 
    "Azee 500", "Azee", "Cefixime", "Taxim-O", "Mahacef", "Ciprofloxacin", "Ciplox", 
    "Ofloxacin", "Oflox", "Levofloxacin", "Levomac", "Metronidazole", "Flagyl", 
    "Doxycycline", "Doxt-SL", "Acyclovir", "Cephalexin", "Sporidex", "Clindamycin", 
    "Clavam 625", "Bactrim", "Norfloxacin", "Norflox-TZ",
    
    // Diabetes
    "Metformin Hydrochloride", "Metformin HCl", "Metformin", "Glycomet-GP", "Glycomet 500", 
    "Glycomet", "Glimepiride", "Amaryl", "Gliclazide", "Sitagliptin", "Januvia", 
    "Vildagliptin", "Galvus", "Teneligliptin", "Dapagliflozin", "Forxiga", "Empagliflozin", 
    "Jardiance", "Insulin", "Glipizide", "Voglibose", "Pioglitazone",
    
    // Hypertension & Cardiac
    "Telmisartan", "Telma 40", "Telma-H", "Telma", "Telmikind 40", "Telmikind", 
    "Amlodipine", "Amlong 5", "Amlong", "Atenolol", "Aten 50", "Aten", "Losartan", 
    "Losar 50", "Losar", "Ramipril", "Cardace", "Enalapril", "Atorvastatin", "Atorva 20", 
    "Atorva 10", "Atorva", "Lipitor", "Rosuvastatin", "Rosuvas 10", "Rosuvas", 
    "Clopidogrel", "Clopilet", "Nebivolol", "Concor", "Bisoprolol", "Metoprolol", 
    "Betaloc", "Ecosprin 75", "Ecosprin 150", "Ecosprin",
    
    // Gastrointestinal & Antacids
    "Pantoprazole Sodium", "Pantoprazole Gastro-resistant", "Pantoprazole", "Pan 40", 
    "Pan-D", "Pantocid 40", "Pantocid", "Omeprazole", "Omez 20", "Omez-D", "Omez", 
    "Rabeprazole", "Razo 20", "Rablet 20", "Razo", "Esomeprazole", "Nexpro 40", 
    "Nexpro", "Ranitidine", "Zinetac", "Famotidine", "Domperidone", "Ondansetron", 
    "Emeset 4", "Emeset", "Digene", "Gelusil", "Cremaffin", "Duphalac", "Lactulose", 
    "Sucralfate", "Gerd-M", "Spasmo-Proxyvon",
    
    // Allergy, Respiratory & Cold
    "Cetirizine Hydrochloride", "Cetirizine", "Cetzine", "Alerid", "Levocetirizine", 
    "Levocet", "Montelukast Sodium", "Montelukast", "Montair-LC", "Montek-LC", 
    "Fexofenadine", "Allegra 120", "Allegra", "Chlorpheniramine Maleate", "Chlorpheniramine", 
    "Diphenhydramine", "Benadryl", "Dextromethorphan", "Ambroxol", "Guaifenesin", 
    "Ascoril-D", "Ascoril-LS", "Ascoril", "Grilinctus", "Asthalin", "Salbutamol", 
    "Budecort", "Budesonide", "Foracort", "Deriphyllin", "Cheston Cold", "Sinarest", 
    "Wikoryl", "Maxtra", "Alex", "Chericof",
    
    // Vitamins, Minerals & Supplements
    "Calcium Carbonate", "Calcium and Vitamin D3", "Calcium", "Shelcal 500", "Shelcal", 
    "Calcirol", "Vitamin D3", "Vitamin C", "Limcee 500", "Limcee", "Celin 500", "Celin", 
    "Vitamin B-Complex", "Becosules Z", "Becosules", "Neurobion Forte", "Neurobion", 
    "Methylcobalamin", "Cobadex CZS", "Folic Acid", "Folvite", "Zincovit", "Supradyn", 
    "Iron and Folic Acid", "Autrin", "Orofer-XT", "Livogen", "Evion 400", "Evion",
    
    // Topical & Dermatology
    "Povidone-Iodine", "Betadine", "Neosporin", "Soframycin", "Silverex", "Mupirocin", 
    "T-Bact", "Clotrimazole", "Candid", "Fluconazole", "Diflucan", "Itraconazole", 
    "Candiforce 200", "Ketoconazole", "Permethrin", "Burnol", "Volini", "Moov",
    
    // Steroids & Anti-inflammatory
    "Prednisolone", "Wysolone", "Dexamethasone", "Dexona", "Methylprednisolone", 
    "Medrol", "Deflazacort", "Defcort", "Hydrocortisone",
  ];

  /// Set of proprietary brand names (prioritized over generic ingredients)
  static final Set<String> _brandMedicines = {
    "Fever-X 650", "Fever-X", "Doxinate", "Dolo 650", "Dolo", "Crocin 650", "Crocin Advance", 
    "Crocin", "Calpol 650", "Calpol 500", "Calpol", "Pan 40", "Pan-D", "Pantocid 40", 
    "Pantocid", "Augmentin 625 Duo", "Augmentin 625", "Augmentin", "Moxikind-CV", "Omez 20", 
    "Omez-D", "Omez", "Cetzine", "Allegra 120", "Allegra", "Combiflam", "Brufen", "Disprin", 
    "Voveran", "Zerodol-SP", "Zerodol-P", "Zerodol", "Ultracet", "Meftal-Spas", "Meftal", 
    "Azithral 500", "Azithral", "Azee 500", "Azee", "Taxim-O", "Mahacef", "Ciplox", "Oflox", 
    "Levomac", "Flagyl", "Doxt-SL", "Sporidex", "Clavam 625", "Bactrim", "Norflox-TZ", 
    "Glycomet-GP", "Glycomet 500", "Glycomet", "Amaryl", "Januvia", "Galvus", "Forxiga", 
    "Jardiance", "Telma 40", "Telma-H", "Telma", "Telmikind 40", "Telmikind", "Amlong 5", 
    "Amlong", "Aten 50", "Aten", "Losar 50", "Losar", "Cardace", "Atorva 20", "Atorva 10", 
    "Atorva", "Lipitor", "Rosuvas 10", "Rosuvas", "Clopilet", "Concor", "Betaloc", "Ecosprin 75", 
    "Ecosprin 150", "Ecosprin", "Razo 20", "Rablet 20", "Razo", "Nexpro 40", "Nexpro", 
    "Zinetac", "Emeset 4", "Emeset", "Digene", "Gelusil", "Cremaffin", "Duphalac", "Alerid", 
    "Levocet", "Montair-LC", "Montek-LC", "Ascoril-D", "Ascoril-LS", "Ascoril", "Grilinctus", 
    "Asthalin", "Budecort", "Foracort", "Deriphyllin", "Cheston Cold", "Sinarest", "Wikoryl", 
    "Alex", "Chericof", "Shelcal 500", "Shelcal", "Calcirol", "Limcee 500", "Limcee", 
    "Celin 500", "Celin", "Becosules Z", "Becosules", "Neurobion Forte", "Neurobion", 
    "Folvite", "Zincovit", "Supradyn", "Autrin", "Orofer-XT", "Livogen", "Evion 400", "Evion", 
    "Betadine", "Neosporin", "Soframycin", "Silverex", "T-Bact", "Candid", "Diflucan", 
    "Candiforce 200", "Burnol", "Volini", "Moov", "Wysolone", "Dexona", "Medrol", "Defcort",
    "Pregnidoxin", "Vomikind", "Perinorm", "Morepen"
  };

  /// Common pharmaceutical labels and boilerplate to filter out
  static final List<String> _boilerplateLines = [
    "mfg. lic.", "mfg lic", "licence no", "license no", "batch no", "b.no", "lot no",
    "m.r.p.", "mrp rs", "incl. of all taxes", "store below", "store in a cool",
    "protect from light", "protect from moisture", "keep out of reach of children",
    "keep medicine out of", "schedule h prescription", "schedule h1", "warning: to be sold",
    "caution: not to be sold", "dosage: as directed", "as directed by the physician",
    "marketed by", "manufactured by", "mfg by", "pkg by", "for external use only",
    "not for injection", "shake well before use", "each uncoated tablet contains",
    "each film coated tablet contains", "each capsule contains", "each 5ml contains",
    "excipients q.s.", "colour:", "color:", "titanium dioxide", "sunset yellow",
    "pharmaceuticals ltd", "laboratories ltd", "pvt. ltd.", "india limited"
  ];

  /// Clinical database mapping medicines to active ingredients (composition) and therapeutic indications (purpose)
  static final Map<String, Map<String, String>> _medicineDatabase = {
    // Pain, Fever & Inflammation
    "dolo650": {
      "composition": "Paracetamol IP (650 mg)",
      "purpose": "Fever, headache, and body pain relief",
      "knPurpose": "ಜ್ವರ, ತಲೆನೋವು ಮತ್ತು ಮೈ-ಕೈ ನೋವು ನಿವಾರಣೆ",
      "hiPurpose": "बुखार, सिरदर्द और बदन दर्द से राहत",
    },
    "dolo": {
      "composition": "Paracetamol IP (650 mg)",
      "purpose": "Fever, headache, and body pain relief",
      "knPurpose": "ಜ್ವರ, ತಲೆನೋವು ಮತ್ತು ಮೈ-ಕೈ ನೋವು ನಿವಾರಣೆ",
      "hiPurpose": "बुखार, सिरदर्द और बदन दर्द से राहत",
    },
    "calpol650": {
      "composition": "Paracetamol IP (650 mg)",
      "purpose": "Fever and mild-to-moderate pain relief",
      "knPurpose": "ಜ್ವರ ಮತ್ತು ನೋವು ನಿವಾರಣೆ",
      "hiPurpose": "बुखार और दर्द से राहत",
    },
    "calpol500": {
      "composition": "Paracetamol IP (500 mg)",
      "purpose": "Fever and mild pain relief",
      "knPurpose": "ಜ್ವರ ಮತ್ತು ನೋವು ನಿವಾರಣೆ",
      "hiPurpose": "बुखार और दर्द से राहत",
    },
    "calpol": {
      "composition": "Paracetamol IP",
      "purpose": "Fever and pain relief",
      "knPurpose": "ಜ್ವರ ಮತ್ತು ನೋವು ನಿವಾರಣೆ",
      "hiPurpose": "बुखार और दर्द से राहत",
    },
    "feverx650": {
      "composition": "Paracetamol IP (650 mg)",
      "purpose": "Fever and pain relief",
      "knPurpose": "ಜ್ವರ ಮತ್ತು ನೋವು ನಿವಾರಣೆ",
      "hiPurpose": "बुखार और दर्द से राहत",
    },
    "feverx": {
      "composition": "Paracetamol IP (650 mg)",
      "purpose": "Fever and pain relief",
      "knPurpose": "ಜ್ವರ ಮತ್ತು ನೋವು ನಿವಾರಣೆ",
      "hiPurpose": "बुखार और दर्द से राहत",
    },
    "crocin650": {
      "composition": "Paracetamol IP (650 mg)",
      "purpose": "Fever and headache relief",
      "knPurpose": "ಜ್ವರ ಮತ್ತು ತಲೆನೋವು ನಿವಾರಣೆ",
      "hiPurpose": "बुखार और सिरदर्द से राहत",
    },
    "crocinadvance": {
      "composition": "Paracetamol IP (500 mg) Fast Action",
      "purpose": "Fast relief from fever and body pain",
      "knPurpose": "ಜ್ವರ ಮತ್ತು ಮೈ-ಕೈ ನೋವು ಶೀಘ್ರ ನಿವಾರಣೆ",
      "hiPurpose": "बुखार और दर्द से तेज़ राहत",
    },
    "crocin": {
      "composition": "Paracetamol IP",
      "purpose": "Fever and headache relief",
      "knPurpose": "ಜ್ವರ ಮತ್ತು ತಲೆನೋವು ನಿವಾರಣೆ",
      "hiPurpose": "बुखार और सिरदर्द से राहत",
    },
    "paracetamol": {
      "composition": "Paracetamol IP",
      "purpose": "Fever, headache, and pain relief",
      "knPurpose": "ಜ್ವರ ಮತ್ತು ನೋವು ನಿವಾರಣೆ",
      "hiPurpose": "बुखार और दर्द से राहत",
    },
    "combiflam": {
      "composition": "Ibuprofen IP (400 mg) + Paracetamol IP (325 mg)",
      "purpose": "Fever, dental pain, body ache, and joint inflammation",
      "knPurpose": "ಜ್ವರ, ಹಲ್ಲು ನೋವು, ಮೈ-ಕೈ ನೋವು ಮತ್ತು ಊತ ನಿವಾರಣೆ",
      "hiPurpose": "बुखार, दांत दर्द, बदन दर्द और सूजन से राहत",
    },
    "brufen": {
      "composition": "Ibuprofen IP (400 mg)",
      "purpose": "Pain relief, muscle ache, and joint swelling",
      "knPurpose": "ನೋವು ಮತ್ತು ಊತ ನಿವಾರಣೆ",
      "hiPurpose": "दर्द और सूजन से राहत",
    },
    "ibuprofen": {
      "composition": "Ibuprofen IP",
      "purpose": "Pain relief and anti-inflammatory",
      "knPurpose": "ನೋವು ಮತ್ತು ಊತ ನಿವಾರಣೆ",
      "hiPurpose": "दर्द और सूजन से राहत",
    },
    "disprin": {
      "composition": "Aspirin / Acetylsalicylic Acid (350 mg)",
      "purpose": "Headache, fever, and pain relief",
      "knPurpose": "ತಲೆನೋವು ಮತ್ತು ಜ್ವರ ನಿವಾರಣೆ",
      "hiPurpose": "सिरदर्द और बुखार से राहत",
    },
    "aspirin": {
      "composition": "Aspirin / Acetylsalicylic Acid",
      "purpose": "Pain relief and blood clot prevention",
      "knPurpose": "ನೋವು ನಿವಾರಣೆ ಮತ್ತು ರಕ್ತ ತಿಳಿಯಾಗಿಸಲು",
      "hiPurpose": "दर्द से राहत और खून को पतला रखने के लिए",
    },
    "voveran": {
      "composition": "Diclofenac Sodium IP (50 mg)",
      "purpose": "Severe pain, arthritis, and joint inflammation",
      "knPurpose": "ಕೀಲು ನೋವು ಮತ್ತು ಉರಿಯೂತ ನಿವಾರಣೆ",
      "hiPurpose": "जोड़ों के दर्द और सूजन से राहत",
    },
    "diclofenac": {
      "composition": "Diclofenac Sodium IP",
      "purpose": "Pain relief and anti-inflammatory",
      "knPurpose": "ನೋವು ಮತ್ತು ಉರಿಯೂತ ನಿವಾರಣೆ",
      "hiPurpose": "दर्द और सूजन से राहत",
    },
    "zerodolsp": {
      "composition": "Aceclofenac (100 mg) + Paracetamol (325 mg) + Serratiopeptidase (15 mg)",
      "purpose": "Severe pain, swelling, and muscle inflammation relief",
      "knPurpose": "ತೀವ್ರ ನೋವು, ಊತ ಮತ್ತು ಸ್ನಾಯು ಉರಿಯೂತ ನಿವಾರಣೆ",
      "hiPurpose": "दर्द, सूजन और मांसपेशियों की ऐंठन से राहत",
    },
    "zerodolp": {
      "composition": "Aceclofenac (100 mg) + Paracetamol (325 mg)",
      "purpose": "Joint and muscle ache, dental pain, and fever",
      "knPurpose": "ಮೈ-ಕೈ ನೋವು, ಕೀಲು ನೋವು ಮತ್ತು ಜ್ವರ ನಿವಾರಣೆ",
      "hiPurpose": "जोड़ों के दर्द और बुखार से राहत",
    },
    "zerodol": {
      "composition": "Aceclofenac (100 mg)",
      "purpose": "Pain and inflammation relief",
      "knPurpose": "ನೋವು ಮತ್ತು ಉರಿಯೂತ ನಿವಾರಣೆ",
      "hiPurpose": "दर्द और सूजन से राहत",
    },
    "aceclofenac": {
      "composition": "Aceclofenac IP",
      "purpose": "Pain and inflammatory relief",
      "knPurpose": "ನೋವು ಮತ್ತು ಉರಿಯೂತ ನಿವಾರಣೆ",
      "hiPurpose": "दर्द और सूजन से राहत",
    },
    "meftalspas": {
      "composition": "Mefenamic Acid (250 mg) + Dicyclomine Hydrochloride (10 mg)",
      "purpose": "Abdominal cramps, stomach spasms, and menstrual pain relief",
      "knPurpose": "ಹೊಟ್ಟೆ ನೋವು, ಸೆಳೆತ ಮತ್ತು ಮುಟ್ಟಿನ ನೋವು ನಿವಾರಣೆ",
      "hiPurpose": "पेट दर्द, ऐंठन और मासिक धर्म के दर्द से राहत",
    },
    "meftal": {
      "composition": "Mefenamic Acid IP (500 mg)",
      "purpose": "Menstrual pain, dental ache, and muscular discomfort",
      "knPurpose": "ಮುಟ್ಟಿನ ನೋವು ಮತ್ತು ಮೈ-ಕೈ ನೋವು ನಿವಾರಣೆ",
      "hiPurpose": "मासिक धर्म के दर्द और बदन दर्द से राहत",
    },
    "ultracet": {
      "composition": "Tramadol Hydrochloride (37.5 mg) + Paracetamol (325 mg)",
      "purpose": "Moderate to severe acute pain relief",
      "knPurpose": "ತೀವ್ರ ಸ್ವರೂಪದ ನೋವು ನಿವಾರಣೆ",
      "hiPurpose": "गंभीर दर्द से राहत के लिए",
    },
    "tramadol": {
      "composition": "Tramadol Hydrochloride IP",
      "purpose": "Moderate to severe pain relief",
      "knPurpose": "ತೀವ್ರ ನೋವು ನಿವಾರಣೆ",
      "hiPurpose": "गंभीर दर्द से राहत",
    },

    // Gastrointestinal & Antacids
    "pan40": {
      "composition": "Pantoprazole Sodium Gastro-resistant (40 mg)",
      "purpose": "Acidity, heartburn, acid reflux (GERD), and stomach ulcers",
      "knPurpose": "ಅಸಿಡಿಟಿ, ಎದೆಯುರಿ, ಗ್ಯಾಸ್ಟ್ರಿಕ್ ಮತ್ತು ಹೊಟ್ಟೆಯ ಹುಣ್ಣು ನಿವಾರಣೆ",
      "hiPurpose": "एसिडिटी, सीने में जलन, गैस और पेट के अल्सर से राहत",
    },
    "pand": {
      "composition": "Pantoprazole (40 mg) + Domperidone (30 mg)",
      "purpose": "Acidity, nausea, acid reflux, and stomach heaviness",
      "knPurpose": "ಅಸಿಡಿಟಿ, ವಾಕರಿಕೆ ಮತ್ತು ಎದೆಯುರಿ ನಿವಾರಣೆ",
      "hiPurpose": "एसिडिटी, मतली और सीने में जलन से राहत",
    },
    "pantocid40": {
      "composition": "Pantoprazole Sodium IP (40 mg)",
      "purpose": "Acidity, GERD, and stomach acid reduction",
      "knPurpose": "ಅಸಿಡಿಟಿ ಮತ್ತು ಎದೆಯುರಿ ನಿವಾರಣೆ",
      "hiPurpose": "एसिडिटी और सीने में जलन से राहत",
    },
    "pantocid": {
      "composition": "Pantoprazole Sodium IP",
      "purpose": "Acidity and reflux treatment",
      "knPurpose": "ಅಸಿಡಿಟಿ ನಿವಾರಣೆ",
      "hiPurpose": "एसिडिटी से राहत",
    },
    "pantoprazole": {
      "composition": "Pantoprazole Sodium IP",
      "purpose": "Reduces stomach acid and prevents heartburn",
      "knPurpose": "ಅಸಿಡಿಟಿ ಮತ್ತು ಎದೆಯುರಿ ನಿವಾರಣೆ",
      "hiPurpose": "एसिडिटी और सीने में जलन से राहत",
    },
    "omez20": {
      "composition": "Omeprazole Gastro-resistant (20 mg)",
      "purpose": "Stomach acid reducer for indigestion and heartburn",
      "knPurpose": "ಎದೆಯುರಿ, ಅಜೀರ್ಣ ಮತ್ತು ಗ್ಯಾಸ್ಟ್ರಿಕ್ ನಿವಾರಣೆ",
      "hiPurpose": "सीने में जलन, अपच और गैस से राहत",
    },
    "omezd": {
      "composition": "Omeprazole (20 mg) + Domperidone (10 mg)",
      "purpose": "Acid reflux, nausea, and indigestion relief",
      "knPurpose": "ಎದೆಯುರಿ ಮತ್ತು ವಾಂತಿ ನಿವಾರಣೆ",
      "hiPurpose": "एसिडिटी और मतली से राहत",
    },
    "omez": {
      "composition": "Omeprazole IP (20 mg)",
      "purpose": "Gastric acid reducer for heartburn and indigestion",
      "knPurpose": "ಗ್ಯಾಸ್ಟ್ರಿಕ್ ಮತ್ತು ಎದೆಯುರಿ ನಿವಾರಣೆ",
      "hiPurpose": "एसिडिटी और सीने में जलन से राहत",
    },
    "omeprazole": {
      "composition": "Omeprazole IP",
      "purpose": "Stomach acid reducer for reflux and heartburn",
      "knPurpose": "ಅಸಿಡಿಟಿ ಮತ್ತು ಎದೆಯುರಿ ನಿವಾರಣೆ",
      "hiPurpose": "एसिडिटी और सीने में जलन से राहत",
    },
    "razo20": {
      "composition": "Rabeprazole Sodium IP (20 mg)",
      "purpose": "Fast-acting relief from acidity, heartburn, and GERD",
      "knPurpose": "ಅಸಿಡಿಟಿ ಮತ್ತು ಎದೆಯುರಿ ಶೀಘ್ರ ನಿವಾರಣೆ",
      "hiPurpose": "एसिडिटी और सीने में जलन से त्वरित राहत",
    },
    "rablet20": {
      "composition": "Rabeprazole Sodium IP (20 mg)",
      "purpose": "Acidity and acid reflux treatment",
      "knPurpose": "ಅಸಿಡಿಟಿ ಮತ್ತು ಎದೆಯುರಿ ನಿವಾರಣೆ",
      "hiPurpose": "एसिडिटी और सीने में जलन से राहत",
    },
    "rabeprazole": {
      "composition": "Rabeprazole Sodium IP",
      "purpose": "Stomach acid reduction and reflux relief",
      "knPurpose": "ಅಸಿಡಿಟಿ ನಿವಾರಣೆ",
      "hiPurpose": "एसिडिटी से राहत",
    },
    "nexpro40": {
      "composition": "Esomeprazole Magnesium (40 mg)",
      "purpose": "Heals acid reflux, heartburn, and erosive esophagitis",
      "knPurpose": "ಎದೆಯುರಿ ಮತ್ತು ಅಸಿಡಿಟಿ ನಿವಾರಣೆ",
      "hiPurpose": "सीने में जलन और एसिडिटी से राहत",
    },
    "nexpro": {
      "composition": "Esomeprazole Magnesium",
      "purpose": "Gastric acid reducer for GERD",
      "knPurpose": "ಅಸಿಡಿಟಿ ನಿವಾರಣೆ",
      "hiPurpose": "एसिडिटी से राहत",
    },
    "esomeprazole": {
      "composition": "Esomeprazole IP",
      "purpose": "Gastric acid reduction and ulcer healing",
      "knPurpose": "ಅಸಿಡಿಟಿ ನಿವಾರಣೆ",
      "hiPurpose": "एसिडिटी से राहत",
    },
    "doxinate": {
      "composition": "Doxylamine Succinate (10 mg) + Pyridoxine HCl / Vitamin B6 (10 mg)",
      "purpose": "Pregnancy morning sickness, nausea, and vomiting relief",
      "knPurpose": "ಗರ್ಭಾವಸ್ಥೆಯ ವಾಂತಿ, ತಲೆತಿರುಗುವಿಕೆ ಮತ್ತು ವಾಕರಿಕೆ ನಿವಾರಣೆ",
      "hiPurpose": "गर्भावस्था में उल्टी, मतली और चक्कर से राहत",
    },
    "vomikind": {
      "composition": "Ondansetron IP (4 mg)",
      "purpose": "Fast relief from nausea and vomiting",
      "knPurpose": "ವಾಂತಿ ಮತ್ತು ವಾಕರಿಕೆ ನಿವಾರಣೆ",
      "hiPurpose": "उल्टी और मतली की रोकथाम",
    },
    "perinorm": {
      "composition": "Metoclopramide Hydrochloride IP (10 mg)",
      "purpose": "Prevents vomiting and aids gastric emptying",
      "knPurpose": "ವಾಂತಿ ನಿವಾರಣೆ ಮತ್ತು ಜೀರ್ಣಕ್ರಿಯೆ ಸುಧಾರಣೆ",
      "hiPurpose": "उल्टी रोकने और पाचन गति बढ़ाने के लिए",
    },
    "emeset4": {
      "composition": "Ondansetron IP (4 mg)",
      "purpose": "Prevents and stops nausea and vomiting",
      "knPurpose": "ವಾಂತಿ ಮತ್ತು ವಾಕರಿಕೆ ನಿವಾರಣೆ",
      "hiPurpose": "उल्टी और मतली से राहत",
    },
    "emeset": {
      "composition": "Ondansetron IP (4 mg)",
      "purpose": "Stops nausea and vomiting",
      "knPurpose": "ವಾಂತಿ ನಿವಾರಣೆ",
      "hiPurpose": "उल्टी से राहत",
    },
    "ondansetron": {
      "composition": "Ondansetron IP",
      "purpose": "Anti-emetic for nausea and vomiting control",
      "knPurpose": "ವಾಂತಿ ನಿವಾರಣೆ",
      "hiPurpose": "उल्टी की रोकथाम",
    },
    "digene": {
      "composition": "Dried Aluminium Hydroxide + Magnesium Hydroxide + Simethicone",
      "purpose": "Instant relief from acidity, heartburn, and gas bloating",
      "knPurpose": "ಅಸಿಡಿಟಿ, ಎದೆಯುರಿ ಮತ್ತು ಗ್ಯಾಸ್ ನಿಂದ ತಕ್ಷಣದ ಮುಕ್ತಿ",
      "hiPurpose": "एसिडिटी, सीने में जलन और गैस से तुरंत राहत",
    },
    "gelusil": {
      "composition": "Aluminium Hydroxide + Magnesium Silicate + Simethicone",
      "purpose": "Relief from acidity, stomach discomfort, and flatulence",
      "knPurpose": "ಅಸಿಡಿಟಿ ಮತ್ತು ಗ್ಯಾಸ್ ನಿವಾರಣೆ",
      "hiPurpose": "एसिडिटी और गैस से राहत",
    },

    // Antibiotics & Antimicrobials
    "augmentin625duo": {
      "composition": "Amoxicillin Trihydrate (500 mg) + Potassium Clavulanate (125 mg)",
      "purpose": "Broad-spectrum antibiotic for bacterial infections (chest, throat, teeth, skin)",
      "knPurpose": "ಬ್ಯಾಕ್ಟೀರಿಯಾ ಸೋಂಕು ನಿವಾರಕ ಆಂಟಿಬಯೋಟಿಕ್",
      "hiPurpose": "बैक्टीरियल संक्रमण के इलाज के लिए एंटीबायोटिक",
    },
    "augmentin625": {
      "composition": "Amoxicillin (500 mg) + Clavulanic Acid (125 mg)",
      "purpose": "Antibiotic for bacterial infections",
      "knPurpose": "ಬ್ಯಾಕ್ಟೀರಿಯಾ ಸೋಂಕು ನಿವಾರಕ ಆಂಟಿಬಯೋಟಿಕ್",
      "hiPurpose": "बैक्टीरियल इन्फेक्शन के लिए एंटीबायोटिक",
    },
    "augmentin": {
      "composition": "Amoxicillin + Potassium Clavulanate",
      "purpose": "Antibiotic for bacterial infections",
      "knPurpose": "ಬ್ಯಾಕ್ಟೀರಿಯಾ ಸೋಂಕು ನಿವಾರಕ ಆಂಟಿಬಯೋಟಿಕ್",
      "hiPurpose": "बैक्टीरियल इन्फेक्शन के लिए एंटीबायोटिक",
    },
    "clavam625": {
      "composition": "Amoxicillin (500 mg) + Potassium Clavulanate (125 mg)",
      "purpose": "Antibiotic for bacterial respiratory and dental infections",
      "knPurpose": "ಬ್ಯಾಕ್ಟೀರಿಯಾ ಸೋಂಕು ನಿವಾರಕ ಆಂಟಿಬಯೋಟಿಕ್",
      "hiPurpose": "बैक्टीरियल इन्फेक्शन के लिए एंटीबायोटिक",
    },
    "moxikindcv": {
      "composition": "Amoxicillin (500 mg) + Potassium Clavulanate (125 mg)",
      "purpose": "Antibiotic for bacterial infections",
      "knPurpose": "ಬ್ಯಾಕ್ಟೀರಿಯಾ ಸೋಂಕು ನಿವಾರಕ",
      "hiPurpose": "बैक्टीरियल संक्रमण के लिए",
    },
    "amoxicillin": {
      "composition": "Amoxicillin Trihydrate IP",
      "purpose": "Antibiotic for bacterial infections",
      "knPurpose": "ಬ್ಯಾಕ್ಟೀರಿಯಾ ಸೋಂಕು ನಿವಾರಕ",
      "hiPurpose": "बैक्टीरियल इन्फेक्शन के लिए एंटीबायोटिक",
    },
    "amoxyclav": {
      "composition": "Amoxicillin + Potassium Clavulanate",
      "purpose": "Antibiotic for resistant bacterial infections",
      "knPurpose": "ಬ್ಯಾಕ್ಟೀರಿಯಾ ಸೋಂಕು ನಿವಾರಕ",
      "hiPurpose": "बैक्टीरियल इन्फेक्शन के लिए एंटीबायोटिक",
    },
    "azithral500": {
      "composition": "Azithromycin Dihydrate IP (500 mg)",
      "purpose": "Antibiotic for throat, tonsils, chest, sinus, and respiratory infections",
      "knPurpose": "ಗಂಟಲು, ಶ್ವಾಸಕೋಶ ಮತ್ತು ಕಫ ಸೋಂಕು ನಿವಾರಕ ಆಂಟಿಬಯೋಟಿಕ್",
      "hiPurpose": "गले, फेफड़ों और सांस के इन्फेक्शन के लिए एंटीबायोटिक",
    },
    "azithral": {
      "composition": "Azithromycin Dihydrate IP (500 mg)",
      "purpose": "Antibiotic for throat and respiratory infections",
      "knPurpose": "ಗಂಟಲು ಮತ್ತು ಶ್ವಾಸಕೋಶದ ಸೋಂಕು ನಿವಾರಕ",
      "hiPurpose": "गले और सांस के इन्फेक्शन के लिए",
    },
    "azee500": {
      "composition": "Azithromycin IP (500 mg)",
      "purpose": "Antibiotic for respiratory and skin infections",
      "knPurpose": "ಶ್ವಾಸಕೋಶ ಮತ್ತು ಗಂಟಲಿನ ಸೋಂಕು ನಿವಾರಕ",
      "hiPurpose": "गले और सांस के इन्फेक्शन के लिए",
    },
    "azee": {
      "composition": "Azithromycin IP",
      "purpose": "Antibiotic for bacterial infections",
      "knPurpose": "ಬ್ಯಾಕ್ಟೀರಿಯಾ ಸೋಂಕು ನಿವಾರಕ",
      "hiPurpose": "बैक्टीरियल इन्फेक्शन के लिए",
    },
    "azithromycin": {
      "composition": "Azithromycin IP",
      "purpose": "Broad-spectrum macrolide antibiotic for infections",
      "knPurpose": "ಬ್ಯಾಕ್ಟೀರಿಯಾ ಸೋಂಕು ನಿವಾರಕ",
      "hiPurpose": "बैक्टीरियल इन्फेक्शन के लिए एंटीबायोटिक",
    },
    "cefixime": {
      "composition": "Cefixime Trihydrate IP",
      "purpose": "Antibiotic for typhoid, urinary, and respiratory infections",
      "knPurpose": "ಟೈಫಾಯಿಡ್ ಮತ್ತು ಮೂತ್ರನಾಳದ ಸೋಂಕು ನಿವಾರಕ",
      "hiPurpose": "टाइफाइड और यूरिन इन्फेक्शन के लिए एंटीबायोटिक",
    },
    "taximo": {
      "composition": "Cefixime IP (200 mg)",
      "purpose": "Antibiotic for bacterial infections and typhoid",
      "knPurpose": "ಟೈಫಾಯಿಡ್ ಮತ್ತು ಬ್ಯಾಕ್ಟೀರಿಯಾ ಸೋಂಕು ನಿವಾರಕ",
      "hiPurpose": "टाइफाइड और बैक्टीरियल संक्रमण के लिए",
    },
    "mahacef": {
      "composition": "Cefixime IP (200 mg)",
      "purpose": "Antibiotic for bacterial infections",
      "knPurpose": "ಬ್ಯಾಕ್ಟೀರಿಯಾ ಸೋಂಕು ನಿವಾರಕ",
      "hiPurpose": "बैक्टीरियल संक्रमण के लिए",
    },
    "ciplox": {
      "composition": "Ciprofloxacin Hydrochloride IP (500 mg)",
      "purpose": "Antibiotic for urinary tract, eye/ear, and stomach infections",
      "knPurpose": "ಮೂತ್ರನಾಳ ಮತ್ತು ಕಣ್ಣು/ಕಿವಿ ಸೋಂಕು ನಿವಾರಕ",
      "hiPurpose": "यूरिन और आंख/कान के इन्फेक्शन के लिए एंटीबायोटिक",
    },
    "ciprofloxacin": {
      "composition": "Ciprofloxacin Hydrochloride IP",
      "purpose": "Antibiotic for bacterial infections",
      "knPurpose": "ಬ್ಯಾಕ್ಟೀರಿಯಾ ಸೋಂಕು ನಿವಾರಕ",
      "hiPurpose": "बैक्टीरियल इन्फेक्शन के लिए एंटीबायोटिक",
    },
    "oflox": {
      "composition": "Ofloxacin IP (200 mg)",
      "purpose": "Antibiotic for bacterial infections",
      "knPurpose": "ಬ್ಯಾಕ್ಟೀರಿಯಾ ಸೋಂಕು ನಿವಾರಕ",
      "hiPurpose": "बैक्टीरियल संक्रमण के लिए एंटीबायोटिक",
    },
    "ofloxacin": {
      "composition": "Ofloxacin IP",
      "purpose": "Antibiotic for bacterial infections",
      "knPurpose": "ಬ್ಯಾಕ್ಟೀರಿಯಾ ಸೋಂಕು ನಿವಾರಕ",
      "hiPurpose": "बैक्टीरियल संक्रमण के लिए",
    },
    "norfloxtz": {
      "composition": "Norfloxacin (400 mg) + Tinidazole (600 mg)",
      "purpose": "Treatment for bacterial diarrhea, amoebiasis, and stomach infections",
      "knPurpose": "ಹೊಟ್ಟೆ ಕೆಡುವುದು ಮತ್ತು ಅತಿಸಾರ ಸೋಂಕು ನಿವಾರಣೆ",
      "hiPurpose": "दस्त और पेट के बैक्टीरियल इन्फेक्शन के लिए",
    },
    "norfloxacin": {
      "composition": "Norfloxacin IP",
      "purpose": "Antibiotic for urinary tract and stomach infections",
      "knPurpose": "ಮೂತ್ರನಾಳ ಮತ್ತು ಹೊಟ್ಟೆಯ ಸೋಂಕು ನಿವಾರಕ",
      "hiPurpose": "यूरिन और पेट के इन्फेक्शन के लिए",
    },
    "flagyl": {
      "composition": "Metronidazole IP (400 mg)",
      "purpose": "Treatment for bacterial and amoebic intestinal infections",
      "knPurpose": "ಕರುಳಿನ ಸೋಂಕು ಮತ್ತು ಅತಿಸಾರ ನಿವಾರಣೆ",
      "hiPurpose": "आंतों के इन्फेक्शन और दस्त के लिए",
    },
    "metronidazole": {
      "composition": "Metronidazole IP",
      "purpose": "Antiprotozoal and anaerobic antibiotic",
      "knPurpose": "ಬ್ಯಾಕ್ಟೀರಿಯಾ ಮತ್ತು ಪರಾವಲಂಬಿ ಸೋಂಕು ನಿವಾರಕ",
      "hiPurpose": "बैक्टीरियल और परजीवी इन्फेक्शन के लिए",
    },
    "doxtsl": {
      "composition": "Doxycycline (100 mg) + Lactic Acid Bacillus",
      "purpose": "Antibiotic for acne, chest, and bacterial infections",
      "knPurpose": "ಮೊಡವೆ ಮತ್ತು ಎದೆಯ ಸೋಂಕು ನಿವಾರಕ ಆಂಟಿಬಯೋಟಿಕ್",
      "hiPurpose": "मुंहासे और छाती के इन्फेक्शन के लिए",
    },
    "doxycycline": {
      "composition": "Doxycycline Hydrochloride IP",
      "purpose": "Antibiotic for bacterial infections and acne",
      "knPurpose": "ಬ್ಯಾಕ್ಟೀರಿಯಾ ಸೋಂಕು ನಿವಾರಕ",
      "hiPurpose": "बैक्टीरियल इन्फेक्शन के लिए",
    },

    // Diabetes
    "glycometgp": {
      "composition": "Glimepiride + Metformin Hydrochloride",
      "purpose": "Dual medication for type-2 diabetes blood sugar control",
      "knPurpose": "ಟೈಪ್-2 ಮಧುಮೇಹದಲ್ಲಿ ರಕ್ತದ ಸಕ್ಕರೆ ನಿಯಂತ್ರಣ",
      "hiPurpose": "टाइप-2 डायबिटीज में ब्लड शुगर का नियंत्रण",
    },
    "glycomet500": {
      "composition": "Metformin Hydrochloride IP (500 mg)",
      "purpose": "Lowers high blood sugar in type-2 diabetes",
      "knPurpose": "ಟೈಪ್-2 ಮಧುಮೇಹದಲ್ಲಿ ಸಕ್ಕರೆ ಮಟ್ಟ ನಿಯಂತ್ರಣ",
      "hiPurpose": "डायबिटीज में ब्लड शुगर का नियंत्रण",
    },
    "glycomet": {
      "composition": "Metformin Hydrochloride IP",
      "purpose": "Controls blood sugar in type-2 diabetes",
      "knPurpose": "ಮಧುಮೇಹ ನಿಯಂತ್ರಣ",
      "hiPurpose": "डायबिटीज में शुगर नियंत्रण",
    },
    "metformin": {
      "composition": "Metformin Hydrochloride IP",
      "purpose": "First-line medicine to control high blood sugar in diabetes",
      "knPurpose": "ಮಧುಮೇಹದಲ್ಲಿ ಸಕ್ಕರೆ ನಿಯಂತ್ರಣ",
      "hiPurpose": "डायबिटीज में ब्लड शुगर नियंत्रण",
    },
    "glimepiride": {
      "composition": "Glimepiride IP",
      "purpose": "Stimulates natural insulin production in type-2 diabetes",
      "knPurpose": "ಮಧುಮೇಹದಲ್ಲಿ ಇನ್ಸುಲಿನ್ ಉತ್ಪಾದನೆ ಪ್ರಚೋದನೆ",
      "hiPurpose": "डायबिटीज में इंसुलिन बढ़ाने के लिए",
    },
    "amaryl": {
      "composition": "Glimepiride (1 mg / 2 mg)",
      "purpose": "Lowers blood glucose in type-2 diabetes",
      "knPurpose": "ಮಧುಮೇಹ ನಿಯಂತ್ರಣ",
      "hiPurpose": "डायबिटीज में ब्लड शुगर नियंत्रण",
    },
    "januvia": {
      "composition": "Sitagliptin Phosphate (100 mg)",
      "purpose": "DPP-4 inhibitor to control blood sugar in diabetes",
      "knPurpose": "ಮಧುಮೇಹದಲ್ಲಿ ಸಕ್ಕರೆ ಮಟ್ಟ ನಿಯಂತ್ರಣ",
      "hiPurpose": "डायबिटीज में शुगर नियंत्रण",
    },
    "galvus": {
      "composition": "Vildagliptin (50 mg)",
      "purpose": "DPP-4 inhibitor to maintain steady blood glucose",
      "knPurpose": "ಮಧುಮೇಹ ನಿಯಂತ್ರಣ",
      "hiPurpose": "डायबिटीज में शुगर नियंत्रण",
    },
    "forxiga": {
      "composition": "Dapagliflozin Propanediol (10 mg)",
      "purpose": "SGLT2 inhibitor to lower blood sugar and protect heart & kidneys",
      "knPurpose": "ಮಧುಮೇಹ, ಹೃದಯ ಮತ್ತು ಮೂತ್ರಪಿಂಡಗಳ ರಕ್ಷಣೆ",
      "hiPurpose": "डायबिटीज में शुगर नियंत्रण और किडनी/हार्ट सुरक्षा",
    },
    "jardiance": {
      "composition": "Empagliflozin (10 mg / 25 mg)",
      "purpose": "Lowers blood glucose and reduces cardiovascular risk in diabetes",
      "knPurpose": "ಮಧುಮೇಹ ಮತ್ತು ಹೃದಯದ ಆರೋಗ್ಯ ರಕ್ಷಣೆ",
      "hiPurpose": "डायबिटीज और हृदय सुरक्षा के लिए",
    },

    // Hypertension & Cardiac
    "telma40": {
      "composition": "Telmisartan IP (40 mg)",
      "purpose": "Lowers high blood pressure (hypertension) and protects heart",
      "knPurpose": "ಅಧಿಕ ರಕ್ತದೊತ್ತಡ (BP) ನಿಯಂತ್ರಣ ಮತ್ತು ಹೃದಯ ರಕ್ಷಣೆ",
      "hiPurpose": "हाई ब्लड प्रेशर (बीपी) नियंत्रण और हृदय सुरक्षा",
    },
    "telmah": {
      "composition": "Telmisartan (40 mg) + Hydrochlorothiazide (12.5 mg)",
      "purpose": "Dual therapy for high blood pressure control",
      "knPurpose": "ರಕ್ತದೊತ್ತಡ (BP) ನಿಯಂತ್ರಣ",
      "hiPurpose": "ब्लड प्रेशर नियंत्रण",
    },
    "telma": {
      "composition": "Telmisartan IP (40 mg)",
      "purpose": "Controls high blood pressure and protects heart",
      "knPurpose": "ರಕ್ತದೊತ್ತಡ ನಿಯಂತ್ರಣ",
      "hiPurpose": "ब्लड प्रेशर नियंत्रण",
    },
    "telmikind40": {
      "composition": "Telmisartan IP (40 mg)",
      "purpose": "Controls high blood pressure",
      "knPurpose": "ರಕ್ತದೊತ್ತಡ ನಿಯಂತ್ರಣ",
      "hiPurpose": "ब्लड प्रेशर नियंत्रण",
    },
    "telmisartan": {
      "composition": "Telmisartan IP",
      "purpose": "Lowers high blood pressure and reduces risk of heart attack",
      "knPurpose": "ಅಧಿಕ ರಕ್ತದೊತ್ತಡ ಮತ್ತು ಹೃದಯಾಘಾತ ತಡೆಗಟ್ಟಲು",
      "hiPurpose": "हाई ब्लड प्रेशर नियंत्रण और हार्ट अटैक से बचाव",
    },
    "amlong5": {
      "composition": "Amlodipine Besylate IP (5 mg)",
      "purpose": "Calcium channel blocker for high blood pressure and angina",
      "knPurpose": "ಅಧಿಕ ರಕ್ತದೊತ್ತಡ ಮತ್ತು ಎದೆ ನೋವು ನಿವಾರಣೆ",
      "hiPurpose": "हाई ब्लड प्रेशर और सीने के दर्द से राहत",
    },
    "amlong": {
      "composition": "Amlodipine Besylate IP (5 mg)",
      "purpose": "Lowers high blood pressure",
      "knPurpose": "ರಕ್ತದೊತ್ತಡ ನಿಯಂತ್ರಣ",
      "hiPurpose": "ब्लड प्रेशर नियंत्रण",
    },
    "amlodipine": {
      "composition": "Amlodipine Besylate IP",
      "purpose": "Lowers high blood pressure and improves blood flow",
      "knPurpose": "ರಕ್ತದೊತ್ತಡ ನಿಯಂತ್ರಣ",
      "hiPurpose": "ब्लड प्रेशर नियंत्रण",
    },
    "aten50": {
      "composition": "Atenolol IP (50 mg)",
      "purpose": "Beta-blocker for high blood pressure and irregular heartbeat",
      "knPurpose": "ಅಧಿಕ ರಕ್ತದೊತ್ತಡ ಮತ್ತು ಹೃದಯ ಬಡಿತ ನಿಯಂತ್ರಣ",
      "hiPurpose": "हाई ब्लड प्रेशर और दिल की धड़कन नियंत्रण",
    },
    "aten": {
      "composition": "Atenolol IP",
      "purpose": "Beta-blocker for blood pressure control",
      "knPurpose": "ರಕ್ತದೊತ್ತಡ ನಿಯಂತ್ರಣ",
      "hiPurpose": "ब्लड प्रेशर नियंत्रण",
    },
    "atenolol": {
      "composition": "Atenolol IP",
      "purpose": "Controls high blood pressure and protects heart",
      "knPurpose": "ರಕ್ತದೊತ್ತಡ ನಿಯಂತ್ರಣ",
      "hiPurpose": "ब्लड प्रेशर नियंत्रण",
    },
    "atorva10": {
      "composition": "Atorvastatin Calcium IP (10 mg)",
      "purpose": "Lowers bad cholesterol (LDL) and prevents heart disease",
      "knPurpose": "ಕೆಟ್ಟ ಕೊಲೆಸ್ಟ್ರಾಲ್ ಕಡಿಮೆ ಮಾಡಿ ಹೃದಯ ರಕ್ಷಣೆ",
      "hiPurpose": "खराब कोलेस्ट्रॉल कम करने और हृदय सुरक्षा के लिए",
    },
    "atorva20": {
      "composition": "Atorvastatin Calcium IP (20 mg)",
      "purpose": "Lowers bad cholesterol and triglycerides, protects arteries",
      "knPurpose": "ಕೊಲೆಸ್ಟ್ರಾಲ್ ಕಡಿಮೆ ಮಾಡಿ ಹೃದಯ ರಕ್ಷಣೆ",
      "hiPurpose": "कोलेस्ट्रॉल कम करने और हृदय सुरक्षा के लिए",
    },
    "atorva": {
      "composition": "Atorvastatin Calcium IP",
      "purpose": "Statin to lower bad cholesterol and prevent heart attack",
      "knPurpose": "ಕೊಲೆಸ್ಟ್ರಾಲ್ ನಿಯಂತ್ರಣ",
      "hiPurpose": "कोलेस्ट्रॉल नियंत्रण",
    },
    "atorvastatin": {
      "composition": "Atorvastatin Calcium IP",
      "purpose": "Lowers bad cholesterol and reduces risk of stroke and heart attack",
      "knPurpose": "ಕೊಲೆಸ್ಟ್ರಾಲ್ ಕಡಿಮೆ ಮಾಡಿ ಪಾರ್ಶ್ವವಾಯು ಮತ್ತು ಹೃದಯಾಘಾತ ತಡೆಗಟ್ಟಲು",
      "hiPurpose": "कोलेस्ट्रॉल कम करने और स्ट्रोक/हार्ट अटैक से बचाव के लिए",
    },
    "rosuvas10": {
      "composition": "Rosuvastatin Calcium IP (10 mg)",
      "purpose": "Potent statin to lower bad cholesterol and triglycerides",
      "knPurpose": "ಕೊಲೆಸ್ಟ್ರಾಲ್ ನಿಯಂತ್ರಣ ಮತ್ತು ಹೃದಯ ರಕ್ಷಣೆ",
      "hiPurpose": "कोलेस्ट्रॉल कम करने और हृदय सुरक्षा के लिए",
    },
    "rosuvastatin": {
      "composition": "Rosuvastatin Calcium IP",
      "purpose": "Lowers cholesterol and prevents plaque buildup in arteries",
      "knPurpose": "ಕೊಲೆಸ್ಟ್ರಾಲ್ ನಿಯಂತ್ರಣ",
      "hiPurpose": "कोलेस्ट्रॉल नियंत्रण",
    },
    "ecosprin75": {
      "composition": "Enteric-coated Aspirin IP (75 mg)",
      "purpose": "Low-dose blood thinner to prevent blood clots, heart attack, and stroke",
      "knPurpose": "ರಕ್ತ ಹೆಪ್ಪುಗಟ್ಟುವುದನ್ನು ತಡೆದು ಹೃದಯಾಘಾತ ಮತ್ತು ಪಾರ್ಶ್ವವಾಯು ತಡೆಗಟ್ಟಲು",
      "hiPurpose": "खून के थक्कों, हार्ट अटैक और स्ट्रोक से बचाव के लिए",
    },
    "ecosprin150": {
      "composition": "Enteric-coated Aspirin IP (150 mg)",
      "purpose": "Blood thinner for cardiovascular protection",
      "knPurpose": "ರಕ್ತ ತಿಳಿಯಾಗಿಸಿ ಹೃದಯ ರಕ್ಷಣೆ",
      "hiPurpose": "हार्ट अटैक और स्ट्रोक से बचाव",
    },
    "ecosprin": {
      "composition": "Enteric-coated Aspirin IP",
      "purpose": "Blood thinner to prevent blood clots and protect heart",
      "knPurpose": "ರಕ್ತ ತಿಳಿಯಾಗಿಸಿ ಹೃದಯ ರಕ್ಷಣೆ",
      "hiPurpose": "खून पतला करने और हृदय सुरक्षा के लिए",
    },

    // Allergy & Respiratory
    "cetzine": {
      "composition": "Cetirizine Hydrochloride IP (10 mg)",
      "purpose": "Allergy relief for sneezing, runny nose, watery eyes, and itching",
      "knPurpose": "ಅಲರ್ಜಿ, ಸೀನು, ನೆಗಡಿ, ಕಣ್ಣಿನಲ್ಲಿ ನೀರು ಮತ್ತು ತುರಿಕೆ ನಿವಾರಣೆ",
      "hiPurpose": "एलर्जी, छींक, बहती नाक और खुजली से राहत",
    },
    "alerid": {
      "composition": "Cetirizine Hydrochloride IP (10 mg)",
      "purpose": "Relieves cold, sneezing, runny nose, and allergic hives",
      "knPurpose": "ಅಲರ್ಜಿ, ಸೀನು ಮತ್ತು ನೆಗಡಿ ನಿವಾರಣೆ",
      "hiPurpose": "एलर्जी और जुकाम से राहत",
    },
    "cetirizine": {
      "composition": "Cetirizine Hydrochloride IP",
      "purpose": "Antihistamine for allergies, cold symptoms, and itchy skin",
      "knPurpose": "ಅಲರ್ಜಿ ಮತ್ತು ನೆಗಡಿ ನಿವಾರಣೆ",
      "hiPurpose": "एलर्जी, छींक और खुजली से राहत",
    },
    "levocet": {
      "composition": "Levocetirizine Dihydrochloride IP (5 mg)",
      "purpose": "Effective anti-allergic for sneezing, nasal congestion, and hives",
      "knPurpose": "ಅಲರ್ಜಿ, ಸೀನು ಮತ್ತು ಮೂಗು ಕಟ್ಟುವಿಕೆ ನಿವಾರಣೆ",
      "hiPurpose": "एलर्जी, छींक और बंद नाक से राहत",
    },
    "levocetirizine": {
      "composition": "Levocetirizine Dihydrochloride IP",
      "purpose": "Anti-allergic medication for allergic rhinitis and skin hives",
      "knPurpose": "ಅಲರ್ಜಿ ನಿವಾರಣೆ",
      "hiPurpose": "एलर्जी से राहत",
    },
    "montairlc": {
      "composition": "Montelukast Sodium (10 mg) + Levocetirizine (5 mg)",
      "purpose": "Relief from allergic rhinitis, asthma symptoms, and chronic sneezing",
      "knPurpose": "ಅಲರ್ಜಿ, ಉಬ್ಬಸ, ಸೀನು ಮತ್ತು ಕೆಮ್ಮು ನಿವಾರಣೆ",
      "hiPurpose": "एलर्जी, छींक, दमा के लक्षण और खांसी से राहत",
    },
    "monteklc": {
      "composition": "Montelukast Sodium (10 mg) + Levocetirizine (5 mg)",
      "purpose": "Relief from allergies, sneezing, and breathing discomfort",
      "knPurpose": "ಅಲರ್ಜಿ ಮತ್ತು ಉಸಿರಾಟದ ತೊಂದರೆ ನಿವಾರಣೆ",
      "hiPurpose": "एलर्जी और सांस की तकलीफ से राहत",
    },
    "allegra120": {
      "composition": "Fexofenadine Hydrochloride IP (120 mg)",
      "purpose": "Non-drowsy allergy relief for seasonal hay fever and skin rashes",
      "knPurpose": "ನಿದ್ದೆ ಬಾರದ ಅಲರ್ಜಿ, ಸೀನು ಮತ್ತು ಚರ್ಮದ ತುರಿಕೆ ನಿವಾರಣೆ",
      "hiPurpose": "बिना सुस्ती वाली एलर्जी, छींक और खुजली से राहत",
    },
    "allegra": {
      "composition": "Fexofenadine Hydrochloride IP (120 mg)",
      "purpose": "Non-drowsy relief from allergic rhinitis and itching",
      "knPurpose": "ಅಲರ್ಜಿ ಮತ್ತು ಸೀನು ನಿವಾರಣೆ",
      "hiPurpose": "एलर्जी और छींक से राहत",
    },
    "fexofenadine": {
      "composition": "Fexofenadine Hydrochloride IP",
      "purpose": "Non-drowsy antihistamine for allergy symptoms",
      "knPurpose": "ಅಲರ್ಜಿ ನಿವಾರಣೆ",
      "hiPurpose": "एलर्जी से राहत",
    },
    "ascorills": {
      "composition": "Levosalbutamol + Ambroxol + Guaifenesin",
      "purpose": "Cough syrup to thin mucus, clear chest congestion, and ease breathing",
      "knPurpose": "ಕಫ ಕರಗಿಸಿ ಕೆಮ್ಮು ಮತ್ತು ಎದೆ ಬಿಗಿತ ನಿವಾರಿಸಲು ಕೆಮ್ಮಿನ ಸಿರಪ್",
      "hiPurpose": "कफ को पतला करने, खांसी और सीने की जकड़न से राहत का सिरप",
    },
    "ascoril": {
      "composition": "Levosalbutamol + Ambroxol + Guaifenesin",
      "purpose": "Relieves chest congestion, wet cough, and airway constriction",
      "knPurpose": "ಕಫ ಮತ್ತು ಕೆಮ್ಮು ನಿವಾರಕ ಸಿರಪ್",
      "hiPurpose": "खांसी और कफ से राहत का सिरप",
    },
    "benadryl": {
      "composition": "Diphenhydramine HCl + Ammonium Chloride",
      "purpose": "Cough syrup to suppress dry cough and soothe throat irritation",
      "knPurpose": "ಒಣ ಕೆಮ್ಮು ಮತ್ತು ಗಂಟಲು ಕಿರಿಕಿರಿ ನಿವಾರಕ ಸಿರಪ್",
      "hiPurpose": "सूखी खांसी और गले की खराश से राहत का सिरप",
    },
    "chestoncold": {
      "composition": "Paracetamol (325 mg) + Phenylephrine (5 mg) + Chlorpheniramine (2 mg)",
      "purpose": "Comprehensive relief from severe cold, headache, blocked nose, and fever",
      "knPurpose": "ನೆಗಡಿ, ಮೂಗು ಕಟ್ಟುವಿಕೆ, ತಲೆನೋವು ಮತ್ತು ಜ್ವರ ನಿವಾರಣೆ",
      "hiPurpose": "जुकाम, बंद नाक, सिरदर्द और बुखार से राहत",
    },

    // Vitamins, Minerals & Supplements
    "shelcal500": {
      "composition": "Calcium Carbonate (500 mg elemental Calcium) + Vitamin D3 (250 IU)",
      "purpose": "Strengthens bones and teeth, treats calcium and vitamin D deficiency",
      "knPurpose": "ಮೂಳೆ ಮತ್ತು ಹಲ್ಲುಗಳ ಬಲವರ್ಧನೆ, ಕ್ಯಾಲ್ಸಿಯಂ ಪೂರಕ",
      "hiPurpose": "हड्डियों और दांतों की मजबूती, कैल्शियम की पूर्ति",
    },
    "shelcal": {
      "composition": "Calcium + Vitamin D3",
      "purpose": "Bone health and calcium supplement",
      "knPurpose": "ಕ್ಯಾಲ್ಸಿಯಂ ಮತ್ತು ಮೂಳೆಗಳ ಆರೋಗ್ಯ ಪೂರಕ",
      "hiPurpose": "कैल्शियम और हड्डियों के स्वास्थ्य के लिए",
    },
    "becosulesz": {
      "composition": "Vitamin B-Complex + Vitamin C + Zinc Sulphate",
      "purpose": "Restores energy, heals mouth ulcers, and treats vitamin deficiency",
      "knPurpose": "ಬಾಯಿ ಹುಣ್ಣು ನಿವಾರಣೆ, ಶಕ್ತಿ ವೃದ್ಧಿ ಮತ್ತು ವಿಟಮಿನ್ ಪೂರಕ",
      "hiPurpose": "मुंह के छालों, कमजोरी और विटामिन की कमी को दूर करने के लिए",
    },
    "becosules": {
      "composition": "Vitamin B-Complex + Vitamin C",
      "purpose": "Boosts energy, heals tissue, and treats vitamin B deficiency",
      "knPurpose": "ವಿಟಮಿನ್-ಬಿ ಪೂರಕ ಮತ್ತು ಬಾಯಿ ಹುಣ್ಣು ನಿವಾರಣೆ",
      "hiPurpose": "विटामिन बी सप्लीमेंट और छालों से राहत",
    },
    "neurobionforte": {
      "composition": "Vitamin B1 + B2 + B3 + B5 + B6 + B12 (Cyanocobalamin)",
      "purpose": "Restores nerve health, treats numbness, tingling, and nerve pain",
      "knPurpose": "ನರಗಳ ದೌರ್ಬಲ್ಯ, ಮರಗಟ್ಟುವಿಕೆ ಮತ್ತು ಜುಮುಗುಡುವಿಕೆ ನಿವಾರಣೆ",
      "hiPurpose": "नसों की कमजोरी, सुन्नपन और झनझनाहट से राहत",
    },
    "neurobion": {
      "composition": "Vitamin B-Complex (B1, B6, B12)",
      "purpose": "Nourishes nerve cells and treats diabetic neuropathy",
      "knPurpose": "ನರಗಳ ಆರೋಗ್ಯ ಪೂರಕ",
      "hiPurpose": "नसों के पोषण के लिए",
    },
    "limcee500": {
      "composition": "Vitamin C / Ascorbic Acid (500 mg)",
      "purpose": "Immunity booster, antioxidant, and tissue repair supplement",
      "knPurpose": "ರೋಗನಿರೋಧಕ ಶಕ್ತಿ ವೃದ್ಧಿ ಮತ್ತು ವಿಟಮಿನ್-ಸಿ ಪೂರಕ",
      "hiPurpose": "इम्यूनिटी बढ़ाने और विटामिन सी की पूर्ति के लिए",
    },
    "limcee": {
      "composition": "Vitamin C (500 mg)",
      "purpose": "Boosts immune defense and skin health",
      "knPurpose": "ವಿಟಮಿನ್-ಸಿ ಪೂರಕ",
      "hiPurpose": "विटामिन सी सप्लीमेंट",
    },
    "celin500": {
      "composition": "Vitamin C / Ascorbic Acid (500 mg)",
      "purpose": "Immunity enhancer and antioxidant",
      "knPurpose": "ರೋಗನಿರೋಧಕ ಶಕ್ತಿ ಮತ್ತು ವಿಟಮಿನ್-ಸಿ",
      "hiPurpose": "इम्यूनिटी बूस्टर",
    },
    "evion400": {
      "composition": "Vitamin E / Tocopheryl Acetate (400 mg)",
      "purpose": "Antioxidant for muscle cramps, skin nourishment, and cellular health",
      "knPurpose": "ಸ್ನಾಯು ಸೆಳೆತ ನಿವಾರಣೆ, ಚರ್ಮದ ಕಾಂತಿ ಮತ್ತು ವಿಟಮಿನ್-ಇ",
      "hiPurpose": "मांसपेशियों के दर्द, त्वचा और विटामिन ई के लिए",
    },
    "evion": {
      "composition": "Vitamin E (400 mg)",
      "purpose": "Vitamin E supplement for muscles and skin",
      "knPurpose": "ವಿಟಮಿನ್-ಇ ಪೂರಕ",
      "hiPurpose": "विटामिन ई सप्लीमेंट",
    },

    // Topical & Antiseptics
    "betadine": {
      "composition": "Povidone-Iodine IP (5% w/w)",
      "purpose": "Antiseptic for minor cuts, wounds, burns, and skin infection prevention",
      "knPurpose": "ಗಾಯ, ಸುಟ್ಟ ಗಾಯ ಮತ್ತು ಕಡಿತಗಳಿಗೆ ಆಂಟಿಸೆಪ್ಟಿಕ್ ಮುಲಾಮು",
      "hiPurpose": "घाव, कटने और जलने पर इन्फेक्शन रोकने वाला एंटीसेप्टिक",
    },
    "volini": {
      "composition": "Diclofenac Diethylamine + Methyl Salicylate + Menthol",
      "purpose": "Fast relief from joint pain, backache, neck pain, and muscle sprains",
      "knPurpose": "ಮೈ-ಕೈ ನೋವು, ಬೆನ್ನು ನೋವು ಮತ್ತು ಉಳುಕಿಗೆ ಶೀಘ್ರ ಮುಲಾಮು",
      "hiPurpose": "कमर दर्द, जोड़ों के दर्द और मोच से त्वरित राहत",
    },
    "moov": {
      "composition": "Wintergreen Oil + Mint Extract + Turpentine Oil + Eucalyptus Oil",
      "purpose": "Warmth and quick relief from backache and muscle pain",
      "knPurpose": "ಬೆನ್ನು ನೋವು ಮತ್ತು ಸ್ನಾಯು ನೋವು ನಿವಾರಕ ಮುಲಾಮು",
      "hiPurpose": "कमर दर्द और मांसपेशियों के दर्द से राहत",
    },
  };

  /// Extract raw text from an image file using Google ML Kit on-device OCR with fallback
  Future<String> extractRawText(File imageFile) async {
    if (kIsWeb) {
      debugPrint("ML Kit OCR is not available directly on Web.");
      return "";
    }

    try {
      debugPrint("Starting ML Kit OCR on image: ${imageFile.path}");
      final inputImage = InputImage.fromFilePath(imageFile.path);
      TextRecognizer textRecognizer;
      try {
        textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      } catch (_) {
        textRecognizer = TextRecognizer();
      }

      var recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      var text = recognizedText.text.trim();

      // If latin recognizer found nothing, attempt with generic script recognizer
      if (text.isEmpty) {
        try {
          final genericRecognizer = TextRecognizer();
          recognizedText = await genericRecognizer.processImage(inputImage);
          await genericRecognizer.close();
          text = recognizedText.text.trim();
        } catch (_) {}
      }

      debugPrint("ML Kit OCR extracted ${text.length} characters.");
      if (text.isNotEmpty) {
        debugPrint("Extracted OCR snippet: ${text.substring(0, text.length > 300 ? 300 : text.length).replaceAll('\n', ' ')}");
      }
      return text;
    } catch (e) {
      debugPrint("ML Kit OCR processing error: $e");
      return "";
    }
  }

  /// Parses raw OCR text into structured medicine packaging data
  Map<String, dynamic> parseMedicineText(String rawText, {String? language}) {
    if (rawText.trim().isEmpty) {
      return _generateEmptyResult(language);
    }

    final lines = rawText
        .split(RegExp(r'[\r\n]+'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    // 1. Extract Strength
    final strength = _extractStrength(rawText);

    // 2. Extract Pharmaceutical Form
    final form = _extractForm(rawText);

    // 3. Extract Medicine Name
    final name = _extractMedicineName(lines, rawText, strength, form);

    // 4. Extract Composition (Active Ingredients / What is available in the medicine)
    final composition = _extractComposition(lines, rawText, name, strength);

    // 5. Extract Purpose / Indication
    final purpose = _extractPurpose(name, composition, rawText, language: language);

    // 6. Extract Expiry Date
    final expiryDate = _extractExpiryDate(rawText);

    // 7. Extract Instructions
    final instructions = _extractInstructions(rawText, form);

    // 8. Generate Dosage
    final dosage = _extractDosage(rawText, form);

    // 9. Calculate confidence
    String confidence = "high";
    if (name.isEmpty || name == "Medicine") {
      confidence = "low";
    } else if (expiryDate.isEmpty) {
      confidence = "medium";
    }

    // 10. Generate spoken summary
    final spokenSummary = _generateMedicineSpokenSummary(
      name: name,
      strength: strength,
      form: form,
      composition: composition,
      purpose: purpose,
      expiryDate: expiryDate,
      instructions: instructions,
      dosage: dosage,
      language: language,
    );

    return {
      "name": name.isNotEmpty ? name : "Medicine",
      "dosage": dosage,
      "form": form.isNotEmpty ? form : "Tablet",
      "strength": strength,
      "composition": composition,
      "purpose": purpose,
      "expiry_date": expiryDate,
      "instructions": instructions,
      "scanned_text": rawText,
      "confidence": confidence,
      "spoken_summary": spokenSummary,
    };
  }

  /// Extracts strength (e.g. "650 mg", "500 mg", "40 mg", "5 ml", "0.5% w/w")
  String _extractStrength(String text) {
    // 1. Dual strengths e.g. "500 mg / 125 mg" or "500mg + 125mg"
    final dualMatch = RegExp(
      r'(\d+(?:\.\d+)?\s*(?:mg|g|mcg|µg|ml)\s*[\/\+]\s*\d+(?:\.\d+)?\s*(?:mg|g|mcg|µg|ml))',
      caseSensitive: false,
    ).firstMatch(text);
    if (dualMatch != null) {
      return dualMatch.group(1)!.replaceAll(RegExp(r'\s+'), ' ').trim();
    }

    // 2. Percentage strengths e.g. "5% w/w", "0.3% w/v", "2%"
    final percentMatch = RegExp(
      r'(\d+(?:\.\d+)?\s*%\s*(?:w\/w|w\/v|v\/v)?)',
      caseSensitive: false,
    ).firstMatch(text);
    if (percentMatch != null) {
      return percentMatch.group(1)!.trim();
    }

    // 3. Single standard strength e.g. "650 mg", "500mg", "40 mg", "2.5 mg", "100 ml"
    final singleMatch = RegExp(
      r'(\b\d+(?:\.\d+)?\s*(?:mg|g|mcg|µg|ml|iu)\b)',
      caseSensitive: false,
    ).firstMatch(text);
    if (singleMatch != null) {
      return singleMatch.group(1)!.trim();
    }

    // 4. Numbers attached to brand like "Dolo 650" or "Pan 40"
    final attachedMatch = RegExp(
      r'(?:dolo|pan|calpol|crocin|azithral|shelcal|augmentin|cetzine|omez)\s*(\d{2,4})\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (attachedMatch != null) {
      return "${attachedMatch.group(1)} mg";
    }

    return "";
  }

  /// Extracts dosage amount
  String _extractDosage(String text, String form) {
    final match = RegExp(
      r'\b(?:(?:take|instill|apply)\s+)?(\d+(?:\s*(?:to|-)\s*\d+)?|\b(?:one|two|half)\b)\s*(tablet|capsule|spoon|drop|puff)s?\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (match != null) {
      final amount = match.group(1)!.trim();
      final unit = match.group(2)!.trim();
      final isPlural = amount.contains('to') || amount.contains('-') || (amount != '1' && amount != 'one');
      return "$amount $unit${isPlural ? 's' : ''}";
    }
    if (form == "Capsule") return "1 capsule";
    if (form == "Syrup") return "5 to 10 ml";
    if (form == "Drops") return "1 to 2 drops";
    if (form == "Inhaler") return "1 to 2 puffs";
    if (form == "Cream / Ointment") return "Thin layer";
    return "1 tablet";
  }

  /// Extracts pharmaceutical form
  String _extractForm(String text) {
    final lower = text.toLowerCase();
    if (lower.contains("capsule") || lower.contains("cap.")) return "Capsule";
    if (lower.contains("syrup") || lower.contains("suspension") || lower.contains("elixir") || lower.contains("syr.")) return "Syrup";
    if (lower.contains("eye drop") || lower.contains("ear drop") || lower.contains("drops")) return "Drops";
    if (lower.contains("ointment") || lower.contains("gel") || lower.contains("cream") || lower.contains("lotion")) return "Cream / Ointment";
    if (lower.contains("inhaler") || lower.contains("rotacap") || lower.contains("respules") || lower.contains("spray")) return "Inhaler";
    if (lower.contains("injection") || lower.contains("inj.") || lower.contains("vial") || lower.contains("ampoule")) return "Injection";
    if (lower.contains("tablet") || lower.contains("tab.") || lower.contains("tab")) return "Tablet";
    return "Tablet";
  }

  /// Extracts medicine brand name or active drug name
  String _extractMedicineName(List<String> lines, String fullText, String strength, String form) {
    final candidates = <Map<String, dynamic>>[];

    // 1. Match known medicines and rank by line position & specificity
    for (final known in _knownMedicines) {
      final reg = RegExp(r'\b' + RegExp.escape(known) + r'\b', caseSensitive: false);
      final match = reg.firstMatch(fullText);
      if (match != null) {
        int lineIndex = 999;
        for (int i = 0; i < lines.length; i++) {
          if (reg.hasMatch(lines[i])) {
            lineIndex = i;
            break;
          }
        }
        candidates.add({
          'name': known,
          'index': match.start,
          'line': lineIndex,
          'length': known.length,
          'hasNumber': RegExp(r'\d').hasMatch(known),
          'isBrand': _brandMedicines.contains(known),
        });
      }
    }

    if (candidates.isNotEmpty) {
      candidates.sort((a, b) {
        // 1. Proprietary Brand Names (e.g. Fever-X 650, Doxinate, Dolo 650) preferred over generic salts
        final isBrandA = a['isBrand'] == true ? 1 : 0;
        final isBrandB = b['isBrand'] == true ? 1 : 0;
        if (isBrandB != isBrandA) return isBrandB.compareTo(isBrandA);

        // 2. Names with numbers (e.g. Fever-X 650, Dolo 650, Pan 40) preferred
        final numA = a['hasNumber'] == true ? 1 : 0;
        final numB = b['hasNumber'] == true ? 1 : 0;
        if (numB != numA) return numB.compareTo(numA);

        // 3. Line number on packaging
        final lineDiff = (a['line'] as int).compareTo(b['line'] as int);
        if (lineDiff != 0) return lineDiff;

        // 4. Longer / more specific name preferred
        final lenDiff = (b['length'] as int).compareTo(a['length'] as int);
        if (lenDiff != 0) return lenDiff;

        return (a['index'] as int).compareTo(b['index'] as int);
      });
      return candidates.first['name'] as String;
    }

    // 2. Look for Pharmacopoeia Generic Name lines:
    // e.g. "Paracetamol Tablets IP", "Doxylamine Succinate & Pyridoxine Hydrochloride Tablets", "Pantoprazole Gastro-resistant Tablets IP"
    final ipMatch = RegExp(
      r'([A-Za-z0-9\s\-\+\&\,]+?)\s+(?:Tablets|Capsules|Syrup|Injection|Suspension|Drops|Gel|Ointment)\s*(?:IP|BP|USP)?',
      caseSensitive: false,
    ).firstMatch(fullText);
    if (ipMatch != null) {
      final matchedName = ipMatch.group(1)!.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
      if (matchedName.length >= 3 && matchedName.length <= 50 && !_isBoilerplate(matchedName)) {
        return matchedName;
      }
    }

    // 3. Look for "Each ... tablet contains: [Compound Name] IP"
    final compMatch = RegExp(
      r'(?:contains[:\s]+|eq\.\s*to\s+)([A-Za-z\s\-]+?)\s+(?:IP|BP|USP|\d)',
      caseSensitive: false,
    ).firstMatch(fullText);
    if (compMatch != null) {
      final matchedName = compMatch.group(1)!.trim();
      if (matchedName.length >= 3 && matchedName.length <= 35 && !_isBoilerplate(matchedName)) {
        return matchedName;
      }
    }

    // 4. Look for prominent Brand Pattern (e.g. "DOLO 650", "FEVER-X 650", "PAN 40", "AUGMENTIN 625")
    final brandWithNum = RegExp(
      r'\b([A-Z][A-Za-z0-9\-]{2,15})\s*[\-]?\s*(\d{2,4})\b',
    ).firstMatch(fullText);
    if (brandWithNum != null) {
      final brand = brandWithNum.group(1)!.trim();
      final num = brandWithNum.group(2)!.trim();
      if (!_isBoilerplate(brand)) {
        return "$brand $num";
      }
    }

    // 5. Inspect lines near top, filtering out boilerplate
    for (int i = 0; i < lines.length && i < 8; i++) {
      final line = lines[i].trim();
      if (line.length < 3 || line.length > 35) continue;
      if (_isBoilerplate(line)) continue;

      // Clean special characters
      final clean = line.replaceAll(RegExp(r'[^a-zA-Z0-9\s\-\.]'), '').trim();
      if (clean.length >= 3 && RegExp(r'[a-zA-Z]').hasMatch(clean)) {
        // If it starts with Tab. or Cap.
        final prefixMatch = RegExp(r'^(?:tab|cap|syr)\.?\s*(.+)', caseSensitive: false).firstMatch(clean);
        if (prefixMatch != null) {
          return prefixMatch.group(1)!.trim();
        }
        return clean;
      }
    }

    // Fallback: Default to medicine + strength
    if (strength.isNotEmpty) {
      return "Medicine $strength";
    }
    return "Medicine";
  }

  bool _isBoilerplate(String text) {
    final lower = text.toLowerCase();
    for (final bp in _boilerplateLines) {
      if (lower.contains(bp)) return true;
    }
    return false;
  }

  /// Normalizes brand or generic name into alphanumeric key for database lookup
  String _normalizeKey(String s) {
    return s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  /// Cleans and sanitizes raw composition text by stripping excipients and manufacturing boilerplate
  String _cleanComposition(String comp) {
    var cleaned = comp.trim();
    cleaned = cleaned.replaceAll(RegExp(r'^[:\-\s]+'), '');
    cleaned = cleaned.replaceAll(RegExp(r'(?:excipients\s*q\.?s\.?|colour:?|color:?|titanium\s*dioxide|sunset\s*yellow|lake\s*of\s*tartrazine|dosage:?|as\s*directed|storage:?|store\s*below).*', caseSensitive: false), '').trim();
    cleaned = cleaned.replaceAll(RegExp(r'[\s,;\.\-]+$'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleaned;
  }

  /// Extracts active ingredients (composition) available in the medicine
  String _extractComposition(List<String> lines, String rawText, String matchedName, String strength) {
    // 1. Look for explicit packaging patterns in rawText:
    // e.g. "Each uncoated tablet contains: Paracetamol IP 650 mg"
    final containsMatch = RegExp(
      r'(?:each\s+(?:[a-z\-]+\s+)?(?:tablet|capsule|5ml|ml)\s+contains[:\s]+|contains[:\s]+|composition[:\s]+)(.+?)(?=\.|\n|dosage|storage|mfg|exp|keep|warning|caution|batch|lic|mrp|pkg|marketed|manufactured|pvt|ltd|$)',
      caseSensitive: false,
    ).firstMatch(rawText);
    if (containsMatch != null) {
      String comp = containsMatch.group(1)!.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
      comp = _cleanComposition(comp);
      if (comp.length >= 4 && !_isBoilerplate(comp)) {
        return comp;
      }
    }

    // 2. Look for Pharmacopoeia IP/BP/USP line:
    // e.g. "Paracetamol Tablets IP 650 mg", "Amoxycillin and Potassium Clavulanate Tablets IP"
    final ipMatch = RegExp(
      r'([A-Za-z0-9\s\-\+\&\,]+?)\s+(?:Tablets|Capsules|Syrup|Injection|Suspension|Drops|Gel|Ointment)\s*(?:IP|BP|USP)',
      caseSensitive: false,
    ).firstMatch(rawText);
    if (ipMatch != null) {
      String comp = ipMatch.group(1)!.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
      comp = _cleanComposition(comp);
      if (comp.length >= 4 && !_isBoilerplate(comp)) {
        return comp;
      }
    }

    // 3. Fallback to Medical Knowledge Dictionary by matched medicine key
    final key = _normalizeKey(matchedName);
    if (_medicineDatabase.containsKey(key)) {
      return _medicineDatabase[key]!['composition'] ?? "";
    }

    for (final entry in _medicineDatabase.entries) {
      if (key.contains(entry.key) || entry.key.contains(key)) {
        return entry.value['composition'] ?? "";
      }
    }

    // 4. If medicine name has generic drug ingredient (e.g. Paracetamol)
    if (matchedName.isNotEmpty && matchedName != "Medicine") {
      final strSuffix = strength.isNotEmpty ? " ($strength)" : "";
      return "$matchedName$strSuffix";
    }

    return "";
  }

  /// Extracts the therapeutic purpose / medical indication of the medicine
  String _extractPurpose(String matchedName, String composition, String rawText, {String? language}) {
    final key = _normalizeKey(matchedName);
    final lang = language ?? 'en-US';

    // 1. Direct dictionary lookup
    Map<String, String>? info = _medicineDatabase[key];
    if (info == null) {
      for (final entry in _medicineDatabase.entries) {
        if (key.contains(entry.key) || entry.key.contains(key)) {
          info = entry.value;
          break;
        }
      }
    }

    if (info != null) {
      if (lang.startsWith('kn') && info['knPurpose'] != null && info['knPurpose']!.isNotEmpty) {
        return info['knPurpose']!;
      }
      if (lang.startsWith('hi') && info['hiPurpose'] != null && info['hiPurpose']!.isNotEmpty) {
        return info['hiPurpose']!;
      }
      return info['purpose'] ?? "";
    }

    // 2. Clinical class heuristics
    final combined = "$matchedName $composition $rawText".toLowerCase();
    if (combined.contains("paracetamol") || combined.contains("ibuprofen") || combined.contains("aceclofenac") || combined.contains("diclofenac")) {
      return lang.startsWith('kn') ? "ಜ್ವರ ಮತ್ತು ನೋವು ನಿವಾರಣೆ" : lang.startsWith('hi') ? "बुखार और दर्द से राहत" : "Fever and pain relief";
    }
    if (combined.contains("amoxicillin") || combined.contains("azithromycin") || combined.contains("cefixime") || combined.contains("ciprofloxacin") || combined.contains("ofloxacin")) {
      return lang.startsWith('kn') ? "ಬ್ಯಾಕ್ಟೀರಿಯಾ ಸೋಂಕು ನಿವಾರಕ ಆಂಟಿಬಯೋಟಿಕ್" : lang.startsWith('hi') ? "बैक्टीरियल संक्रमण के इलाज के लिए एंटीबायोटिक" : "Antibiotic for bacterial infections";
    }
    if (combined.contains("pantoprazole") || combined.contains("omeprazole") || combined.contains("rabeprazole") || combined.contains("esomeprazole")) {
      return lang.startsWith('kn') ? "ಅಸಿಡಿಟಿ ಮತ್ತು ಎದೆಯುರಿ ನಿವಾರಣೆ" : lang.startsWith('hi') ? "एसिडिटी और सीने में जलन से राहत" : "Acidity and heartburn relief";
    }
    if (combined.contains("metformin") || combined.contains("glimepiride") || combined.contains("vildagliptin") || combined.contains("dapagliflozin")) {
      return lang.startsWith('kn') ? "ಮಧುಮೇಹದಲ್ಲಿ ರಕ್ತದ ಸಕ್ಕರೆ ನಿಯಂತ್ರಣ" : lang.startsWith('hi') ? "डायबिटीज में ब्लड शुगर का नियंत्रण" : "Blood sugar control for diabetes";
    }
    if (combined.contains("telmisartan") || combined.contains("amlodipine") || combined.contains("atenolol") || combined.contains("losartan")) {
      return lang.startsWith('kn') ? "ರಕ್ತದೊತ್ತಡ (BP) ನಿಯಂತ್ರಣ" : lang.startsWith('hi') ? "ब्लड प्रेशर (बीपी) नियंत्रण" : "Blood pressure control";
    }
    if (combined.contains("atorvastatin") || combined.contains("rosuvastatin")) {
      return lang.startsWith('kn') ? "ಕೊಲೆಸ್ಟ್ರಾಲ್ ನಿಯಂತ್ರಣ ಮತ್ತು ಹೃದಯ ರಕ್ಷಣೆ" : lang.startsWith('hi') ? "कोलेस्ट्रॉल का नियंत्रण और हृदय सुरक्षा" : "Cholesterol control and heart protection";
    }
    if (combined.contains("cetirizine") || combined.contains("levocetirizine") || combined.contains("fexofenadine") || combined.contains("montelukast")) {
      return lang.startsWith('kn') ? "ಅಲರ್ಜಿ, ಸೀನು ಮತ್ತು ನೆಗಡಿ ನಿವಾರಣೆ" : lang.startsWith('hi') ? "एलर्जी, छींक और जुकाम से राहत" : "Allergy, cold, and sneezing relief";
    }

    return "";
  }

  /// Extracts Expiry Date and standardizes to YYYY-MM-DD
  String _extractExpiryDate(String text) {
    if (text.trim().isEmpty) return "";

    // Normalize OCR confusion: letter 'O'/'o' inside numbers to '0'
    final normalizedText = text.replaceAllMapped(
      RegExp(r'(?<=\d)[Oo](?=\d)|(?<=\b[Ee][Xx][Pp][:\s\.\-]*)[Oo](?=\d)'),
      (m) => '0',
    );

    final monthNames = {
      "jan": 1, "feb": 2, "mar": 3, "apr": 4, "may": 5, "jun": 6,
      "jul": 7, "aug": 8, "sep": 9, "oct": 10, "nov": 11, "dec": 12,
      "january": 1, "february": 2, "march": 3, "april": 4, "june": 6,
      "july": 7, "august": 8, "september": 9, "october": 10, "november": 11, "december": 12
    };

    final prefix = r'(?:exp(?:\.|\b)|expiry|exp\.?\s*d(?:a)?t(?:e)?|use\s*before|use\s*by|best\s*before|valid\s*till|valid\s*upto|e\.?d\.?)';

    // 1. Day / Month / Year with prefix: e.g. EXP. 15/08/2026 or 15-08-26 or 15.08.2026
    final dmyMatch = RegExp(
      prefix + r'[:\s\.\-]*([0-3]?\d)\s*[\/\-\.]\s*(0?[1-9]|1[0-2])\s*[\/\-\.]\s*(20\d{2}|\d{2})\b',
      caseSensitive: false,
    ).firstMatch(normalizedText);
    if (dmyMatch != null) {
      final day = int.tryParse(dmyMatch.group(1)!);
      final month = int.tryParse(dmyMatch.group(2)!);
      int? year = int.tryParse(dmyMatch.group(3)!);
      if (year != null && year < 100) year += 2000;
      if (day != null && month != null && year != null && day >= 1 && day <= 31 && month >= 1 && month <= 12 && year >= 2020 && year <= 2045) {
        final mStr = month < 10 ? "0$month" : "$month";
        final dStr = day < 10 ? "0$day" : "$day";
        return "$year-$mStr-$dStr";
      }
    }

    // 2. Month / Year with prefix: e.g. EXP: 11/2026 or EXP 05 / 2026 or EXP.DT: 08/2027 or EXP. 12-26
    final myMatch = RegExp(
      prefix + r'[:\s\.\-]*([0-1]?\d)\s*[\/\-\.]\s*(20\d{2}|\d{2})\b',
      caseSensitive: false,
    ).firstMatch(normalizedText);
    if (myMatch != null) {
      final month = int.tryParse(myMatch.group(1)!);
      int? year = int.tryParse(myMatch.group(2)!);
      if (year != null && year < 100) year += 2000;
      if (month != null && month >= 1 && month <= 12 && year != null && year >= 2020 && year <= 2045) {
        final lastDay = DateTime(year, month + 1, 0).day;
        final mStr = month < 10 ? "0$month" : "$month";
        final dStr = lastDay < 10 ? "0$lastDay" : "$lastDay";
        return "$year-$mStr-$dStr";
      }
    }

    // 3. Year / Month with prefix: e.g. EXP: 2026/08 or EXP 2026-11
    final ymMatch = RegExp(
      prefix + r'[:\s\.\-]*(20\d{2})\s*[\/\-\.]\s*(0?[1-9]|1[0-2])\b',
      caseSensitive: false,
    ).firstMatch(normalizedText);
    if (ymMatch != null) {
      final year = int.tryParse(ymMatch.group(1)!);
      final month = int.tryParse(ymMatch.group(2)!);
      if (month != null && month >= 1 && month <= 12 && year != null && year >= 2020 && year <= 2045) {
        final lastDay = DateTime(year, month + 1, 0).day;
        final mStr = month < 10 ? "0$month" : "$month";
        final dStr = lastDay < 10 ? "0$lastDay" : "$lastDay";
        return "$year-$mStr-$dStr";
      }
    }

    // 4. Month name with prefix: e.g. EXP. NOV 2026 or EXP: DEC.26 or EXPIRY: AUG 2025
    final nameMatch = RegExp(
      prefix + r"[:\s\.\-]*([a-zA-Z]{3,9})[\s\.\-\/',]+(20\d{2}|\d{2})\b",
      caseSensitive: false,
    ).firstMatch(normalizedText);
    if (nameMatch != null) {
      final mName = nameMatch.group(1)!.toLowerCase();
      final month = monthNames[mName];
      int? year = int.tryParse(nameMatch.group(2)!);
      if (year != null && year < 100) year += 2000;
      if (month != null && year != null && year >= 2020 && year <= 2045) {
        final lastDay = DateTime(year, month + 1, 0).day;
        final mStr = month < 10 ? "0$month" : "$month";
        final dStr = lastDay < 10 ? "0$lastDay" : "$lastDay";
        return "$year-$mStr-$dStr";
      }
    }

    // 5. Date across newlines: e.g. EXP. DATE \n 11/2026
    final multilineMatch = RegExp(
      prefix + r'[\s\S]{1,20}?([0-1]?\d)\s*[\/\-\.]\s*(20\d{2}|\d{2})\b',
      caseSensitive: false,
    ).firstMatch(normalizedText);
    if (multilineMatch != null) {
      final month = int.tryParse(multilineMatch.group(1)!);
      int? year = int.tryParse(multilineMatch.group(2)!);
      if (year != null && year < 100) year += 2000;
      if (month != null && month >= 1 && month <= 12 && year != null && year >= 2020 && year <= 2045) {
        final lastDay = DateTime(year, month + 1, 0).day;
        final mStr = month < 10 ? "0$month" : "$month";
        final dStr = lastDay < 10 ? "0$lastDay" : "$lastDay";
        return "$year-$mStr-$dStr";
      }
    }

    // 6. General date that is NOT preceded by mfg / mfd (e.g. stamped edge on blister strip)
    final generalMatch = RegExp(
      r'(?<!(?:mfg|mfd)[^\n]{0,15})\b(0?[1-9]|1[0-2])\s*[\/\-]\s*(20[2-3]\d|[2-3]\d)\b',
      caseSensitive: false,
    ).firstMatch(normalizedText);
    if (generalMatch != null) {
      final month = int.tryParse(generalMatch.group(1)!);
      int? year = int.tryParse(generalMatch.group(2)!);
      if (year != null && year < 100) year += 2000;
      if (month != null && month >= 1 && month <= 12 && year != null && year >= 2024 && year <= 2045) {
        final lastDay = DateTime(year, month + 1, 0).day;
        final mStr = month < 10 ? "0$month" : "$month";
        final dStr = lastDay < 10 ? "0$lastDay" : "$lastDay";
        return "$year-$mStr-$dStr";
      }
    }

    return "";
  }

  /// Extracts instructions or provides clear safe guidance
  String _extractInstructions(String text, String form) {
    final lower = text.toLowerCase();
    final detected = <String>[];

    if (lower.contains("after food") || lower.contains("after meals") || lower.contains("p.c")) {
      detected.add("Take after meals with water.");
    } else if (lower.contains("before food") || lower.contains("before meals") || lower.contains("empty stomach") || lower.contains("a.c")) {
      detected.add("Take on an empty stomach with water.");
    }

    if (lower.contains("3 to 4 times") || lower.contains("four times") || lower.contains("4 times")) {
      detected.add("Take 3 to 4 times daily (minimum 4 hours interval).");
    } else if (lower.contains("twice daily") || lower.contains("b.d") || lower.contains("bid") || lower.contains("1-0-1")) {
      detected.add("Take twice daily (morning and night).");
    } else if (lower.contains("thrice daily") || lower.contains("three times") || lower.contains("t.d.s") || lower.contains("1-1-1")) {
      detected.add("Take three times daily.");
    } else if (lower.contains("once daily") || lower.contains("o.d") || lower.contains("1-0-0")) {
      detected.add("Take once daily in the morning.");
    } else if (lower.contains("bedtime") || lower.contains("at night") || lower.contains("h.s") || lower.contains("0-0-1")) {
      detected.add("Take once daily at bedtime.");
    }

    if (detected.isNotEmpty) {
      return detected.join(" ");
    }

    // Default safe medical advice tailored to pharmaceutical form
    if (form == "Capsule" || form == "Tablet") {
      return "Take 1 $form with a glass of water after food, as directed by your doctor.";
    } else if (form == "Syrup") {
      return "Shake well before use. Take 5 to 10 ml as directed by your physician.";
    } else if (form == "Drops") {
      return "Instill 1 to 2 drops as advised by your doctor.";
    } else if (form == "Cream / Ointment") {
      return "Apply gently to the affected area. For external use only.";
    } else if (form == "Inhaler") {
      return "Take 1 to 2 puffs using inhaler technique as prescribed.";
    }

    return "Take as directed by your physician or pharmacist.";
  }

  /// Generates spoken summary in the user's selected language announcing all extracted details clearly
  String _generateMedicineSpokenSummary({
    required String name,
    required String strength,
    required String form,
    required String expiryDate,
    required String instructions,
    String composition = "",
    String purpose = "",
    String? dosage,
    String? language,
  }) {
    final effectiveDose = (dosage != null && dosage.isNotEmpty) ? dosage : "1 $form";
    final strengthText = strength.isNotEmpty ? " $strength" : "";

    final monthNames = [
      "", "January", "February", "March", "April", "May", "June",
      "July", "August", "September", "October", "November", "December"
    ];
    final knMonthNames = [
      "", "ಜನವರಿ", "ಫೆಬ್ರವರಿ", "ಮಾರ್ಚ್", "ಏಪ್ರಿಲ್", "ಮೇ", "ಜೂನ್",
      "ಜುಲೈ", "ಆಗಸ್ಟ್", "ಸೆಪ್ಟೆಂಬರ್", "ಅಕ್ಟೋಬರ್", "ನವೆಂಬರ್", "ಡಿಸೆಂಬರ್"
    ];
    final hiMonthNames = [
      "", "जनवरी", "फरवरी", "मार्च", "अप्रैल", "मई", "जून",
      "जुलाई", "अगस्त", "सितंबर", "अक्टूबर", "नवंबर", "दिसंबर"
    ];

    String expNoticeEn;
    String expNoticeKn;
    String expNoticeHi;

    if (expiryDate.isNotEmpty) {
      try {
        final exp = DateTime.parse(expiryDate);
        final now = DateTime.now();
        final mName = (exp.month >= 1 && exp.month <= 12) ? monthNames[exp.month] : "";
        final knMName = (exp.month >= 1 && exp.month <= 12) ? knMonthNames[exp.month] : "";
        final hiMName = (exp.month >= 1 && exp.month <= 12) ? hiMonthNames[exp.month] : "";

        if (exp.isBefore(now)) {
          expNoticeEn = " Warning: This medicine expired in $mName ${exp.year}.";
          expNoticeKn = " ಎಚ್ಚರಿಕೆ: ಈ ಔಷಧಿಯ ಅವಧಿ $knMName ${exp.year} ನಲ್ಲಿ ಮುಗಿದಿದೆ.";
          expNoticeHi = " चेतावनी: इस दवा की समाप्ति तिथि $hiMName ${exp.year} में समाप्त हो चुकी है।";
        } else {
          expNoticeEn = " Expiry date is $mName ${exp.year}.";
          expNoticeKn = " ಮುಕ್ತಾಯ ದಿನಾಂಕ $knMName ${exp.year}.";
          expNoticeHi = " समाप्ति तिथि $hiMName ${exp.year} है।";
        }
      } catch (_) {
        expNoticeEn = " Expiry date is $expiryDate.";
        expNoticeKn = " ಮುಕ್ತಾಯ ದಿನಾಂಕ $expiryDate.";
        expNoticeHi = " समाप्ति तिथि $expiryDate है।";
      }
    } else {
      expNoticeEn = " Expiry date not visible on this photo. Tap the expiry box to set it.";
      expNoticeKn = " ಈ ಫೋಟೋದಲ್ಲಿ ಮುಕ್ತಾಯ ದಿನಾಂಕ ಕಾಣಿಸುತ್ತಿಲ್ಲ. ದಿನಾಂಕವನ್ನು ಆಯ್ಕೆ ಮಾಡಲು ಬಾಕ್ಸ್ ಟ್ಯಾಪ್ ಮಾಡಿ.";
      expNoticeHi = " इस फोटो पर समाप्ति तिथि दिखाई नहीं दे रही है। तारीख सेट करने के लिए बॉक्स पर टैप करें।";
    }

    String compNoticeEn = composition.isNotEmpty ? " Active ingredients: $composition." : "";
    String purposeNoticeEn = purpose.isNotEmpty ? " Used for $purpose." : "";

    String compNoticeKn = composition.isNotEmpty ? " ಇದರಲ್ಲಿ $composition ಇದೆ." : "";
    String purposeNoticeKn = purpose.isNotEmpty ? " $purpose ಗಾಗಿ ಬಳಸಲಾಗುತ್ತದೆ." : "";

    String compNoticeHi = composition.isNotEmpty ? " इसमें $composition मौजूद है।" : "";
    String purposeNoticeHi = purpose.isNotEmpty ? " $purpose के लिए प्रयोग किया जाता है।" : "";

    if (language == 'kn-IN') {
      return "ನಾನು $name$strengthText $form ಅನ್ನು ಓದಿದೆ.$compNoticeKn$purposeNoticeKn ಪ್ರಮಾಣ: $effectiveDose.$expNoticeKn $instructions";
    } else if (language == 'hi-IN') {
      return "मैंने $name$strengthText $form पढ़ा है।$compNoticeHi$purposeNoticeHi खुराक: $effectiveDose।$expNoticeHi $instructions";
    } else {
      return "I read $name$strengthText $form.$compNoticeEn$purposeNoticeEn Dose: $effectiveDose.$expNoticeEn $instructions";
    }
  }

  /// Parses Doctor's Prescription from raw OCR text
  Map<String, dynamic> parsePrescriptionText(String rawText, {String? language}) {
    if (rawText.trim().isEmpty) {
      return {
        "doctor_name": "",
        "extracted_text": "",
        "spoken_summary": language == 'kn-IN'
            ? "ಯಾವುದೇ ಪಠ್ಯ ಪತ್ತೆಯಾಗಿಲ್ಲ. ದಯವಿಟ್ಟು ಮತ್ತೊಮ್ಮೆ ಸ್ಪಷ್ಟವಾಗಿ ಫೋಟೋ ತೆಗೆಯಿರಿ."
            : language == 'hi-IN'
                ? "कोई पाठ नहीं मिला। कृपया अच्छी रोशनी में दोबारा फोटो लें।"
                : "No text found. Please take a clearer photo of the prescription.",
        "medicines": []
      };
    }

    final lines = rawText
        .split(RegExp(r'[\r\n]+'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    // 1. Doctor Name / Clinic
    String doctorName = "";
    for (final line in lines) {
      if (RegExp(r'(?:dr\.|doctor|m\.?b\.?b\.?s|m\.?d\.?|clinic|hospital)', caseSensitive: false).hasMatch(line)) {
        doctorName = line;
        break;
      }
    }

    // 2. Extract Medicines
    final List<Map<String, dynamic>> medicines = [];

    for (final line in lines) {
      String? bestKnown;
      for (final known in _knownMedicines) {
        if (RegExp(r'\b' + RegExp.escape(known) + r'\b', caseSensitive: false).hasMatch(line)) {
          if (bestKnown == null || known.length > bestKnown.length) {
            bestKnown = known;
          }
        }
      }

      if (bestKnown != null) {
        if (!medicines.any((m) => m['name'].toString().toLowerCase() == bestKnown!.toLowerCase())) {
          final strength = _extractStrength(line);
          final form = _extractForm(line);
          final times = _inferTimesFromLine(line);
          final duration = _inferDurationFromLine(line);
          final instructions = _extractInstructions(line, form);

          medicines.add({
            "name": bestKnown,
            "dosage": strength.isNotEmpty ? "$strength $form" : "1 $form",
            "instructions": instructions,
            "times": times,
            "duration_days": duration,
          });
        }
      }
    }

    // If no known medicines matched, parse numbered rows (e.g. "1. Metformin 500mg 1-0-1")
    if (medicines.isEmpty) {
      for (final line in lines) {
        final numberedMatch = RegExp(r'^(?:\d+[\.\)\-]|rx:?|tab\.?|cap\.?)\s*(.+)', caseSensitive: false).firstMatch(line);
        if (numberedMatch != null) {
          final content = numberedMatch.group(1)!.trim();
          if (content.length >= 3 && !content.toLowerCase().contains("date") && !content.toLowerCase().contains("phone")) {
            final words = content.split(RegExp(r'\s+'));
            final name = words.first;
            final strength = _extractStrength(content);
            final form = _extractForm(content);
            final times = _inferTimesFromLine(content);

            medicines.add({
              "name": name,
              "dosage": strength.isNotEmpty ? "$strength $form" : "1 $form",
              "instructions": "Take as directed on prescription.",
              "times": times,
              "duration_days": 7,
            });
          }
        }
      }
    }

    final count = medicines.length;
    final spokenSummary = count > 0
        ? (language == 'kn-IN'
            ? "ಈ ಚೀಟಿಯಲ್ಲಿ $count ಔಷಧಿಗಳು ಕಂಡುಬಂದಿವೆ: ${medicines.map((m) => m['name']).join(', ')}."
            : language == 'hi-IN'
                ? "इस पर्चे में $count दवाएं मिली हैं: ${medicines.map((m) => m['name']).join(', ')}।"
                : "Found $count medicines in this prescription: ${medicines.map((m) => m['name']).join(', ')}.")
        : (language == 'kn-IN'
            ? "ಚೀಟಿಯಲ್ಲಿ ಯಾವುದೇ ನಿರ್ದಿಷ್ಟ ಔಷಧಿಗಳು ಪತ್ತೆಯಾಗಿಲ್ಲ. ದಯವಿಟ್ಟು ಹತ್ತಿರದಿಂದ ಫೋಟೋ ತೆಗೆಯಿರಿ."
            : language == 'hi-IN'
                ? "पर्चे में कोई स्पष्ट दवा नहीं मिली। कृपया पास से फोटो लें।"
                : "Could not detect medicine names on this prescription. Please take a clearer photo closer to the text.");

    return {
      "doctor_name": doctorName,
      "extracted_text": rawText,
      "spoken_summary": spokenSummary,
      "medicines": medicines,
    };
  }

  List<String> _inferTimesFromLine(String line) {
    final lower = line.toLowerCase();
    if (lower.contains("1-0-1") || lower.contains("bid") || lower.contains("b.d") || lower.contains("twice")) {
      return ["08:00", "20:00"];
    }
    if (lower.contains("1-1-1") || lower.contains("tid") || lower.contains("tds") || lower.contains("three times")) {
      return ["08:00", "14:00", "20:00"];
    }
    if (lower.contains("1-0-0") || lower.contains("morning") || lower.contains("od morning")) {
      return ["08:00"];
    }
    if (lower.contains("0-0-1") || lower.contains("night") || lower.contains("bedtime") || lower.contains("h.s")) {
      return ["21:00"];
    }
    if (lower.contains("0-1-0") || lower.contains("afternoon")) {
      return ["14:00"];
    }
    return ["08:00", "20:00"];
  }

  int _inferDurationFromLine(String line) {
    final match = RegExp(r'(?:x|for)\s*(\d+)\s*(?:days?|d)\b', caseSensitive: false).firstMatch(line);
    if (match != null) {
      return int.tryParse(match.group(1)!) ?? 7;
    }
    final weekMatch = RegExp(r'(?:x|for)\s*(\d+)\s*(?:weeks?|w)\b', caseSensitive: false).firstMatch(line);
    if (weekMatch != null) {
      return (int.tryParse(weekMatch.group(1)!) ?? 1) * 7;
    }
    return 7;
  }

  Map<String, dynamic> _generateEmptyResult(String? language) {
    final summary = language == 'kn-IN'
        ? "ಚಿತ್ರದಲ್ಲಿ ಯಾವುದೇ ಸ್ಪಷ್ಟ ಪಠ್ಯ ಕಂಡುಬಂದಿಲ್ಲ. ದಯವಿಟ್ಟು ಬೆಳಕಿನಲ್ಲಿ ಮತ್ತೆ ಫೋಟೋ ತೆಗೆಯಿರಿ."
        : language == 'hi-IN'
            ? "फोटो में कोई स्पष्ट पाठ नहीं मिला। कृपया अच्छी रोशनी में दोबारा प्रयास करें।"
            : "Could not read text clearly. Please hold the medicine packaging steady under good light and try again.";

    return {
      "name": "",
      "dosage": "",
      "form": "",
      "strength": "",
      "composition": "",
      "purpose": "",
      "expiry_date": "",
      "instructions": "",
      "scanned_text": "",
      "confidence": "low",
      "spoken_summary": summary,
    };
  }
}
