import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

/// Keep existing stored category values compatible while rendering brand icons.
const categorySymbols = <String, (String, IconData)>{
  '💬': ('General', PhosphorIconsRegular.chatCircle),
  '📰': ('News', PhosphorIconsRegular.newspaper),
  '📅': ('Events', PhosphorIconsRegular.calendarBlank),
  '🏠': ('Housing', PhosphorIconsRegular.house),
  '💼': ('Jobs', PhosphorIconsRegular.briefcase),
  '⚽': ('Sports', PhosphorIconsRegular.soccerBall),
  '🛒': ('Marketplace', PhosphorIconsRegular.shoppingCart),
  '📍': ('Local Businesses', PhosphorIconsRegular.mapPin),
  '🔎': ('Lost & Found', PhosphorIconsRegular.magnifyingGlass),
  '🌿': ('Nature', PhosphorIconsRegular.leaf),
  '🐾': ('Pets', PhosphorIconsRegular.pawPrint),
  '📢': ('Announcements', PhosphorIconsRegular.megaphone),
  '🍔': ('Burgers', PhosphorIconsRegular.hamburger),
  '🍕': ('Pizza', PhosphorIconsRegular.pizza),
  '🍴': ('Food', PhosphorIconsRegular.forkKnife),
  '☕': ('Coffee', PhosphorIconsRegular.coffee),
  '🚗': ('Transport', PhosphorIconsRegular.car),
  '❤️': ('Health', PhosphorIconsRegular.heart),
};

class CategorySymbol extends StatelessWidget {
  const CategorySymbol(this.value, {super.key, this.size = 22, this.color});
  final String value;
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final symbol = categorySymbols[value];
    return symbol == null
        ? Text(
            value,
            style: TextStyle(fontSize: size, color: color),
          )
        : Icon(symbol.$2, size: size, color: color);
  }
}
