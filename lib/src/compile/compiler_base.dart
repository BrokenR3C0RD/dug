import 'package:dug/src/parse/nodes.dart';


const debug = false;

abstract class CompilerBase {
  final Block root;
  late StringBuffer output;

  CompilerBase(this.root);

  bool visitBlock(Block node) => true;
  bool visitNamedBlock(NamedBlock node) => true;
  bool visitMixinBlock(MixinBlock node) => true;
  bool visitFilter(Filter node) => true;
  bool visitFileReference(FileReference node) => true;
  bool visitIncludeFilter(IncludeFilter node) => true;
  bool visitInclude(Include node) => true;
  bool visitRawInclude(RawInclude node) => true;
  bool visitDoctype(Doctype node) => true;
  bool visitAttributeBlock(AttributeBlock node) => true;
  bool visitMixin(Mixin node) => true;
  bool visitTag(Tag node) => true;
  bool visitBlockComment(BlockComment node) => true;
  bool visitComment(Comment node) => true;
  bool visitText(Text node) => true;
  bool visitCode(Code node) => true;
  bool visitYieldBlock(YieldBlock node) => throw UnimplementedError('');
  bool visitWhile(While node) => true;
  bool visitCase(Case node) => true;
  bool visitWhen(When node) => true;
  bool visitEach(Each node) => true;
  bool visitEachOf(EachOf node) => true;
  bool visitConditional(Conditional node) => true;
  bool visitExtends(Extends node) => true;

  bool visit(Node node) {
    if (debug) print('visiting ${node.type}');
    return switch (node) {
      Block() => visitBlock(node),
      NamedBlock() => visitNamedBlock(node),
      MixinBlock() => visitMixinBlock(node),
      FileReference() => visitFileReference(node),
      Filter() => visitFilter(node),
      IncludeFilter() => visitIncludeFilter(node),
      Include() => visitInclude(node),
      RawInclude() => visitRawInclude(node),
      Doctype() => visitDoctype(node),
      AttributeBlock() => visitAttributeBlock(node),
      Mixin() => visitMixin(node),
      InterpolatedTag() => visitTag(node),
      Tag() => visitTag(node),
      BlockComment() => visitBlockComment(node),
      Comment() => visitComment(node),
      Text() => visitText(node),
      Code() => visitCode(node),
      YieldBlock() => visitYieldBlock(node),
      While() => visitWhile(node),
      Case() => visitCase(node),
      When() => visitWhen(node),
      Each() => visitEach(node),
      EachOf() => visitEachOf(node),
      Conditional() => visitConditional(node),
      Extends() => visitExtends(node),
    };
  }

  String compile() {
    output = StringBuffer();
    root.walkAST(before: (node, _, _) => visit(node), includeDependencies: true);
    return output.toString();
  }
}
