import 'package:flutter/material.dart';

class WicchuLogo extends StatelessWidget {
  const WicchuLogo({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/brand/logo_wicchu.png',
    width: size,
    height: size,
    fit: BoxFit.contain,
    semanticLabel: 'Wicchu',
  );
}

class WicchuTitle extends StatelessWidget {
  const WicchuTitle({super.key, this.scale = 1});

  final double scale;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.centerLeft,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        WicchuLogo(size: 30 * scale),
        SizedBox(width: 10 * scale),
        Text(
          'Wicchu',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize:
                (DefaultTextStyle.of(context).style.fontSize ?? 22) * scale,
          ),
        ),
      ],
    ),
  );
}
