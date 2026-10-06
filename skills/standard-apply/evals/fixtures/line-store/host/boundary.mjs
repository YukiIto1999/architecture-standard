import assert from "node:assert/strict";
import { createRequire } from "node:module";
import { join, resolve } from "node:path";
import { pathToFileURL } from "node:url";

export function checkBoundary(projectPath, mode) {
  assert.ok(["hidden", "map"].includes(mode), `Unknown boundary mode: ${mode}`);
  const project = resolve(projectPath);
  const require = createRequire(join(project, "package.json"));
  const ts = require("typescript");
  const configPath = join(project, "tsconfig.json");
  const config = ts.readConfigFile(configPath, ts.sys.readFile);
  assert.equal(config.error, undefined, "Candidate tsconfig must be readable");
  const parsed = ts.parseJsonConfigFileContent(config.config, ts.sys, project);
  assert.equal(parsed.errors.length, 0, "Candidate tsconfig must be valid");
  const program = ts.createProgram({ rootNames: parsed.fileNames, options: parsed.options });
  const checker = program.getTypeChecker();
  const storagePath = join(project, "src/line-store.ts");
  const storage = program.getSourceFile(storagePath);
  assert.ok(storage, "Fixed storage owner must exist");
  const production = program.getSourceFiles().filter((file) => file.fileName.startsWith(join(project, "src") + "/"));
  const diagnostics = ts.getPreEmitDiagnostics(program).filter((diagnostic) => !diagnostic.file || production.includes(diagnostic.file));
  assert.equal(diagnostics.length, 0, ts.formatDiagnosticsWithColorAndContext(diagnostics, {
    getCurrentDirectory: () => project,
    getCanonicalFileName: (file) => file,
    getNewLine: () => "\n",
  }));
  const moduleSymbol = checker.getSymbolAtLocation(storage);
  assert.ok(moduleSymbol, "Storage owner must export its class");
  const exports = checker.getExportsOfModule(moduleSymbol);
  const storageExport = exports.find((symbol) => symbol.name === "LineStore");
  assert.ok(storageExport, "LineStore export must remain present");
  const classSymbol = storageExport.flags & ts.SymbolFlags.Alias ? checker.getAliasedSymbol(storageExport) : storageExport;
  const declaration = classSymbol.declarations?.find(ts.isClassDeclaration);
  assert.ok(declaration && declaration.getSourceFile() === storage, "LineStore must be owned by its fixed source file");
  const instanceType = checker.getDeclaredTypeOfSymbol(classSymbol);
  const failures = [];

  const isPrivate = (node) => Boolean(node && (
    (node.name && ts.isPrivateIdentifier(node.name)) ||
    ts.getCombinedModifierFlags(node) & ts.ModifierFlags.Private
  ));
  const isMap = (type) => ["Map", "ReadonlyMap", "WeakMap"].includes(type.getSymbol()?.name);
  const isArray = (type) => checker.isArrayType(type) || checker.isTupleType(type) || type.getSymbol()?.name === "ReadonlyArray";
  const collectionIn = (type, seen = new Set()) => {
    if (seen.has(type)) return false;
    seen.add(type);
    if (isMap(type) || isArray(type)) return true;
    if (type.isUnionOrIntersection()) return type.types.some((part) => collectionIn(part, seen));
    if (!(type.flags & ts.TypeFlags.Object)) return false;
    if (type.objectFlags & ts.ObjectFlags.Reference) {
      if (checker.getTypeArguments(type).some((argument) => collectionIn(argument, seen))) return true;
    }
    for (const signature of type.getCallSignatures()) {
      if (collectionIn(signature.getReturnType(), seen)) return true;
    }
    for (const property of type.getProperties()) {
      const node = property.valueDeclaration ?? property.declarations?.[0];
      if (!node || isPrivate(node) || !production.includes(node.getSourceFile())) continue;
      if (collectionIn(checker.getTypeOfSymbolAtLocation(property, node), seen)) return true;
    }
    return false;
  };
  const checkPublic = (type, label) => {
    for (const property of type.getProperties()) {
      const node = property.valueDeclaration ?? property.declarations?.[0];
      if (!node || isPrivate(node)) continue;
      if (collectionIn(checker.getTypeOfSymbolAtLocation(property, node))) {
        failures.push(`${label}.${property.name} exposes a storage collection`);
      }
    }
  };
  checkPublic(instanceType, "LineStore");
  checkPublic(checker.getTypeOfSymbolAtLocation(classSymbol, declaration), "LineStore.static");
  for (const symbol of exports) {
    if (symbol === storageExport) continue;
    const node = symbol.valueDeclaration ?? symbol.declarations?.[0];
    if (node && collectionIn(checker.getTypeOfSymbolAtLocation(symbol, node))) {
      failures.push(`Storage export ${symbol.name} exposes a collection`);
    }
  }

  const isStore = (type) => type.getSymbol() === classSymbol || (
    type.isUnionOrIntersection() && type.types.some(isStore)
  );
  for (const file of production) {
    if (file === storage) continue;
    const visit = (node) => {
      if (ts.isElementAccessExpression(node) && isStore(checker.getTypeAtLocation(node.expression))) {
        failures.push(`${file.fileName}: consumer indexes the storage representation`);
      }
      if (ts.isPropertyAccessExpression(node) && isStore(checker.getTypeAtLocation(node.expression))) {
        if (node.name.text === "lines" || collectionIn(checker.getTypeAtLocation(node))) {
          failures.push(`${file.fileName}: consumer reads a storage collection`);
        }
      }
      ts.forEachChild(node, visit);
    };
    visit(file);
  }

  const privateFields = declaration.members.filter((member) => ts.isPropertyDeclaration(member) && isPrivate(member));
  const privateMaps = privateFields.filter((member) => checker.getTypeAtLocation(member).getSymbol()?.name === "Map");
  const privateArrays = privateFields.filter((member) => isArray(checker.getTypeAtLocation(member)));
  if (mode === "map") {
    if (privateMaps.length === 0) failures.push("Map branch has no private Map storage field");
    if (privateArrays.length > 0) failures.push("Map branch retains array storage fields");
    let writes = 0;
    let reads = 0;
    const mapSymbols = new Set(privateMaps.map((member) => checker.getSymbolAtLocation(member.name)));
    const backedByPrivateMap = (expression, seen = new Set()) => {
      if (seen.has(expression)) return false;
      seen.add(expression);
      if (ts.isParenthesizedExpression(expression) || ts.isNonNullExpression(expression) || ts.isAsExpression(expression)) {
        return backedByPrivateMap(expression.expression, seen);
      }
      const symbol = checker.getSymbolAtLocation(ts.isPropertyAccessExpression(expression) ? expression.name : expression);
      if (symbol && mapSymbols.has(symbol)) return true;
      if (ts.isIdentifier(expression)) {
        const variable = symbol?.valueDeclaration;
        if (variable && ts.isVariableDeclaration(variable) && variable.initializer) {
          return backedByPrivateMap(variable.initializer, seen);
        }
      }
      return false;
    };
    const visit = (node) => {
      if (ts.isCallExpression(node) && ts.isPropertyAccessExpression(node.expression)) {
        const receiver = node.expression.expression;
        if (isMap(checker.getTypeAtLocation(receiver)) && backedByPrivateMap(receiver)) {
          if (node.expression.name.text === "set") writes += 1;
          if (["get", "has", "values", "entries", "keys"].includes(node.expression.name.text)) reads += 1;
        }
      }
      ts.forEachChild(node, visit);
    };
    visit(declaration);
    if (writes === 0 || reads === 0) failures.push("Map branch must write and read its Map storage");
  }
  assert.deepEqual(failures, [], "Fixture-specific storage boundary contract failed");
  return {
    success: true,
    mode,
    storageOwner: "src/line-store.ts#LineStore",
    consumers: production.filter((file) => file !== storage).map((file) => file.fileName.slice(project.length + 1)).sort(),
    privateMapFields: privateMaps.length,
    privateArrayFields: privateArrays.length,
    claimScope: "fixture-source-contract-only",
  };
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  try {
    process.stdout.write(`${JSON.stringify(checkBoundary(process.argv[2], process.argv[3]))}\n`);
  } catch (error) {
    process.stderr.write(`${error.stack ?? error}\n`);
    process.exitCode = 1;
  }
}
