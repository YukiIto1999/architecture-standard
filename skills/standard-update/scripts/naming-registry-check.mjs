#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { markdownBodyLines } from "./markdown-body-lines.mjs";

const args = process.argv.slice(2);
const productsOnly = args.at(-1) === "--products";
if (productsOnly) args.pop();
if (args.length !== 0 && (args.length !== 2 || args[0] !== "--standard-root" || args[1] === "")) {
  console.error("usage: naming-registry-check.mjs [--standard-root ROOT] [--products]");
  process.exit(2);
}
const ROOT = fs.realpathSync(args.length === 2 ? args[1] : fileURLToPath(new URL("../../../", import.meta.url)));

/**
 * 採用欄の説明文と区別した機構の選定宣言の取得
 *
 * 対象範囲は次の見出しか entry 項目までの採用欄
 * 宣言単位は物理改行をまたぐ句点区切りの文
 * 採用の明示は文頭の `採用は` か `追加の採用は` による指定
 * 使用指定は `には` に続く `を使う` か `を使い` による指定
 * 出力指定は `には` に続く `で ... を出力する` による指定
 *
 * @param {string[]} lines - コードフェンス外の Markdown 本文の行
 * @returns {string[]} 物理改行をまたぐ採用の明示文か用途への機構の使用指定文
 */
function adoptionDeclarations(lines) {
  const sentences = [];
  let field = "";
  for (const line of lines) {
    if (/^#+ |^(用途|採用|判断基準|撤回条件)は、/.test(line)) {
      if (field !== "") sentences.push(...field.split("。"));
      field = "";
    }
    if (line.startsWith("採用は、") || field !== "") field += `${line}\n`;
  }
  if (field !== "") sentences.push(...field.split("。"));
  return sentences.map((sentence) => sentence.trim()).filter((sentence) =>
    /^(追加の)?採用は(?:、|\s)/.test(sentence) ||
    /には[\s\S]*(?:を使[うい]|で[\s\S]*を出力する)/.test(sentence)
  );
}

/**
 * 採用エントリの選定宣言から得る製品名の検査用レジストリの構築
 * @returns {{registry: Set<string>, products: Set<string>}} 名前の照合用語と選定宣言に含まれる正規の製品名
 * @throws {@link Error} 採用エントリへのアクセス失敗
 */
function extractRegistry() {
  const AXIS_FILES = new Set(
    ["formation", "translation", "connection", "coordination", "publication", "inspection", "conventions"].map(
      (a) => `${a}.md`
    )
  );
  const ECOSYSTEMS = new Set(["rust", "csharp", "typescript"]);
  const files = [];
  walk(path.join(ROOT, "tools"), files);
  walk(path.join(ROOT, "languages"), files);
  const tokenRe = /[@A-Za-z][A-Za-z0-9_.#+@/-]*/g;
  const registry = new Set();
  const products = new Set();
  for (const file of files) {
    const base = path.basename(file);
    const dir = path.basename(path.dirname(file));
    // 採用の正本でない軸 file による自己許可を防ぐため registry への追加は不可
    if (ECOSYSTEMS.has(dir) && AXIS_FILES.has(base)) continue;
    const lines = markdownBodyLines(fs.readFileSync(file, "utf8"));
    for (const line of lines) {
      if (!line.startsWith("# ") && !line.startsWith("## ")) continue;
      for (const token of line.matchAll(tokenRe)) {
        const product = token[0];
        registry.add(product.startsWith("@") ? product.slice(1) : product);
      }
    }
    for (const declaration of adoptionDeclarations(lines)) {
      for (const token of declaration.matchAll(tokenRe)) {
        const product = token[0];
        registry.add(product.startsWith("@") ? product.slice(1) : product);
        products.add(product);
      }
    }
  }
  return { registry, products };
}

/**
 * レジストリや候補の対象にする Markdown ファイルの収集
 * @param {string} dir - 探索を始めるディレクトリ
 * @param {string[]} out - 発見したパスを末尾へ追加する配列
 * @returns {string[]} 発見したパスを追加済みの入力配列
 * @throws {@link Error} 対象ツリーへのアクセス失敗
 */
function walk(dir, out) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const entryPath = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(entryPath, out);
    else if (entryPath.endsWith(".md")) out.push(entryPath);
  }
  return out;
}

/**
 * 製品名の候補と区別するテストサイズの正本の語彙の取得
 * @param {string[]} files - 候補の対象として列挙済みの Markdown ファイル
 * @returns {Set<string>} サイズの節で定義された分類名
 * @throws {@link Error} 列挙したサイズ定義の読取り失敗
 */
function testSizeVocabulary(files) {
  const definition = files.find((file) => path.relative(ROOT, file) === "structure/tests/layout.md");
  const names = new Set();
  if (definition === undefined) return names;
  let sizes = false;
  for (const line of markdownBodyLines(fs.readFileSync(definition, "utf8"))) {
    if (line.startsWith("## ")) {
      sizes = line === "## サイズによる配置";
      continue;
    }
    const definition = sizes && line.match(/^([A-Z][A-Za-z0-9]*) は、/);
    if (definition) names.add(definition[1]);
  }
  return names;
}

/**
 * 製品名候補から除外する単一バッククォートのコード表記の除去
 * @param {string} line - フェンス外の本文の一行
 * @returns {string} インラインコードを空文字に置き換えた本文
 */
function stripInlineCode(line) {
  return line.replace(/`[^`]*`/g, "");
}

/**
 * 製品の選定宣言と区別する参照先の規律名の除去
 * @param {string} line - フェンス外の本文の一行
 * @param {string} file - 本文を持つ Markdown ファイルのパス
 * @param {Map<string, Set<string>>} headings - 参照先ごとに保持する規律名
 * @returns {string} ローカルリンク直後の正しい規律名だけを除いた本文
 * @throws {@link Error} 参照先の読取り失敗
 */
function stripHeadingCitations(line, file, headings) {
  if (!line.includes("「")) return line;
  return line.replace(/(\[[^\]]+\]\((\.[^#)]*\.md)(?:#[^)]*)?\)\s*(?:の\s*)?)「([^」]+)」/g,
    (citation, link, relative, title) => {
      const target = path.resolve(path.dirname(file), relative);
      const withinRoot = path.relative(ROOT, target);
      if (withinRoot.startsWith("..") || path.isAbsolute(withinRoot)) return citation;
      if (!headings.has(target)) {
        headings.set(target, new Set(
          markdownBodyLines(fs.readFileSync(target, "utf8"))
            .filter((body) => body.startsWith("## "))
            .map((body) => body.slice(3))
        ));
      }
      return headings.get(target).has(title) ? link : citation;
    });
}

/**
 * 採用レジストリとの照合に使う製品名候補の抽出
 * @param {string[]} files - 製品名の記載を調べる Markdown ファイルのパス
 * @param {Set<string>} vocabulary - 採用物でない分類名として正本に定義された語
 * @returns {Array<{file: string, line: number, token: string, text: string}>} 標準 root 相対のパスと元の行番号を持つ候補
 * @throws {@link Error} 対象ファイルの読取り失敗
 */
function findCandidates(files, vocabulary) {
  const candidateRe = /\b[A-Z][A-Za-z0-9_.#+@/-]*/g;
  const found = [];
  const headings = new Map();
  for (const file of files) {
    const lines = markdownBodyLines(fs.readFileSync(file, "utf8"));
    lines.forEach((rawLine, idx) => {
      const trimmed = rawLine.trim();
      if (!trimmed.endsWith("である。")) return;
      const line = stripInlineCode(stripHeadingCitations(trimmed, file, headings));
      let candidateMatch;
      while ((candidateMatch = candidateRe.exec(line))) {
        const tok = candidateMatch[0];
        if (tok.endsWith(".md") || vocabulary.has(tok)) continue;
        if (!/[a-z]/.test(tok)) continue;
        found.push({ file: path.relative(ROOT, file), line: idx + 1, token: tok, text: trimmed });
      }
    });
  }
  return found;
}

const { registry, products } = extractRegistry();
if (productsOnly) {
  console.log([...products].sort().join("\n"));
  process.exit(0);
}

const files = [];
walk(path.join(ROOT, "concerns"), files);
walk(path.join(ROOT, "structure"), files);
for (const language of ["rust", "csharp", "typescript"]) {
  for (const axis of ["formation", "translation", "connection", "coordination", "publication", "inspection", "conventions"]) {
    files.push(path.join(ROOT, "languages", language, `${axis}.md`));
  }
}

const candidates = findCandidates(files, testSizeVocabulary(files));
const violations = candidates.filter((c) => !registry.has(c.token));

console.log(`adoption registry size: ${registry.size}`);
console.log(`violations: ${violations.length}`);
for (const v of violations) {
  console.log(`${v.file}:${v.line}\t${v.token}\t"${v.text}"`);
}
