import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

const double _goldenRasterizationTolerance = 0.025;

void configureGoldenFileComparator() {
  goldenFileComparator = _TolerantGoldenFileComparator(
    Uri.parse('test/flutter_test_config.dart'),
    precisionTolerance: _goldenRasterizationTolerance,
  );
}

/// Allows small host-renderer differences while retaining structural goldens.
class _TolerantGoldenFileComparator extends LocalFileComparator {
  _TolerantGoldenFileComparator(
    super.testFile, {
    required double precisionTolerance,
  }) : assert(precisionTolerance >= 0 && precisionTolerance <= 1),
       _precisionTolerance = precisionTolerance;

  final double _precisionTolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed || result.diffPercent <= _precisionTolerance) {
      result.dispose();
      return true;
    }

    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}
