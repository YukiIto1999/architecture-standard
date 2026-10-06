/**
 * 追加済みの行を論理位置に対応させる格納機構
 */
export class LineStore {
  /**
   * 追加順と重複を保持する格納済みの行
   */
  readonly lines: string[] = [];

  /**
   * 次の論理位置への行の追加
   * @param line - 重複も保持する行の文字列
   */
  append(line: string): void {
    this.lines.push(line);
  }
}
