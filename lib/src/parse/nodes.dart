import 'dart:collection';

import 'package:source_span/source_span.dart';

typedef Visitor = void Function(Node);
typedef Callback = bool Function(Node node, Function(dynamic node) replace, int depth);

abstract class Node {
  String get type;
  final FileSpan? location;

  Node(this.location);

  @override
  String toString() => type;

  dynamic walkAST({Callback? before, Callback? after, bool includeDependencies = false, Queue<Node>? parents}) {
    dynamic ast = this;

    parents ??= Queue();

    final arrayAllowed =
        parents.isNotEmpty && (parents.first is Block || (parents.first is RawInclude && ast is IncludeFilter));

    List<Node> walkAndMergeNodes(List<Node> nodes) {
      return nodes.fold(<Node>[], (nodes, node) {
        final result = node.walkAST(
          before: before,
          after: after,
          includeDependencies: includeDependencies,
          parents: parents,
        );

        if (result is List<Node>) {
          return nodes..addAll(result);
        } else {
          return nodes..add(result as Node);
        }
      });
    }

    void replace(dynamic replacement) {
      if (replacement is! Node && replacement is! List<Node>) {
        throw ArgumentError.value(replacement, 'replacement', 'must be Node${arrayAllowed ? ' or List<Node>' : ''}');
      }

      if (replacement is List<Node> && !arrayAllowed) {
        throw StateError('replace() can only be called with an array if the last parent is a Block or NamedBlock');
      }
      ast = replacement;
    }

    if (before != null) {
      if (!before(ast, replace, parents.length)) {
        return ast;
      } else if (ast is List<Node>) {
        return walkAndMergeNodes(ast);
      }
    }

    parents.addFirst(ast as Node);

    switch (ast as Node) {
      case Block():
        ast.nodes = walkAndMergeNodes(ast.nodes);
      case Case():
      case Filter():
      case Tag():
      case When():
      case Code():
      case While():
      case EachOf():
        if (ast.block != null) {
          ast.block = ast.block.walkAST(
            before: before,
            after: after,
            parents: parents,
            includeDependencies: includeDependencies,
          );
        }
      case Each():
        if (ast.block != null) {
          ast.block = ast.block.walkAST(
            before: before,
            after: after,
            parents: parents,
            includeDependencies: includeDependencies,
          );
        }
        if (ast.alternate != null) {
          ast.alternate = ast.alternate.walkAST(
            before: before,
            after: after,
            parents: parents,
            includeDependencies: includeDependencies,
          );
        }
      case Conditional():
        if (ast.consequent != null) {
          ast.consequent = ast.consequent.walkAST(
            before: before,
            after: after,
            parents: parents,
            includeDependencies: includeDependencies,
          );
        }
        if (ast.alternate != null) {
          ast.alternate = ast.alternate.walkAST(
            before: before,
            after: after,
            parents: parents,
            includeDependencies: includeDependencies,
          );
        }

      case Include():
        ast.block.walkAST(before: before, after: after, parents: parents, includeDependencies: includeDependencies);
        ast.file.walkAST(before: before, after: after, parents: parents, includeDependencies: includeDependencies);

      case Extends():
        throw UnimplementedError();

      case RawInclude():
        ast.filters = walkAndMergeNodes(ast.filters).cast<IncludeFilter>();
        ast.file.walkAST(before: before, after: after, parents: parents, includeDependencies: includeDependencies);

      case Attr():
      case BlockComment():
      case Comment():
      case Doctype():
      case IncludeFilter():
      case MixinBlock():
      case YieldBlock():
      case Text():
        break;

      case FileReference():
        if (includeDependencies && ast.ast != null) {
          ast.ast.walkAST(before: before, after: after, parents: parents, includeDependencies: includeDependencies);
        }

      default:
        throw StateError('Unexpected node type ${ast.type}');
    }

    parents.removeFirst();
    if (after != null) after(ast, replace, parents.length);
    return ast;
  }
}

class Block extends Node {
  @override
  String get type => 'Block';

  List<Node> nodes;

  Block(super.location, this.nodes);
  factory Block.fromNode(Node node) {
    if (node is Block) {
      return node;
    } else {
      return Block(node.location!.start.pointSpan(), [node]);
    }
  }

  void extend(Node node) {
    if (node is Block) {
      nodes.addAll(node.nodes);
    } else {
      nodes.add(node);
    }
  }
}

class NamedBlock extends Block {
  @override
  String get type => 'NamedBlock';

  String name;
  String mode;

  NamedBlock(super.location, this.name, this.mode, super.nodes);
  factory NamedBlock.fromBlock(Block block, String name, String mode) =>
      NamedBlock(block.location, name, mode, block.nodes);
}

class MixinBlock extends Node {
  @override
  String get type => 'MixinBlock';

  MixinBlock(super.location);
}

class FileReference extends Node {
  @override
  String get type => 'FileReference';

  String filename;
  Node? ast;

  FileReference(super.location, this.filename);
}

class Filter extends Node {
  @override
  String get type => 'Filter';
  String name;
  List<Attr> attrs;
  Block block;

  Filter(super.location, this.name, this.attrs, this.block);
}

class IncludeFilter extends Node {
  @override
  String get type => 'IncludeFilter';
  String name;
  List<Attr> attrs;

  IncludeFilter(super.location, this.name, this.attrs);
}

class Include extends Node {
  @override
  String get type => 'Include';

  FileReference file;
  Block block;

  Include(super.location, this.file, this.block);
}

class RawInclude extends Node {
  @override
  String get type => 'RawInclude';

  FileReference file;
  List<IncludeFilter> filters;

  RawInclude(super.location, this.file, this.filters);
}

class Doctype extends Node {
  @override
  String get type => 'Doctype';

  String doctype;

  Doctype(super.location, this.doctype);
}

class Attr {
  FileSpan location;
  String name;
  Object val;
  bool mustEscape;

  Attr(this.location, this.name, this.val, {required this.mustEscape});

  @override
  String toString() => '$name = $val';
}

class AttributeBlock extends Node {
  @override
  String get type => 'AttributeBlock';

  final String val;

  AttributeBlock(super.span, this.val);
}

class Tag extends Node {
  @override
  String get type => 'Tag';

  String name;
  bool selfClosing;
  Block? block;
  List<Attr> attrs = [];
  List<AttributeBlock> attrBlocks = [];
  bool isInline;
  bool textOnly = false;
  Code? code;

  Tag(super.span, this.name, {required this.selfClosing, required this.isInline, required this.block});
}

class Comment extends Node {
  @override
  String get type => 'Comment';

  String val;
  bool buffer;

  Comment(super.location, this.val, {required this.buffer});
}

class BlockComment extends Comment {
  @override
  String get type => 'BlockComment';

  Block? block;

  BlockComment(super.location, super.val, this.block, {required super.buffer});
}

class Text extends Node {
  @override
  String get type => 'Text';

  String? val;
  bool isHtml;

  Text(super.location, this.val, {this.isHtml = false});
}

class Code extends Node {
  @override
  String get type => 'Code';

  String val;
  bool buffer;
  bool mustEscape;
  bool isInline;
  Block? block;

  Code(super.location, this.val, {required this.buffer, required this.mustEscape, required this.isInline});
}

class Mixin extends Tag {
  @override
  String get type => 'Mixin';

  String? args;
  bool call;

  Mixin(super.location, super.name, this.args, {required this.call, required super.block})
    : super(isInline: false, selfClosing: false);
}

/// NOTE: `expr` in Pug = `name` in Dart
class InterpolatedTag extends Tag {
  @override
  String get type => 'InterpolatedTag';

  InterpolatedTag(super.span, super.name, {required super.selfClosing, required super.isInline, required super.block});
}

class YieldBlock extends Node {
  @override
  String get type => 'YieldBlock';

  YieldBlock(super.location);
}

class While extends Node {
  @override
  String get type => 'While';

  String test;
  Block? block;

  While(super.location, this.test);
}

class Case extends Node {
  @override
  String get type => 'Case';
  String expr;
  Block? block;

  Case(super.location, this.expr);
}

class When extends Node {
  @override
  String get type => 'When';
  String expr;
  Block? block;

  When(super.location, this.expr, this.block);

}

class Each extends Node {
  @override
  String get type => 'Each';

  String? key;
  String val;
  String obj;
  Block block;
  Block? alternate;

  Each(super.location, this.key, this.val, this.obj, this.block);
}

class EachOf extends Node {
  @override
  String get type => 'EachOf';

  String val;
  String obj;
  Block block;

  EachOf(super.location, this.val, this.obj, this.block);
}

class Conditional extends Node {
  @override
  String get type => 'Conditional';

  bool unless;
  String test;
  Block consequent;
  Node? alternate;

  Conditional(super.location, this.unless, this.test, this.consequent);
}

class Extends extends Node {
  @override
  String get type => 'Extends';

  FileReference file;

  Extends(super.location, this.file);
}
