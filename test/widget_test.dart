import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:safwa_quran/main.dart';
import 'package:safwa_quran/quran_data.dart';
// Deterministic in-memory data avoids waiting on platform asset channels
// inside fake-async widget tests. This stub deliberately returns no Quran text.
class _ReaderTestRepository extends QuranData {
  const _ReaderTestRepository();
  @override
  Future<List<Surah>> chapters() => SynchronousFuture<List<Surah>>(
    const [Surah(1, 'Al-Fatihah', 7), Surah(2, 'Al-Baqarah', 286)],
  );

  @override
  Future<List<Ayah>?> verses(int chapter) =>
      SynchronousFuture<List<Ayah>?>(null);
}

void main(){
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(()=>SharedPreferences.setMockInitialValues({}));
  test('catalog has all 114 chapters',()async{
    final rows=await const QuranData().chapters();
    expect(rows.length,114);
    expect(rows.fold<int>(0,(n,r)=>n+r.verseCount),6236);
  });
  test('unreviewed Quran text is never returned',()async{
    expect(await const QuranData().verses(1),isNull);
  });
  testWidgets('Surah catalog and fail-closed reader',(tester)async{
    await tester.pumpWidget(const SafwaApp(repository: _ReaderTestRepository()));
    await tester.pumpAndSettle();
    expect(find.text('SAFWA  |  QURAN'),findsOneWidget);
    await tester.tap(find.text('Explore the Quran'));
    await tester.pumpAndSettle();
    expect(find.text('Al-Fatihah'),findsOneWidget);
    await tester.tap(find.text('Al-Fatihah'));
    await tester.pumpAndSettle();
    expect(find.text('Verified Mushaf required'),findsOneWidget);
  });
}
