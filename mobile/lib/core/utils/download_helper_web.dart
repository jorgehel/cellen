// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void downloadXml(String content, String filename) {
  final blob = html.Blob([content], 'application/xml');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}
