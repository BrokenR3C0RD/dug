import 'package:source_span/source_span.dart';

typedef Visitor = void Function(Node);

abstract class Node {
  String get type;
  final FileSpan? location;

  Node(this.location);

  @override
  String toString() => type;
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

class FileReference extends Node {
  @override
  String get type => 'FileReference';

  String filename;

  FileReference(super.location, this.filename);
}

class IncludeFilter extends Node {
  @override
  String get type => 'IncludeFilter';

  IncludeFilter(super.location);
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

  String val;

  Text(super.location, this.val);
}

class Code extends Node {
  @override
  String get type => 'Code';

  String val;
  bool buffer;
  bool mustEscape;
  bool isInline;

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
