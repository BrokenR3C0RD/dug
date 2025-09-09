import 'dart:io';

import 'package:dug/dug.dart';
import 'package:dug/src/ast_transform/flatten_blocks.dart';
import 'package:dug/src/ast_transform/include_loader.dart';
import 'package:dug/src/ast_transform/link.dart';
import 'package:dug/src/ast_transform/parse_js.dart';
import 'package:dug/src/compile/ssg_compiler.dart';
import 'package:dug/src/lex/lexer.dart';
import 'package:dug/src/parse/nodes.dart';
import 'package:dug/src/parse/parser.dart';
import 'package:dug/src/ast_transform/strip_comments.dart';

bool visit(Node node, void Function(dynamic) _, int depth) {
  final prefix = ' |' * depth;
  print(
    '$prefix ${node.type}${node.span.text.isNotEmpty ? ': ${node.span.text}' : ''} (${node.span.start.toolString})',
  );
  return true;
}

void prettyPrint(Node node) {
  int depth = 0;
  bool before(Node node, void Function(dynamic) _, int _) {
    final prefix = ' |' * depth;
    if (node is! Block) {
      print(
        '$prefix ${node.type}${node.span.text.isNotEmpty ? ': ${node.span.text}' : ''} (${node.span.start.toolString})',
      );
    }

    if (node is Block || node is Include || node is RawInclude || node is Extends) {
      depth++;
    }

    return true;
  }

  bool after(Node node, void Function(dynamic) _, int _) {
    if (node is Block || node is Include || node is RawInclude || node is Extends) {
      depth--;
    }
    return true;
  }

  node.walkAST(before: before, after: after, includeDependencies: true);
}

void main() {
  final lexer = Lexer.fromFile(File('test_files/index.pug'));
  final parser = Parser.fromLexer(lexer);
  var nodes = parser.parse();
  nodes
    ..loadDependencies()
    ..stripComments()
    ..parseJs();

  nodes = nodes.link()..flattenBlocks();

  final compilerOutput = SsgCompiler(nodes, pretty: true).compile();
  print(compilerOutput);
}
