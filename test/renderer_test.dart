import 'package:lexicon/lexicon/template_renderer.dart';
import 'package:test/test.dart';

void main() async {
  // String container = '<H:[nb|grey|available]:CLASSIFIER: >';
  String container = 'H[nb|grey|available]:CLASSIFIER: ';

  test('test', () {
    getContSpecs(container);
  });
}
