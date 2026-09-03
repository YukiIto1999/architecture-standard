# construction

construction は、実装の構成に関する原則を置く。
値を不変に扱い、関数を全域にし、判断と集合を構造化し、パターンを統一し、単純な形を既定にし、投機的な要素を作らない。
副作用をどこに置くかは [separation](../separation/README.md) に従う。

## 規律

- [値を不変に扱い、変換の連なりで組む](./immutable-transformations.md)
- [関数を全域にする](./total-functions.md)
- [業務判断を型と多態で構造化する](./decisions-as-types.md)
- [集合処理を名前のある操作で表す](./named-collection-operations.md)
- [同じ目的に同じパターンを使う](./consistent-patterns.md)
- [単純な形を既定にする](./simplicity-by-default.md)
- [新しい要素を最後に選ぶ](./reuse-before-new.md)
- [投機的で説明できない要素を作らない](./no-speculation.md)
