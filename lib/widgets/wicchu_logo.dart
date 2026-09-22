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
  const WicchuTitle({super.key});

  @override
  Widget build(BuildContext context) => const Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      WicchuLogo(size: 30),
      SizedBox(width: 10),
      Text('Wicchu', style: TextStyle(fontWeight: FontWeight.w800)),
    ],
  );
}
