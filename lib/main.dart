import 'package:flutter/material.dart';
import 'safwa_preferences.dart';
import 'quran_data.dart';
import 'prayer_times.dart';
import 'companion_features.dart';
import 'local_backup.dart';
import 'offline_recitation_page.dart';

/// Recover interrupted preference restore before any widget reads local data.
/// Fail closed rather than displaying potentially half-restored settings.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await const LocalSafwaBackup().recoverPendingRestore();
    runApp(const SafwaApp());
  } catch (_) {
    runApp(const MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Safwa could not safely recover local preferences. '
                'Keep your original encrypted backup. Restart the app or '
                'contact support before attempting another restore.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    ));
  }
}
const navy=Color(0xFF142547),cream=Color(0xFFF7F6F2),gold=Color(0xFFAD8744),teal=Color(0xFF187A8B);
class SafwaApp extends StatelessWidget {
  const SafwaApp({super.key, this.repository = const QuranData()});
  final QuranData repository;
  @override Widget build(BuildContext context)=>MaterialApp(
    title:'Safwa Quran',debugShowCheckedModeBanner:false,
    theme:ThemeData(useMaterial3:true,scaffoldBackgroundColor:cream,
      colorScheme:ColorScheme.fromSeed(seedColor:navy,surface:cream),
      appBarTheme:const AppBarTheme(backgroundColor:cream,foregroundColor:navy),
      cardTheme:CardThemeData(color:Colors.white,elevation:0,
      shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18)))),
    home:QuranHome(repository: repository));
}
class QuranHome extends StatefulWidget {
  const QuranHome({super.key, required this.repository});
  final QuranData repository;
  @override State<QuranHome> createState()=>_QuranHomeState();
}
class _QuranHomeState extends State<QuranHome>{
  late final Future<List<Surah>> chapters;
  Set<int> saved={};int tab=0;String query='';String? lastRead;
  @override void initState(){
    super.initState();
    chapters=widget.repository.chapters();
    _load();
  }
  Future<void> _load()async{
    final p=await SafwaPreferences.getInstance();
    if (mounted) {
      setState(() {
      saved=(p.getStringList('saved_surahs')??[]).map(int.tryParse).whereType<int>().toSet();
      lastRead=p.getString('last_read');
      });
    }
  }
  Future<void> _save(int id)async{
    final next={...saved};
    next.contains(id)?next.remove(id):next.add(id);
    final p=await SafwaPreferences.getInstance();
    if (await p.setStringList('saved_surahs',next.map((e)=>e.toString()).toList()) && mounted) {
      setState(() => saved = next);
    }
  }
  Future<void> _read(Surah surah)async{
    await Navigator.of(context).push(MaterialPageRoute<void>(builder:(_)=>SurahReader(surah:surah,repository:widget.repository)));
    _load();
  }
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('SAFWA  |  QURAN',style:TextStyle(fontWeight:FontWeight.w800,letterSpacing:1))),
    bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(v)=>setState(()=>tab=v),
      destinations:const [
        NavigationDestination(icon:Icon(Icons.home_outlined),label:'Home'),
        NavigationDestination(icon:Icon(Icons.menu_book_outlined),label:'Quran'),
        NavigationDestination(icon:Icon(Icons.bookmark_outline),label:'Saved'),
        NavigationDestination(icon:Icon(Icons.apps_outlined),label:'Companion')]),
    body: tab == 3 ? const CompanionHub() : FutureBuilder<List<Surah>>(future:chapters,builder:(context,s){
      if(s.hasError)return const Center(child:Text('Surah directory unavailable.'));
      if(!s.hasData)return const Center(child:CircularProgressIndicator());
      final all=s.data!;
      if (tab == 0) {
        return ListView(padding:const EdgeInsets.all(20),children:[
        const SizedBox(height:28),
        const Text('SAFWA INSTITUTE  /  FAITH, KNOWLEDGE & GROWTH',
          style:TextStyle(color:teal,letterSpacing:1.1,fontSize:11,fontWeight:FontWeight.w700)),
        const SizedBox(height:14),
        const Text('Your peaceful Quran journey starts here.',
          style:TextStyle(color:navy,fontWeight:FontWeight.w800,fontSize:32,height:1.18)),
        const SizedBox(height:14),
        const Text('Read, remember and grow with a source-first Islamic companion.'),
        const SizedBox(height:24),
        Card(child:Padding(padding:const EdgeInsets.all(20),child:Column(
          crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('QURAN READER',style:TextStyle(color:gold,fontWeight:FontWeight.w700)),
          const SizedBox(height:8),
          const Text('114 Surahs · 6,236 Ayahs',style:TextStyle(color:navy,fontSize:21,fontWeight:FontWeight.bold)),
          const SizedBox(height:14),
          FilledButton.icon(onPressed:()=>setState(()=>tab=1),
            icon:const Icon(Icons.menu_book_outlined),label:const Text('Explore the Quran')),
        ]))),
        const SizedBox(height:14),
        Card(child:Padding(padding:const EdgeInsets.all(20),child:Column(
          crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('OFFLINE RECITATION',style:TextStyle(
            color:gold,fontWeight:FontWeight.w700)),
          const SizedBox(height:8),
          const Text('Listen without internet',style:TextStyle(
            color:navy,fontSize:20,fontWeight:FontWeight.w700)),
          const SizedBox(height:8),
          const Text('Recorded recitations remain unavailable until '
            'rights and independent audio reviews are approved.'),
          const SizedBox(height:12),
          OutlinedButton.icon(
            onPressed:()=>Navigator.of(context).push(MaterialPageRoute<void>(
              builder:(_)=>const OfflineRecitationPage())),
            icon:const Icon(Icons.headphones_outlined),
            label:const Text('Offline recitation status')),
        ]))),
        const SizedBox(height:14),
        Card(child:Padding(padding:const EdgeInsets.all(20),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Text('PRAYER TIMES',style:TextStyle(
              color:gold,fontWeight:FontWeight.w700)),
            const SizedBox(height:8),
            const Text('Your daily Salah, thoughtfully planned.',
              style:TextStyle(color:navy,fontSize:20,fontWeight:FontWeight.w700)),
            const SizedBox(height:8),
            const Text('Offline estimates · choose your city and method · no GPS required'),
            const SizedBox(height:12),
            OutlinedButton.icon(
              onPressed:()=>Navigator.of(context).push(
                MaterialPageRoute<void>(builder:(_)=>const PrayerTimesPage())),
              icon:const Icon(Icons.access_time),
              label:const Text('View prayer times')),
          ]))),
        if(lastRead!=null)...[const SizedBox(height:15),Text('Continue from ${lastRead!}',
          style:const TextStyle(color:teal))],
        const SizedBox(height:20),
        const Text('Begin with a Surah',style:TextStyle(color:navy,fontSize:20,fontWeight:FontWeight.w700)),
        ...all.take(5).map(_tile),
        const Padding(padding:EdgeInsets.all(12),child:Text('Quran text appears only when a complete, rights-cleared and independently reviewed source is activated.',
          style:TextStyle(color:teal,fontSize:12))),
      ]);
      }
      final list=tab==2?all.where((x)=>saved.contains(x.number)).toList():
        all.where((x)=>x.englishName.toLowerCase().contains(query.toLowerCase())||x.number.toString()==query.trim()).toList();
      return Column(children:[
        if(tab==1)Padding(padding:const EdgeInsets.all(16),child:TextField(
          onChanged:(v)=>setState(()=>query=v),
          decoration:const InputDecoration(prefixIcon:Icon(Icons.search),
            hintText:'Search Surah names or numbers',border:OutlineInputBorder()))),
        Expanded(child:list.isEmpty?const Center(child:Text('No saved or matching Surahs.')):
          ListView.builder(itemCount:list.length,
            itemBuilder:(_,i)=>Padding(padding:const EdgeInsets.symmetric(horizontal:12),child:_tile(list[i]))))
      ]);
    }),
  );
  Widget _tile(Surah s)=>Card(child:ListTile(
    leading:CircleAvatar(backgroundColor:cream,child:Text(s.number.toString(),
      style:const TextStyle(color:navy))),
    title:Text(s.englishName,style:const TextStyle(fontWeight:FontWeight.w700)),
    subtitle:Text('${s.verseCount} ayahs'),
    onTap:()=>_read(s),
    trailing:IconButton(tooltip:'Bookmark Surah',onPressed:()=>_save(s.number),
      icon:Icon(saved.contains(s.number)?Icons.bookmark:Icons.bookmark_outline)),
  ));
}
class SurahReader extends StatefulWidget {
  const SurahReader({super.key,required this.surah,required this.repository});
  final Surah surah;final QuranData repository;
  @override State<SurahReader> createState()=>_SurahReaderState();
}
class _SurahReaderState extends State<SurahReader>{
  late final Future<List<Ayah>?> verses=widget.repository.verses(widget.surah.number);
  double fontSize=30;Set<String> savedAyat={};
  @override void initState(){super.initState();_load();}
  Future<void> _load()async{
    final p=await SafwaPreferences.getInstance();
    if (mounted) {
      setState(() {
      fontSize=p.getDouble('arabic_font_size')??30;
      savedAyat=(p.getStringList('saved_ayat')??[]).toSet();
      });
    }
  }
  Future<void> _toggle(int verse)async{
    final id='${widget.surah.number}:$verse';
    final next={...savedAyat};
    next.contains(id)?next.remove(id):next.add(id);
    final p=await SafwaPreferences.getInstance();
    if (await p.setStringList('saved_ayat',next.toList()) && mounted) {
      setState(() => savedAyat = next);
    }
  }
  Future<void> _resize(double delta)async{
    final size=(fontSize+delta).clamp(20.0,48.0);
    final p=await SafwaPreferences.getInstance();
    if (await p.setDouble('arabic_font_size',size) && mounted) {
      setState(() => fontSize = size);
    }
  }
  Future<void> _progress(int verse)async{
    final p=await SafwaPreferences.getInstance();
    await p.setString('last_read','${widget.surah.number}:$verse');
  }
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:Text(widget.surah.englishName),actions:[
      IconButton(tooltip:'Reduce font size',onPressed:()=>_resize(-2),icon:const Icon(Icons.text_decrease)),
      IconButton(tooltip:'Increase font size',onPressed:()=>_resize(2),icon:const Icon(Icons.text_increase)),
    ]),
    body:FutureBuilder<List<Ayah>?>(future:verses,builder:(context,s){
      if(s.hasError)return const Center(child:Text('Quran dataset integrity check failed.'));
      if(!s.hasData){
        if (s.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        return const Center(child:Padding(padding:EdgeInsets.all(28),child:Column(
          mainAxisSize:MainAxisSize.min,children:[
            Icon(Icons.verified_user_outlined,color:gold,size:52),
            SizedBox(height:16),
            Text('Verified Mushaf required',textAlign:TextAlign.center,
              style:TextStyle(fontSize:22,color:navy,fontWeight:FontWeight.bold)),
            SizedBox(height:12),
            Text('Arabic verses are unavailable until the complete Quran dataset is independently verified and approved.',
              textAlign:TextAlign.center),
          ])));
      }
      final rows=s.data!;
      return ListView.builder(padding:const EdgeInsets.all(14),itemCount:rows.length,
        itemBuilder:(context,index){
          final a=rows[index];
          final id='${widget.surah.number}:${a.number}';
          return Semantics(label:'Verse $id',child:Card(child:Padding(
            padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
              Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
                Text(id,style:const TextStyle(color:teal,fontWeight:FontWeight.bold)),
                IconButton(tooltip:'Bookmark verse $id',onPressed:()=>_toggle(a.number),
                  icon:Icon(savedAyat.contains(id)?Icons.bookmark:Icons.bookmark_border)),
              ]),
              Directionality(textDirection:TextDirection.rtl,child:Text(a.text,
                textAlign:TextAlign.right,style:TextStyle(fontSize:fontSize,height:2,color:navy))),
              Align(alignment:Alignment.centerRight,child:TextButton(
                onPressed:()=>_progress(a.number),child:const Text('Mark last read'))),
            ]))));
        });
    }),
  );
}
