import 'package:dug/src/parse/nodes.dart';

extension FlattenBlocks on Block {
  /// Flatten (Named)Blocks inside (Named)Blocks.
  /// 
  /// Should be run after linking.
  void flattenBlocks() {
    final parents = <Node>[];
    walkAST(before: (node, _, _) {
      parents.add(node);
      return true;
    }, after: (node, replace, _) {
      parents.removeLast();
      if ((node is Block || node is NamedBlock) && (parents.lastOrNull is Block || parents.lastOrNull is NamedBlock)) {
        replace((node as dynamic).nodes);
      }
      return true;
    });
  }
}
