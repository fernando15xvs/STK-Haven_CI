import 'dart:io';

/// Detects byte-for-byte duplicates without loading a large MP4 into RAM.
/// No file content, fingerprint, or original path is sent to a server.
class MotivationFileDedup {
  const MotivationFileDedup._();

  static Future<bool> matchesAny(
    File incoming,
    Iterable<File> existingFiles,
  ) async {
    if (!await incoming.exists()) return false;
    final bytes=await incoming.length();
    for(final other in existingFiles){
      if(!await other.exists())continue;
      if(await other.length()!=bytes)continue;
      if(await equalBytes(incoming,other))return true;
    }
    return false;
  }

  static Future<bool> equalBytes(File a,File b) async {
    if(!await a.exists() || !await b.exists())return false;
    if(await a.length()!=await b.length())return false;
    final first=await a.open(mode:FileMode.read);
    RandomAccessFile? second;
    try{
      second=await b.open(mode:FileMode.read);
      while(true){
        final left=await first.read(65536);
        final right=await second.read(65536);
        if(left.length!=right.length)return false;
        if(left.isEmpty)return true;
        for(var i=0;i<left.length;i++){
          if(left[i]!=right[i])return false;
        }
      }
    }finally{
      await first.close();
      if(second!=null)await second.close();
    }
  }
}
