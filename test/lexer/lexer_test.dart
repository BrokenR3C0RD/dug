import 'dart:io';
import 'package:dug/src/lex/lexer.dart';
import 'package:path/path.dart';
import 'package:test/test.dart';

void main() {
  final path = Directory('./test/lexer/cases');
  for (final file in path.listSync().whereType<File>()) {
    test(basenameWithoutExtension(file.path), () {
      final lexer = Lexer.fromFile(file);
      lexer.getTokens();
    });
  }
  
}
