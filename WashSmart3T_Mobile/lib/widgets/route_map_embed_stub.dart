import 'package:flutter/material.dart';

class RouteMapEmbedPlatform extends StatelessWidget {
  final String url;
  final double height;

  const RouteMapEmbedPlatform({
    super.key,
    required this.url,
    this.height = 360,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: Text('Bản đồ định tuyến trực tuyến'),
      ),
    );
  }
}
