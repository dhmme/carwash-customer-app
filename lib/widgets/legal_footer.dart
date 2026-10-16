import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Public policy pages remain available without a session or Flutter startup.
class LegalFooter extends StatelessWidget {
  const LegalFooter({super.key});

  static Future<void> open(BuildContext context, String page) async {
    try {
      final opened = await launchUrl(
        Uri.parse('https://www.codecare.sa/legal/$page.html'),
        mode: LaunchMode.platformDefault,
        webOnlyWindowName: '_blank',
      );
      if (opened) return;
    } catch (_) {}
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح الصفحة. حاول مرة أخرى.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 4,
            children: [
              for (final item in const {
                'terms': 'الشروط والأحكام',
                'privacy': 'سياسة الخصوصية',
                'refunds': 'الإلغاء والاسترداد',
                'contact': 'تواصل معنا',
              }.entries)
                TextButton(
                  onPressed: () => open(context, item.key),
                  child: Text(item.value),
                ),
            ],
          ),
          const Text('كودكير — عناية بكل تفصيل', textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}
