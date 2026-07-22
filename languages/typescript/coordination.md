# coordination

## 概要
coordination は、TypeScript で非同期・並行・取り消しの実行を扱う実現軸である。
principles の [separation](../../principles/separation.md) が定める副作用の境界と、concerns の [concurrency](../../concerns/concurrency.md) が定める構造化された並行・取り消しの協調・共有可変状態の回避を、TypeScript の機構で満たす。
共有可変状態の回避は、connection が定める module 最上位の可変な singleton の禁止と、retention が定める state の機構の規律で満たす。
取り消しは AbortSignal で計算全体へ伝播し、[effect](../../concerns/effect.md) の取り消しの終了を実現する。
資源は範囲の終わりで解放する。

## 非同期

### 要求
非同期は、コールバックの入れ子より追いやすい逐次の形で書く。これを async/await で満たす。

### 根拠
async/await は非同期の流れを逐次の形で書け、コールバックの入れ子や Promise の連鎖より追いやすい。

### 完了条件
非同期が、async/await で書かれている。

### 禁止事項
非同期の流れを、コールバックの入れ子で表すこと。

### 行動
非同期を async/await で書く。

## 取り消し

### 要求
取り消しは AbortSignal を渡して協調し、fetch には signal を渡す。
時間切れは abort の予約で表す。
絶対期限を文脈として伝播する機構は、標準が固定せず、project が単一の採用を ADR に明記する。

### 根拠
JavaScript の Promise は作成時に実行が始まり、それ自体は止められない。
取り消しは AbortSignal を渡して協調で行い、abort で下流の操作を止める。
fetch に signal を渡せば、abort で通信が止まる。
時間切れを abort の予約で表せば、時間切れも同じ経路で伝わる。

### 完了条件
取り消しが、AbortSignal で協調して伝えられている。
fetch に、signal が渡されている。
時間切れが、abort の予約で表されている。

### 禁止事項
Promise 自体を、止められると見なすこと。
fetch に signal を渡さず、通信を止められなくすること。

### 行動
AbortSignal を fetch や処理に渡し、abort で止める。
時間切れは abort の予約で表す。

### 例
```typescript
// signal を渡さない。通信を止められない
const response = await fetch(url);

// signal を渡し、時間切れは abort の予約で表す
const response = await fetch(url, { signal: AbortSignal.timeout(5000) });
```

## 並行の組

### 要求
並行の組は一つの AbortController に束ね、一つの失敗で残りを abort する。
部分の成功を集める処理にだけ、allSettled を使う。
並行度の上限を固定する機構は、標準が固定せず project が単一の採用を ADR に明記する。

### 根拠
Promise.all は一つが失敗すると即その失敗で返るが、束ねた他の操作は走り続ける。
一つの AbortController に束ねて一つの失敗で残りを abort すれば、無駄な実行を止められる。
allSettled は全ての完了を待つので、部分の成功を集める処理にだけ使う。
JavaScript の標準実行環境は並行度を上限で絞る組み込みの機構を持たないので、上限を固定する具体の機構は project の ADR に単一採用を明記させる。

### 完了条件
並行の組が、一つの AbortController に束ねられている。
一つの失敗で、残りが abort されている。
allSettled が、部分の成功を集める処理にだけ使われている。
並行度の上限を固定する機構が、project の ADR に明記されている。

### 禁止事項
一つが失敗しても、束ねた残りの実行を走らせ続けること。

### 行動
並行の組を一つの AbortController に束ね、一つの失敗で残りを abort する。
部分の成功を集めるときだけ allSettled を使う。

### 例
```typescript
// 一つの AbortController に束ね、一つの失敗で残りを abort する
const controller = new AbortController();
try {
  await Promise.all(urls.map((url) => fetch(url, { signal: controller.signal })));
} catch (error) {
  controller.abort(); // 残りを止める
  throw error;
}
```

## メインスレッドを塞がない

### 要求
重い同期の計算を、viewer のメインスレッドと extension の host のイベント処理で実行しない。
重い同期計算は、Web Worker へ退避する。

### 根拠
browser の実行は単一スレッドで、同期の計算が続く間は描画も入力も止まる。
extension の host も単一のイベントループで、塞ぐと editor の応答が止まる。
Worker へ退避すれば、メインスレッドはイベントの処理へ戻れる。
非同期の見た目に包んだだけの同期計算は、待ちを分割するだけで、実行の間はやはりスレッドを塞ぐ。

### 完了条件
メインスレッドを塞ぐ重い同期計算が、Worker へ退避されている。
退避した計算との受け渡しが、値のメッセージで行われている。

### 禁止事項
重い同期計算を、イベントの処理の中で実行すること。
非同期の見た目に包んだだけの同期計算で、退避を済ませたと称すること。

### 行動
入力から描画までを塞ぐ処理を計測で特定し、Worker へ移す。
Worker との境界は、値のメッセージで受け渡す。

## 後始末

### 要求
購読と資源は解除の手立てを返す形で確保し、範囲の終わりで解放する。
viewer は解除を onCleanup に委ね、extension は購読と資源を host の Disposable として host の購読管理に委ねる。

### 根拠
購読と資源を解除の手立てなく確保すると、範囲を抜けても残り、漏れる。
解除を返す形で確保すれば、範囲の終わりで確実に解放できる。
viewer は SolidJS の反応の範囲の終わりを onCleanup が持ち、extension は host が Disposable の集合を終了時に一括で解放する。

### 完了条件
購読と資源が、解除の手立てを返す形で確保されている。
viewer の購読と資源が、onCleanup で範囲の終わりに解放されている。
extension の購読と資源が、host の Disposable として host の購読管理に登録されている。

### 禁止事項
購読と資源を、解除の手立てなく確保すること。

### 行動
viewer は購読の解除を onCleanup に登録する。
extension は購読と資源を Disposable にし、host の購読管理へ登録する。

### 例
```typescript
// viewer: 解除を onCleanup に登録し、反応の範囲の終わりで解放する
const unsubscribe = source.subscribe(handler);
onCleanup(unsubscribe);

// extension: 購読を Disposable にし、host の購読管理へ登録する。host が終了時に一括 dispose する
const disposable = watcher.onDidChange(handler);
context.subscriptions.push(disposable);
```

## 参照
並行の規律は [concurrency](../../concerns/concurrency.md)、副作用を境界に集める原則は [separation](../../principles/separation.md)、効果の取り消しと資源は [effect](../../concerns/effect.md) に従う。
