import 'package:dug/src/parse/nodes.dart';

abstract class CompilerBase {
  final Block root;
  late StringBuffer output;

  CompilerBase(this.root);

  void enterBlock(Block node) {}
  void enterNamedBlock(NamedBlock node) {}
  void enterMixinBlock(MixinBlock node) {}
  void enterFilter(Filter node) {}
  void enterFileReference(FileReference node) {}
  void enterIncludeFilter(IncludeFilter node) {}
  void enterInclude(Include node) {}
  void enterRawInclude(RawInclude node) {}
  void enterDoctype(Doctype node) {}
  void enterAttributeBlock(AttributeBlock node) {}
  void enterMixin(Mixin node) {}
  void enterInterpolatedTag(InterpolatedTag node) {}
  void enterTag(Tag node) {}
  void enterBlockComment(BlockComment node) {}
  void enterComment(Comment node) {}
  void enterText(Text node) {}
  void enterCode(Code node) {}
  void enterYieldBlock(YieldBlock node) => throw UnimplementedError('');
  void enterWhile(While node) {}
  void enterCase(Case node) {}
  void enterWhen(When node) {}
  void enterEach(Each node) {}
  void enterEachOf(EachOf node) {}
  void enterConditional(Conditional node) {}
  void enterExtends(Extends node) {}

  void exitBlock(Block node) {}
  void exitNamedBlock(NamedBlock node) {}
  void exitMixinBlock(MixinBlock node) {}
  void exitFilter(Filter node) {}
  void exitFileReference(FileReference node) {}
  void exitIncludeFilter(IncludeFilter node) {}
  void exitInclude(Include node) {}
  void exitRawInclude(RawInclude node) {}
  void exitDoctype(Doctype node) {}
  void exitAttributeBlock(AttributeBlock node) {}
  void exitMixin(Mixin node) {}
  void exitInterpolatedTag(InterpolatedTag node) {}
  void exitTag(Tag node) {}
  void exitBlockComment(BlockComment node) {}
  void exitComment(Comment node) {}
  void exitText(Text node) {}
  void exitCode(Code node) {}
  void exitYieldBlock(YieldBlock node) {}
  void exitWhile(While node) {}
  void exitCase(Case node) {}
  void exitWhen(When node) {}
  void exitEach(Each node) {}
  void exitEachOf(EachOf node) {}
  void exitConditional(Conditional node) {}
  void exitExtends(Extends node) {}

  bool _enter(Node node, ReplaceFn _, int _) {
    final _ = switch (node) {
      Block() => enterBlock(node),
      NamedBlock() => enterNamedBlock(node),
      MixinBlock() => enterMixinBlock(node),
      FileReference() => enterFileReference(node),
      Filter() => enterFilter(node),
      IncludeFilter() => enterIncludeFilter(node),
      Include() => enterInclude(node),
      RawInclude() => enterRawInclude(node),
      Doctype() => enterDoctype(node),
      AttributeBlock() => enterAttributeBlock(node),
      Mixin() => enterMixin(node),
      InterpolatedTag() => enterInterpolatedTag(node),
      Tag() => enterTag(node),
      BlockComment() => enterBlockComment(node),
      Comment() => enterComment(node),
      Text() => enterText(node),
      Code() => enterCode(node),
      YieldBlock() => enterYieldBlock(node),
      While() => enterWhile(node),
      Case() => enterCase(node),
      When() => enterWhen(node),
      Each() => enterEach(node),
      EachOf() => enterEachOf(node),
      Conditional() => enterConditional(node),
      Extends() => enterExtends(node),
    };
    return true;
  }

  bool _exit(Node node, ReplaceFn _, int _) {
    final _ = switch (node) {
      Block() => exitBlock(node),
      NamedBlock() => exitNamedBlock(node),
      MixinBlock() => exitMixinBlock(node),
      FileReference() => exitFileReference(node),
      Filter() => exitFilter(node),
      IncludeFilter() => exitIncludeFilter(node),
      Include() => exitInclude(node),
      RawInclude() => exitRawInclude(node),
      Doctype() => exitDoctype(node),
      AttributeBlock() => exitAttributeBlock(node),
      Mixin() => exitMixin(node),
      InterpolatedTag() => exitInterpolatedTag(node),
      Tag() => exitTag(node),
      BlockComment() => exitBlockComment(node),
      Comment() => exitComment(node),
      Text() => exitText(node),
      Code() => exitCode(node),
      YieldBlock() => exitYieldBlock(node),
      While() => exitWhile(node),
      Case() => exitCase(node),
      When() => exitWhen(node),
      Each() => exitEach(node),
      EachOf() => exitEachOf(node),
      Conditional() => exitConditional(node),
      Extends() => exitExtends(node),
    };

    return true;
  }

  String compile() {
    output = StringBuffer();
    root.walkAST(before: _enter, after: _exit, includeDependencies: true);
    return output.toString();
  }
}
