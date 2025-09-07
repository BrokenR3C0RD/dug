import 'package:dug/src/compile/compiler_base.dart';
import 'package:dug/src/parse/nodes.dart';

const doctypes = {
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

class SsgCompiler extends CompilerBase {
  final bool pretty;
  bool terse = false;
  bool xml = false;

  SsgCompiler(super.root, {this.pretty = false});

  @override
  void enterDoctype(Doctype node) {
    final doctype = doctypes[node.doctype] ?? '<!DOCTYPE ${node.doctype}>';
    terse = doctype.toLowerCase() == '<!doctype html>';
    xml = doctype.startsWith('<?xml');
    output.write(doctype);
  }

  @override
  void enterAttributeBlock(AttributeBlock node) {
    // TODO: implement enterAttributeBlock
  }

  @override
  void enterBlock(Block node) {
    // TODO: implement enterBlock
  }

  @override
  void enterBlockComment(BlockComment node) {
    // TODO: implement enterBlockComment
  }

  @override
  void enterCase(Case node) {
    // TODO: implement enterCase
  }

  @override
  void enterCode(Code node) {
    // TODO: implement enterCode
  }

  @override
  void enterComment(Comment node) {
    if (!node.buffer) return;
  }

  @override
  void enterConditional(Conditional node) {
    // TODO: implement enterConditional
  }

  @override
  void enterEach(Each node) {
    // TODO: implement enterEach
  }

  @override
  void enterEachOf(EachOf node) {
    // TODO: implement enterEachOf
  }

  @override
  void enterExtends(Extends node) {
    // TODO: implement enterExtends
  }

  @override
  void enterFileReference(FileReference node) {
    // TODO: implement enterFileReference
  }

  @override
  void enterFilter(Filter node) {
    // TODO: implement enterFilter
  }

  @override
  void enterInclude(Include node) {
    // TODO: implement enterInclude
  }

  @override
  void enterIncludeFilter(IncludeFilter node) {
    // TODO: implement enterIncludeFilter
  }

  @override
  void enterInterpolatedTag(InterpolatedTag node) {
    // TODO: implement enterInterpolatedTag
  }

  @override
  void enterMixin(Mixin node) {
    // TODO: implement enterMixin
  }

  @override
  void enterMixinBlock(MixinBlock node) {
    // TODO: implement enterMixinBlock
  }

  @override
  void enterNamedBlock(NamedBlock node) {
    // TODO: implement enterNamedBlock
  }

  @override
  void enterRawInclude(RawInclude node) {
    // TODO: implement enterRawInclude
  }

  @override
  void enterTag(Tag node) {
    // TODO: implement enterTag
  }

  @override
  void enterText(Text node) {
    // TODO: implement enterText
  }

  @override
  void enterWhen(When node) {
    // TODO: implement enterWhen
  }

  @override
  void enterWhile(While node) {
    // TODO: implement enterWhile
  }

  @override
  void exitAttributeBlock(AttributeBlock node) {
    // TODO: implement exitAttributeBlock
  }

  @override
  void exitBlock(Block node) {
    // TODO: implement exitBlock
  }

  @override
  void exitBlockComment(BlockComment node) {
    // TODO: implement exitBlockComment
  }

  @override
  void exitCase(Case node) {
    // TODO: implement exitCase
  }

  @override
  void exitCode(Code node) {
    // TODO: implement exitCode
  }

  @override
  void exitComment(Comment node) {
    // TODO: implement exitComment
  }

  @override
  void exitConditional(Conditional node) {
    // TODO: implement exitConditional
  }

  @override
  void exitDoctype(Doctype node) {
    // TODO: implement exitDoctype
  }

  @override
  void exitEach(Each node) {
    // TODO: implement exitEach
  }

  @override
  void exitEachOf(EachOf node) {
    // TODO: implement exitEachOf
  }

  @override
  void exitExtends(Extends node) {
    // TODO: implement exitExtends
  }

  @override
  void exitFileReference(FileReference node) {
    // TODO: implement exitFileReference
  }

  @override
  void exitFilter(Filter node) {
    // TODO: implement exitFilter
  }

  @override
  void exitInclude(Include node) {
    // TODO: implement exitInclude
  }

  @override
  void exitIncludeFilter(IncludeFilter node) {
    // TODO: implement exitIncludeFilter
  }

  @override
  void exitInterpolatedTag(InterpolatedTag node) {
    // TODO: implement exitInterpolatedTag
  }

  @override
  void exitMixin(Mixin node) {
    // TODO: implement exitMixin
  }

  @override
  void exitMixinBlock(MixinBlock node) {
    // TODO: implement exitMixinBlock
  }

  @override
  void exitNamedBlock(NamedBlock node) {
    // TODO: implement exitNamedBlock
  }

  @override
  void exitRawInclude(RawInclude node) {
    // TODO: implement exitRawInclude
  }

  @override
  void exitTag(Tag node) {
    // TODO: implement exitTag
  }

  @override
  void exitText(Text node) {
    // TODO: implement exitText
  }

  @override
  void exitWhen(When node) {
    // TODO: implement exitWhen
  }

  @override
  void exitWhile(While node) {
    // TODO: implement exitWhile
  }
}
