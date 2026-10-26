import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';
import '../services/speech_service.dart';
import '../services/emailjs_service.dart';

class CaregiverScreen extends StatefulWidget {
  const CaregiverScreen({super.key});

  @override
  State<CaregiverScreen> createState() => _CaregiverScreenState();
}

class _CaregiverScreenState extends State<CaregiverScreen> {
  List<Map<String, dynamic>> _caregivers = [];
  bool _isLoading = true;
  bool _isSendingMail = false;

  @override
  void initState() {
    super.initState();
    _fetchCaregivers();
  }

  Future<void> _fetchCaregivers() async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    try {
      final data = await db.getCaregivers();
      if (!mounted) return;
      setState(() {
        _caregivers = data;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openCaregiverDialog({Map<String, dynamic>? existing}) async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    final speech = Provider.of<SpeechService>(context, listen: false);

    final nameController = TextEditingController(text: existing?['name'] ?? '');
    final phoneController = TextEditingController(text: existing?['phone'] ?? '');
    final emailController = TextEditingController(text: existing?['email'] ?? '');
    final relationController = TextEditingController(text: existing?['relationship'] ?? '');

    final isEdit = existing != null;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFF334155))),
        title: Text(
          isEdit ? "Edit Caregiver" : "Add Caregiver",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Name *",
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  prefixIcon: const Icon(Icons.person_rounded, color: Color(0xFF38BDF8)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF334155))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF334155))),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Phone Number",
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  prefixIcon: const Icon(Icons.phone_rounded, color: Color(0xFF38BDF8)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF334155))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF334155))),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Gmail / Email (for alerts)",
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  prefixIcon: const Icon(Icons.alternate_email_rounded, color: Color(0xFF38BDF8)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF334155))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF334155))),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: relationController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Relationship (e.g., Doctor, Daughter, Nurse)",
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  prefixIcon: const Icon(Icons.badge_rounded, color: Color(0xFF38BDF8)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF334155))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF334155))),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final name = nameController.text.trim();
              final phone = phoneController.text.trim();
              final email = emailController.text.trim();
              final relation = relationController.text.trim();

              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please enter a name for the caregiver")),
                );
                return;
              }

              final payload = {
                'name': name,
                'phone': phone,
                'email': email,
                'relationship': relation.isNotEmpty ? relation : 'Caregiver',
              };

              if (isEdit) {
                await db.updateCaregiver(existing['id'], payload);
                speech.speak("Caregiver $name updated.");
              } else {
                await db.insertCaregiver(payload);
                speech.speak("Caregiver $name added.");
              }

              if (context.mounted) Navigator.pop(context);
              _fetchCaregivers();
            },
            child: Text(isEdit ? "Update" : "Save to Firebase"),
          ),
        ],
      ),
    );
  }

  Future<void> _sendEmailToCaregiver({String? toEmail, String? caregiverName}) async {
    final speech = Provider.of<SpeechService>(context, listen: false);
    final db = Provider.of<DatabaseService>(context, listen: false);

    // 1. Determine target email(s) strictly from Caregivers and Emergency Contact
    final targetEmails = <String>{};
    if (toEmail != null && toEmail.trim().isNotEmpty && toEmail.contains('@')) {
      targetEmails.add(toEmail.trim());
    } else {
      // Collect all configured caregivers
      for (final cg in _caregivers) {
        final em = cg['email']?.toString().trim();
        if (em != null && em.isNotEmpty && em.contains('@')) {
          targetEmails.add(em);
        }
      }
      // If none, check emergency contact
      if (targetEmails.isEmpty) {
        final ec = await db.getEmergencyContact();
        final em = ec?['emergency_contact_email']?.toString().trim() ?? ec?['emergency_email']?.toString().trim();
        if (em != null && em.isNotEmpty && em.contains('@')) {
          targetEmails.add(em);
        }
      }
    }

    if (targetEmails.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          content: Text("⚠️ No email configured in Caregivers or Emergency Contact. Please add an email address first."),
        ),
      );
      speech.speak("No email address configured in Caregivers or Emergency Contact. Please add an email first.");
      return;
    }

    if (!mounted) return;
    setState(() => _isSendingMail = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("📧 Sending EmailJS report (template_err1y5l) to ${targetEmails.join(', ')}..."),
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      final profile = await db.getProfile();
      final patientName = profile?['full_name'] ?? 'Patient';
      final medicines = await db.getMedicines();
      final medSummary = medicines.map((m) => "- ${m['name']} (${m['dosage'] ?? ''})").join("\n");
      final reportBody = "Hello ${caregiverName ?? 'Caregiver'},\n\n"
          "This is a medication status report for $patientName via MediCare app.\n\n"
          "Active Medications:\n"
          "${medSummary.isNotEmpty ? medSummary : 'All current medications on track.'}\n\n"
          "Timestamp: ${DateTime.now().toString().split('.').first}";

      bool anySuccess = false;
      for (final email in targetEmails) {
        debugPrint("EmailJS: Sending Caregiver template (template_err1y5l) to $email...");
        final success = await EmailJSService.sendCaregiverEmail(
          toEmail: email,
          patientName: patientName,
          message: reportBody,
          subject: "MediCare Report for ${caregiverName ?? 'Caregiver'}",
        );
        if (success) anySuccess = true;
      }

      if (!mounted) return;
      setState(() => _isSendingMail = false);

      if (anySuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            content: Text("✅ EmailJS report sent successfully to ${targetEmails.join(', ')}!"),
          ),
        );
        speech.speak("Email report sent to caregiver successfully.");
      } else {
        final err = EmailJSService.lastError ?? 'Unknown error';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            content: Text("⚠️ Failed: $err"),
            duration: const Duration(seconds: 5),
          ),
        );
        if (err.contains("Gmail account disconnected") || err.contains("Invalid grant")) {
          speech.speak("EmailJS Gmail account is disconnected. Please reconnect it in your EmailJS dashboard.");
        } else {
          speech.speak("Could not send email via EmailJS.");
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSendingMail = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red, content: Text("Error: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1D),
      appBar: AppBar(
        title: const Text(
          "Caregivers",
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.3),
        ),
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        actions: [
          IconButton(
            icon: _isSendingMail
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_rounded, color: Color(0xFF38BDF8)),
            tooltip: "Send EmailJS Report to Caregivers",
            onPressed: _isSendingMail ? null : () => _sendEmailToCaregiver(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
          : Column(
              children: [
                // Real-time Cloud Sync Banner
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.cloud_done_rounded, color: Color(0xFF10B981), size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Firebase Realtime Database",
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            SizedBox(height: 2),
                            Text(
                              "Reports & alerts are sent only to the emails added here.",
                              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Caregivers List or Empty State
                Expanded(
                  child: _caregivers.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _caregivers.length,
                          itemBuilder: (context, index) {
                            final c = _caregivers[index];
                            final hasEmail = (c['email'] ?? '').toString().contains('@');
                            final relation = c['relationship'] ?? 'Caregiver';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFF334155)),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                leading: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.person_rounded, color: Color(0xFF38BDF8), size: 24),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        c['name'] ?? 'Unknown',
                                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF334155),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        relation,
                                        style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 6),
                                    if ((c['phone'] ?? '').toString().isNotEmpty)
                                      Row(
                                        children: [
                                          const Icon(Icons.phone_rounded, size: 14, color: Color(0xFF94A3B8)),
                                          const SizedBox(width: 6),
                                          Text(c['phone'] ?? '', style: const TextStyle(fontSize: 14, color: Color(0xFFCBD5E1))),
                                        ],
                                      ),
                                    if ((c['email'] ?? '').toString().isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4.0),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.alternate_email_rounded, size: 14, color: Color(0xFF38BDF8)),
                                            const SizedBox(width: 6),
                                            Text(c['email'] ?? '', style: const TextStyle(fontSize: 14, color: Color(0xFF38BDF8))),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (hasEmail)
                                      IconButton(
                                        icon: const Icon(Icons.email_rounded, color: Color(0xFF38BDF8), size: 24),
                                        tooltip: "Send EmailJS Caregiver Report",
                                        onPressed: _isSendingMail
                                            ? null
                                            : () => _sendEmailToCaregiver(
                                                  toEmail: c['email'],
                                                  caregiverName: c['name'],
                                                ),
                                      ),
                                    IconButton(
                                      icon: const Icon(Icons.edit_rounded, color: Color(0xFF94A3B8), size: 22),
                                      tooltip: "Edit Caregiver",
                                      onPressed: () => _openCaregiverDialog(existing: c),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 22),
                                      tooltip: "Delete Caregiver",
                                      onPressed: () async {
                                        await Provider.of<DatabaseService>(context, listen: false).deleteCaregiver(c['id']);
                                        _fetchCaregivers();
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCaregiverDialog(),
        backgroundColor: const Color(0xFF0284C7),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text("ADD CAREGIVER", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: const Icon(Icons.people_outline_rounded, size: 48, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            const Text(
              "No Caregivers Added Yet",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            const Text(
              "Add family members, nurses, or doctors. When you miss a dose or send a health report, EmailJS alerts will go directly to their Gmail.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8), height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
