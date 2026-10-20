/**
 * 文書検証に使うコードフェンス外の行の抽出
 *
 * フェンス記号は行頭の空白に続く三文字以上のバッククォートかチルダ
 * 閉じ記号の構成文字は開始記号と同じ文字
 * 閉じ記号の長さは開始記号以上
 * 閉じ記号の後に許される内容は空白のみ
 * 閉じ記号のないフェンスの除外範囲は文書末尾まで
 *
 * @param {string} text - LF 区切りの Markdown 本文
 * @returns {string[]} フェンスの行を空文字に置き換えた元の行番号順の本文
 */
export function markdownBodyLines(text) {
  let open = "";
  return text.split("\n").map((line) => {
    const marker = line.match(/^\s*(`{3,}|~{3,})/);
    if (marker) {
      if (open === "") {
        open = marker[1];
      } else if (
        marker[1][0] === open[0] &&
        marker[1].length >= open.length &&
        line.slice(marker[0].length).trim() === ""
      ) {
        open = "";
      }
      return "";
    }
    return open === "" ? line : "";
  });
}
