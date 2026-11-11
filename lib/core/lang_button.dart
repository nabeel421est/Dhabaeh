import 'package:flutter/material.dart';

import 'i18n.dart';

/// Small pill that switches the app between Arabic and English.
/// The choice is saved on the device and on the user's profile.
class LangButton extends StatelessWidget {
  const LangButton({super.key});
  @override
  Widget build(BuildContext context) {
    final en = Localizations.localeOf(context).languageCode == 'en';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Tooltip(
        message: en ? 'اللغة: العربية' : 'Language: English',
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => setLanguage(en ? 'ar' : 'en'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: Colors.white.withValues(alpha: .14),
              border: Border.all(color: Colors.white.withValues(alpha: .45)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.translate, size: 16, color: Colors.white),
              const SizedBox(width: 5),
              // Flutter's own Text (not translated): shown in the other
              // language so people can always find it.
              Text(en ? 'عربي' : 'EN',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13)),
            ]),
          ),
        ),
      ),
    );
  }
}
