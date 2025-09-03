import 'dart:io';

import 'package:collection/collection.dart';
import 'package:dug/dug.dart';
import 'package:dug/src/lex/lexer.dart';
import 'package:dug/src/lex/tokens.dart';
import 'package:dug/src/parse/nodes.dart';
import 'package:dug/src/parse/parser.dart';
import 'package:dug/src/parse/walk.dart';
import 'package:source_span/source_span.dart';

bool visit(Node node, void Function(dynamic) _, int depth) {
  final prefix = ' |' * depth;
  print('$prefix ${node.type} (${node.location?.start.toolString})');
  return true;
}

void main() {
  final lexer = Lexer.fromFile(File('main.pug'));
  final parser = Parser.fromLexer(lexer);
  final nodes = parser.parse();

  nodes.stripComments();
  nodes.walkAST(before: visit, includeDependencies: true);
}
