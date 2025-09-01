import 'dart:io';

import 'package:collection/collection.dart';
import 'package:dug/dug.dart';
import 'package:dug/src/lex/lexer.dart';
import 'package:dug/src/lex/tokens.dart';
import 'package:dug/src/parse/nodes.dart';
import 'package:dug/src/parse/parser.dart';
import 'package:source_span/source_span.dart';

void visit(Node node, [int depth = 0]) {
  final prefix = ' |' * depth;
  switch (node) {
    case Block():
      for (final node in node.nodes) {
        visit(node, depth + 1);
      }
    case Mixin():
      print('$prefix ${node.call ? '+' : ''}${node.name} (${node.location?.start.toolString})');
    case Tag():
      print('$prefix ${node.name} (${node.location?.start.toolString})');
      if (node.block != null) visit(node.block!, depth);
  }
}

void main() {
  final lexer = Lexer.fromFile(File('main.pug'));
  final tokens = lexer.getTokens();
  final parser = Parser.fromLexer(lexer);
  final nodes = parser.parse();

  visit(nodes);
}
