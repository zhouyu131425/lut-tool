#!/usr/bin/env node
import { copyFile, mkdir, readFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { dirname, join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const sourcePath = join(repoRoot, '照片LUT调色工具.html');
const targets = [
  join(repoRoot, 'desktop', '照片LUT调色工具.html'),
  join(repoRoot, 'ios', 'LutTool', 'index.html'),
  join(repoRoot, 'android', 'www', 'index.html'),
];

const checkOnly = process.argv.includes('--check');
const sha256 = async (filePath) =>
  createHash('sha256').update(await readFile(filePath)).digest('hex');

let sourceHash;
try {
  sourceHash = await sha256(sourcePath);
} catch (error) {
  console.error(`找不到主页面源文件：${relative(repoRoot, sourcePath)}`);
  process.exit(1);
}

let hasMismatch = false;
let syncedCount = 0;
let unchangedCount = 0;

for (const targetPath of targets) {
  const relativePath = relative(repoRoot, targetPath);
  let targetHash = null;

  try {
    targetHash = await sha256(targetPath);
  } catch {
    targetHash = null;
  }

  if (targetHash === sourceHash) {
    unchangedCount += 1;
    console.log(`已一致：${relativePath}`);
    continue;
  }

  hasMismatch = true;

  if (checkOnly) {
    console.error(`不同步：${relativePath}`);
    continue;
  }

  await mkdir(dirname(targetPath), { recursive: true });
  await copyFile(sourcePath, targetPath);
  syncedCount += 1;
  console.log(`已同步：${relativePath}`);
}

console.log('');
console.log(`源文件：${relative(repoRoot, sourcePath)}`);
console.log(`SHA-256：${sourceHash}`);

if (checkOnly) {
  if (hasMismatch) {
    console.error('页面副本不同步。请运行：node scripts/sync-html.mjs');
    process.exit(1);
  }
  console.log(`校验通过：${targets.length} 个平台副本全部一致。`);
} else {
  console.log(`完成：新增同步 ${syncedCount} 个，原本一致 ${unchangedCount} 个。`);
}
