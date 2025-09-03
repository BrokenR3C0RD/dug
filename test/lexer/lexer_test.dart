import 'dart:io';
import 'package:dug/src/lex/lexer.dart';
import 'package:dug/src/parse/parser.dart';
import 'package:path/path.dart';
import 'package:test/test.dart';

void main() {
  final path = Directory('./test/lexer/cases');
  for (final file in path.listSync().whereType<File>()) {
    test('lex: ${basenameWithoutExtension(file.path)}', () {
      final lexer = Lexer.fromFile(file);
      lexer.getTokens();
    });

    test('parse: ${basenameWithoutExtension(file.path)}', () {
      final parser = Parser.fromLexer(Lexer.fromFile(file));
      parser.parse();
    });
  }
  
}
