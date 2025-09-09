import 'package:dug/src/compile/compiler_base.dart';
import 'package:dug/src/parse/nodes.dart';
import 'package:dug/src/utils.dart';
import 'package:source_span/source_span.dart';

const _doctypes = {
  'html': '<!DOCTYPE html>',
  'xml': '<?xml version="1.0" encoding="utf-8" ?>',
  'transitional':
      '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">',
  'strict':
      '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">',
  'frameset':
      '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Frameset//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-frameset.dtd">',
  '1.1': '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">',
  'basic':
      '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML Basic 1.1//EN" "http://www.w3.org/TR/xhtml-basic/xhtml-basic11.dtd">',
  'mobile':
      '<!DOCTYPE html PUBLIC "-//WAPFORUM//DTD XHTML Mobile 1.2//EN" "http://www.openmobilealliance.org/tech/DTD/xhtml-mobile12.dtd">',
  'plist': '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">',
};

const _whitespaceSensitiveTags = {'pre', 'whitespace'};

class SsgCompiler extends CompilerBase {
  final bool pretty;
  bool terse = false;
  bool xml = false;
  int indent = -1;
  int escapePrettyModeDepth = 0;

  SsgCompiler(super.root, {this.pretty = false});

  void _prettyIndent(int offset, bool newline) {
    if (!pretty || escapePrettyModeDepth != 0) return;
    if (newline) output.writeln();
    output.write('  ' * (indent + offset));
  }

  @override
  bool visitBlock(Block node) {
    final nodes = node.nodes;

    if (nodes.isEmpty) return false;

    if (nodes.length == 1) {
      visit(nodes.single);
    } else {
      var first = true;
      for (final [cur, next] in nodes.windows(2)) {
        if (first && cur is Text && next is Text) {
          _prettyIndent(1, true);
        }
        visit(cur);
        if (cur is Text && next is Text && cur.text.endsWith('\n')) {
          _prettyIndent(1, false);
        }
        first = false;
      }
      visit(nodes.last);
    }

    return false;
  }

  dynamic evaluateExpression(String expr) {
    throw UnimplementedError();
  }

  @override
  bool visitTag(Tag node) {
    indent++;
    if (_whitespaceSensitiveTags.contains(node.name)) escapePrettyModeDepth++;

    final name = node is InterpolatedTag ? evaluateExpression(node.name).toString() : node.name;
    if (pretty && !node.isInline) _prettyIndent(0, true);

    output.write('<$name');
    _visitAttributes(node.attrs, node.attrBlocks);

    if (node.selfClosing && !terse) {
      if (pretty) output.write(' ');
      output.write('/>');
    } else {
      output.write('>');
    }

    final block = node.block;
    if (node.selfClosing) {
      if (node.code != null ||
          block != null &&
              block.nodes.isNotEmpty &&
              block.nodes.any((node) => node is! Text || node.text.trim().isNotEmpty)) {
        throw SourceSpanException('${node.name} is self-closing but has content', node.span);
      }
    } else {
      if (node.code != null) visitCode(node.code!);
      visit(node.block!);

      if (pretty && !(node.isInline || _tagCanInline(node))) {
        _prettyIndent(0, true);
      }
      output.write('</$name>');
    }

    if (_whitespaceSensitiveTags.contains(node.name)) escapePrettyModeDepth--;
    indent--;
    return false;
  }

  static bool _tagCanInline(Tag tag) {
    bool isInline(Node node) {
      if (node is Block) return node.nodes.every(isInline);
      if (node is Text && !node.text.contains('\n')) return true;
      if (node is Tag && node.isInline) return true;
      if (node is Code && node.isInline) return true;
      return false;
    }

    return tag.block?.nodes.every(isInline) ?? true;
  }

  void _visitAttributes(List<Attr> attrs, List<AttributeBlock> attrBlocks) {
    if (attrs.isEmpty && attrBlocks.isEmpty) return;
    // throw UnimplementedError('attributes');
  }

  @override
  bool visitDoctype(Doctype node) {
    final doctype = _doctypes[node.doctype] ?? _doctypes['html'];
    terse = doctype == _doctypes['html'];
    xml = doctype == _doctypes['xml'];
    output.write(doctype);
    return true;
  }

  @override
  bool visitText(Text node) {
    output.write(node.text);
    return true;
  }
}
