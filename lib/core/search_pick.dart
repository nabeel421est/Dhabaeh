import 'package:flutter/material.dart' hide Text;

import 'brand.dart';
import 'i18n.dart';
import 'ttext.dart';

/// Loose Arabic matching: ignores hamza forms, taa marbuta, alef maqsura,
/// the article «ال» and letter case, so «الرفاع», «رفاع» and «رفا» all match.
String searchKey(String s) => s
    .toLowerCase()
    .replaceAll(RegExp('[أإآٱ]'), 'ا')
    .replaceAll('ة', 'ه')
    .replaceAll('ى', 'ي')
    .replaceAll(RegExp(r'(^|\s)ال'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

bool searchMatch(String text, String q) {
  final k = searchKey(q);
  if (k.isEmpty) return true;
  final t = searchKey(text);
  return k.split(' ').every(t.contains);
}

/// A list with a search box on top; returns the picked value.
Future<String?> showSearchPick(BuildContext context,
    {required String title,
    required List<(String, String)> options,
    String? current,
    IconData icon = Icons.location_city_outlined}) {
  final q = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (c) => StatefulBuilder(builder: (c, set) {
      final tone = brandOf(context).primary;
      final list =
          options.where((o) => searchMatch('${o.$2} ${o.$1}', q.text)).toList();
      return Dialog(
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440, maxHeight: 560),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
              decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: brandOf(context).stops.sublist(1))),
              child: Row(children: [
                Icon(icon, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700))),
                IconButton(
                    onPressed: () => Navigator.pop(c),
                    icon: const Icon(Icons.close, color: Colors.white)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: q,
                autofocus: true,
                onChanged: (_) => set(() {}),
                onSubmitted: (_) {
                  if (list.length == 1) Navigator.pop(c, list.first.$1);
                },
                decoration: InputDecoration(
                  hintText: tr('ابحث بالاسم…'),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: q.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () => set(q.clear),
                          icon: const Icon(Icons.clear)),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            Flexible(
              child: list.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('لا توجد نتائج',
                          style: TextStyle(color: Colors.black45)))
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.only(bottom: 8),
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final o = list[i];
                        final sel = o.$1 == current;
                        return ListTile(
                          dense: true,
                          leading: Icon(
                              sel ? Icons.check_circle : Icons.place_outlined,
                              color: sel ? tone : Colors.black38),
                          title: Text(o.$2,
                              style: TextStyle(
                                  fontWeight:
                                      sel ? FontWeight.w700 : FontWeight.w500)),
                          onTap: () => Navigator.pop(c, o.$1),
                        );
                      },
                    ),
            ),
          ]),
        ),
      );
    }),
  );
}

/// A form field that opens [showSearchPick]. Use it instead of a dropdown
/// for long lists such as cities and delivery areas.
class SearchPickField extends StatelessWidget {
  const SearchPickField(
      {super.key,
      required this.value,
      required this.options,
      required this.onChanged,
      this.decoration = const InputDecoration(),
      this.title,
      this.validator,
      this.icon = Icons.location_city_outlined});

  /// Plain strings as both value and label.
  SearchPickField.strings(
      {Key? key,
      required String? value,
      required List<String> items,
      required ValueChanged<String?> onChanged,
      InputDecoration decoration = const InputDecoration(),
      String? title,
      String? Function(String?)? validator,
      IconData icon = Icons.location_city_outlined})
      : this(
            key: key,
            value: value,
            options: [for (final s in items) (s, s)],
            onChanged: onChanged,
            decoration: decoration,
            title: title,
            validator: validator,
            icon: icon);

  final String? value;
  final List<(String, String)> options;
  final ValueChanged<String?> onChanged;
  final InputDecoration decoration;
  final String? title;
  final String? Function(String?)? validator;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final label = options.where((o) => o.$1 == value).firstOrNull?.$2;
    return FormField<String>(
      key: ValueKey('pick-$value'),
      initialValue: value,
      validator: validator == null ? null : (_) => validator!(value),
      builder: (st) => InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final v = await showSearchPick(context,
              title: title ?? decoration.labelText ?? tr('اختر'),
              options: options,
              current: value,
              icon: icon);
          if (v != null) {
            st.didChange(v);
            onChanged(v);
          }
        },
        child: InputDecorator(
          isEmpty: label == null,
          decoration: decoration.copyWith(
            errorText: st.errorText,
            suffixIcon: decoration.suffixIcon ?? const Icon(Icons.search),
          ),
          child: label == null
              ? const SizedBox(height: 20)
              : Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}
