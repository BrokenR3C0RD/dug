import 'dart:io';

import 'package:dug/dug.dart';
import 'package:dug/src/lex/lexer.dart';
import 'package:dug/src/lex/tokens.dart';
import 'package:source_span/source_span.dart';
import 'package:jsparser/jsparser.dart';

class PrintVisitor extends RecursiveVisitor {
  @override
  visit(Node? node) {
    print('$node: ${node?.start}');
    node?.forEach(visit);
  }
}

void main() {
  final lexer = Lexer.fromFile(File('main.pug'));

  // print(lexer.getTokens().join('\n'));

  final parsed = parsejs(r'var x = `Hello, ${world, x + 5}!`');
  final visitor = PrintVisitor();

  visitor.visit(parsed);

}
