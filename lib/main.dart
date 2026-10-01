import 'package:flutter/material.dart';

import 'app.dart';
import 'self_test.dart';

void main() => runApp(VillageApp(test: SelfTest.fromEnvironment()));
