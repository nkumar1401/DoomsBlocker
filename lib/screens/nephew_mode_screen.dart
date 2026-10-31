// Backward compatibility alias for NephewModeScreen -> KidsModeScreen
export 'kids_mode_screen.dart';

import 'package:flutter/material.dart';
import 'kids_mode_screen.dart';

class NephewModeScreen extends StatelessWidget {
  const NephewModeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const KidsModeScreen();
  }
}
