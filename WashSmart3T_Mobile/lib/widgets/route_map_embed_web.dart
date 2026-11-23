// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

class RouteMapEmbedPlatform extends StatefulWidget {
  final String url;
  final double height;

  const RouteMapEmbedPlatform({
    super.key,
    required this.url,
    this.height = 360,
  });

  @override
  State<RouteMapEmbedPlatform> createState() => _RouteMapEmbedPlatformState();
}

class _RouteMapEmbedPlatformState extends State<RouteMapEmbedPlatform> {
  late final String _viewTypeId;

  @override
  void initState() {
    super.initState();
    _viewTypeId = 'shipper-route-iframe-${DateTime.now().microsecondsSinceEpoch}';
    ui_web.platformViewRegistry.registerViewFactory(
      _viewTypeId,
      (int viewId) {
        final iframe = html.IFrameElement()
          ..src = widget.url
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          ..allow = 'geolocation; camera';
        return iframe;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: HtmlElementView(viewType: _viewTypeId),
      ),
    );
  }
}
