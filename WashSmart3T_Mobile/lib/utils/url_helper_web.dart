// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void openBrowserUrl(String url) {
  try {
    html.window.open(url, '_blank');
  } catch (e) {
    // ignore
  }
}
