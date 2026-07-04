# canonical 層

canonical 層は、契約の意味の正本を定める層である。
操作・型・エラーを、媒体に依らない意味として記述する。
canonical は [layout](./layout.md) の依存に従う。

## 意味の定義

canonical は、操作・型・エラーを意味として定義する。
canonical は、HTTP やプロトコルの詳細を含まない。

## 単一の正本

canonical は、契約の意味の唯一の正本である。
http と protocol は canonical から導き、generated は canonical と binding から導く。
言語の型を、正本にしない。

## 記述

canonical は、TypeSpec で記述する。
TypeSpec を、契約の単一の正本とする。

## 集合の操作

集合を返す操作は、最初から頁を持つ。
続きは opaque な cursor で表し、client はその中身を解釈しない。
cursor は続きの位置だけを表し、認可を含めない。
頁の大きさは任意指定とし、既定値と上限を定義へ書く。上限を超える指定は上限へ丸める。
終端は、次の cursor の不在で表す。
並びは安定とし、同値は一意の鍵で順序を固定する。
絞り込みと並び替えは、操作の定義で宣言した項目に限る。
総数は、既定で返さない。

## 直和の型

判別のある直和は、TypeSpec の `@discriminated` union で書く。
判別のない素の union は、生成先で判別を保てないため canonical に置かない。

## 命名

操作・型・エラーの名前は、業務の意味の語彙で付ける。
command・query・result・view の別を、名前で表す。
HTTP の request・response の語彙を、canonical に持ち込まない。

## 進化

互換のある変化は、追加で行い、読み手は未知の項目を無視する。
破壊的な変化は、独立した版として分け、移行の期限を定める。
恒久的な互換ラッパーや互換専用の層を作らない。
