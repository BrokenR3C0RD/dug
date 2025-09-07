import 'package:collection/collection.dart';
import 'package:dug/src/parse/nodes.dart';
import 'package:source_span/source_span.dart';

extension Link on Block {
  void _findDeclaredBlocks() {
    declaredBlocks = {};
    walkAST(
      before: (node, _, _) {
        if (node is NamedBlock && node.mode == 'replace') {
          declaredBlocks!.putIfAbsent(node.name, () => []).add(node);
        }
        return true;
      },
    );
  }

  Block link() {
    final Extends? extendsNode;

    final firstAfterUnbuffered = nodes.firstWhereOrNull(
      (node) =>
          ((node is! Comment || node.buffer) &&
          (node is! Text || node.val?.isNotEmpty == true) &&
          (node is! Code || node.buffer)),
    );

    if (firstAfterUnbuffered is Extends) {
      extendsNode = firstAfterUnbuffered;
    } else {
      extendsNode = null;
    }

    // Verify there isn't an extends placed in the wrong location
    walkAST(
      before: (node, _, _) {
        if (node is Extends && node != extendsNode) {
          throw SourceSpanException(
            'invalid `extends` position. '
            '`extends` must be the first unbuffered top-level statement in a file (with includes considered).',
            node.span,
          );
        }
        return true;
      },
    );

    _findDeclaredBlocks();

    if (extendsNode != null) {
      final beforeExtends = nodes.takeWhile((node) => node != extendsNode)..toList();
      final afterExtends = nodes.skipWhile((node) => node != extendsNode).skip(1)..toList();

      final mixins = <Mixin>[];
      final expectedBlocks = <String, NamedBlock>{};

      void addNode(Node node) {
        if (node is NamedBlock) {
          expectedBlocks[node.name] = node;
        } else if (node is Mixin && !node.call) {
          mixins.add(node);
        } else if (node is Block) {
          node.nodes.forEach(addNode);
        } else {
          throw SourceSpanException(
            'Only named blocks and mixin definitions can appear at the top level of an extending template (found ${node.type})',
            node.span,
          );
        }
      }

      afterExtends.forEach(addNode);

      final parent = extendsNode.file.ast!.link();
      _extend(parent.declaredBlocks!);

      for (final MapEntry(key: name, value: block) in declaredBlocks!.entries) {
        parent.declaredBlocks![name] = block;
      }

      parent.nodes = [...beforeExtends, ...mixins, ...parent.nodes];
      return parent;
    }

    return this;
  }

  static List<NamedBlock> _flattenParentBlocks(List<NamedBlock> parentBlocks, [List<NamedBlock>? accumulator]) {
    accumulator ??= [];

    for (final parentBlock in parentBlocks) {
      if (parentBlock.parents != null) {
        _flattenParentBlocks(parentBlock.parents!, accumulator);
      }
      accumulator.add(parentBlock);
    }
    return accumulator;
  }

  void _extend(Map<String, List<NamedBlock>> parentBlocks) {
    final stack = {};
    walkAST(
      before: (node, _, _) {
        if (node is! NamedBlock) return true;
        if (stack.containsKey(node.name)) {
          node.ignore = true;
          return true;
        }
        stack[node.name] = node.name;

        final parentBlockList = parentBlocks.containsKey(node.name)
            ? _flattenParentBlocks(parentBlocks[node.name]!)
            : <NamedBlock>[];

        if (parentBlockList.isNotEmpty) {
          node.parents = parentBlockList;
          for (final parentBlock in parentBlockList) {
            switch (node.mode) {
              case 'append':
                parentBlock.nodes.addAll(node.nodes);
              case 'prepend':
                parentBlock.nodes = [...node.nodes, ...parentBlock.nodes];
              case 'replace':
                parentBlock.nodes = node.nodes;
            }
          }
        } else {
          throw SourceSpanException('Unexpected block ${node.name}', node.span);
        }
        return true;
      },
      after: (node, _, _) {
        if (node is NamedBlock && !node.ignore) {
          stack.remove(node.name);
        }
        return true;
      },
    );
  }
}
