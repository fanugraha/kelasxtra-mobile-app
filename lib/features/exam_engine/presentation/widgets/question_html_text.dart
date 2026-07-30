// lib/features/exam_engine/presentation/widgets/question_html_text.dart
//
// Renderer HTML minimal untuk question_text -- cuma menangani tag yang
// TERBUKTI muncul di data asli sejauh ini: <p>, <ol>, <li> (lihat soal id
// 393 di data TIU, "Rata-rata nilai ujian..."). Sengaja TIDAK pakai package
// flutter_html: himpunan tag yang perlu didukung sangat kecil & stabil
// (soal ujian, bukan HTML bebas dari web), jadi parser tangan lebih ringan
// dan tidak menambah dependency (+ resiko versi, tanpa Flutter SDK di
// tangan untuk verifikasi build saat ditulis). Kalau ke depan backend mulai
// kirim tag lain (table, <img> inline di teks, dst), pertimbangkan ganti ke
// flutter_html saat itu baru muncul kebutuhannya nyata.
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class QuestionHtmlText extends StatelessWidget {
  const QuestionHtmlText(this.html, {super.key, this.style});

  final String html;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final baseStyle =
        style ?? const TextStyle(color: AppColors.neutral900, fontSize: 15, height: 1.5);

    if (!html.contains('<')) {
      // Fast path: soal biasa (mayoritas data), tanpa tag sama sekali.
      return Text(html, style: baseStyle);
    }

    final blocks = _parseBlocks(html);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final block in blocks)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: block.isListItem
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 22, child: Text(block.marker ?? '•', style: baseStyle)),
                      Expanded(child: Text(block.text, style: baseStyle)),
                    ],
                  )
                : Text(block.text, style: baseStyle),
          ),
      ],
    );
  }

  List<_HtmlBlock> _parseBlocks(String raw) {
    final blocks = <_HtmlBlock>[];
    var olCounter = 0;
    var inOrderedList = false;

    // Regex sederhana: tangkap tag blok satu per satu (tidak nested) --
    // cukup untuk struktur datar yang muncul di data soal. <ol>/<ul> cuma
    // dipakai sebagai penanda konteks penomoran untuk <li> berikutnya.
    final tagPattern = RegExp(
      r'<p[^>]*>(.*?)</p>|<li[^>]*>(.*?)</li>|<ol[^>]*>|</ol>|<ul[^>]*>|</ul>',
      dotAll: true,
      caseSensitive: false,
    );

    var lastEnd = 0;
    for (final match in tagPattern.allMatches(raw)) {
      // Teks di luar tag yang dikenali (mis. sebelum tag pertama) tetap
      // ditampilkan sebagai paragraf biasa, supaya tidak ada konten hilang
      // diam-diam kalau backend kirim format yang sedikit beda dari dugaan.
      final between = raw.substring(lastEnd, match.start).trim();
      if (between.isNotEmpty) {
        blocks.add(_HtmlBlock(text: _stripTags(between)));
      }
      lastEnd = match.end;

      final full = match.group(0)!;
      if (full.startsWith('<ol')) {
        inOrderedList = true;
        olCounter = 0;
        continue;
      }
      if (full.startsWith('</ol') || full.startsWith('<ul') || full.startsWith('</ul')) {
        if (full.startsWith('</ol')) inOrderedList = false;
        continue;
      }

      if (match.group(1) != null) {
        // <p>...</p>
        final text = _stripTags(match.group(1)!).trim();
        if (text.isNotEmpty) blocks.add(_HtmlBlock(text: text));
      } else if (match.group(2) != null) {
        // <li>...</li>
        final text = _stripTags(match.group(2)!).trim();
        if (text.isEmpty) continue;
        olCounter++;
        blocks.add(_HtmlBlock(
          text: text,
          isListItem: true,
          marker: inOrderedList ? '$olCounter.' : '•',
        ));
      }
    }

    final tail = raw.substring(lastEnd).trim();
    if (tail.isNotEmpty) blocks.add(_HtmlBlock(text: _stripTags(tail)));

    if (blocks.isEmpty) {
      // Fallback terakhir: tag tidak dikenali sama sekali -- tetap
      // tampilkan teksnya (di-strip) daripada kosong.
      blocks.add(_HtmlBlock(text: _stripTags(raw)));
    }

    return blocks;
  }

  String _stripTags(String s) {
    return s
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .trim();
  }
}

class _HtmlBlock {
  _HtmlBlock({required this.text, this.isListItem = false, this.marker});
  final String text;
  final bool isListItem;
  final String? marker;
}
