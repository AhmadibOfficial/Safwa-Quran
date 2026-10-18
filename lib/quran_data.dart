import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
class Surah {
  const Surah(this.number,this.englishName,this.verseCount);
  final int number;final String englishName;final int verseCount;
}
class Ayah {
  const Ayah(this.number,this.text);
  final int number;final String text;
}
class QuranData {
  const QuranData();
  Future<List<Surah>> chapters()async{
    final raw=await rootBundle.loadString('assets/data/chapters.tsv');
    final rows=raw.trim().split('\n').where((x)=>x.isNotEmpty).map((line){
      final parts=line.trim().split('|');
      return Surah(int.parse(parts[0]),parts[1],int.parse(parts[2]));
    }).toList(growable:false);
    if(rows.length!=114 || rows.asMap().entries.any((e)=>e.value.number!=e.key+1) ||
      rows.fold<int>(0,(sum,s)=>sum+s.verseCount)!=6236) {
      throw const FormatException('Invalid Quran chapter catalog');
    }
    return rows;
  }
  Future<List<Ayah>?> verses(int chapter)async{
    if(chapter<1||chapter>114)return null;
    try{
      final manifest=jsonDecode(await rootBundle.loadString('assets/data/content_activation.json')) as Map<String,dynamic>;
      if(manifest['quran_reader_enabled']!=true || manifest['review_status']!='approved' ||
        manifest['approved_source_sha256'] is! String)return null;
      final data=await rootBundle.load('assets/data/quran_verified.json');
      final bytes=data.buffer.asUint8List(data.offsetInBytes,data.lengthInBytes);
      if(sha256.convert(bytes).toString()!=manifest['approved_source_sha256'])return null;
      final body=jsonDecode(utf8.decode(bytes)) as Map<String,dynamic>;
      final items=body['chapters'] as List<dynamic>;
      if(items.length!=114)return null;
      final selected=items[chapter-1] as Map<String,dynamic>;
      if(selected['number']!=chapter)return null;
      final verses=selected['verses'] as List<dynamic>;
      final catalog=await chapters();
      if (verses.length != catalog[chapter-1].verseCount) {
        return null;
      }
      final result=<Ayah>[];
      for(var i=0;i<verses.length;i++){
        final row=verses[i] as Map<String,dynamic>;
        if(row['number']!=i+1 || row['text'] is! String || (row['text'] as String).isEmpty)return null;
        result.add(Ayah(i+1,row['text'] as String));
      }
      return result;
    }catch(_){return null;}
  }
}
