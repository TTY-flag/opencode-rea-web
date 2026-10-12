#!/usr/bin/env bash
set -euo pipefail
umask 077

# Generate only OpenCode configuration. The web service is OpenCode itself.
node <<'NODE'
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const env = process.env;
try {
  for (const name of ['MODEL_BASE_URL', 'MODEL_API_KEY', 'MODEL_ID']) {
    const value = env[name]?.trim();
    if (!value || value.startsWith('replace-with-') || value.includes('your-provider.example')) {
      throw new Error(`请先在 .env 中填写 ${name}。`);
    }
  }
  const url = new URL(env.MODEL_BASE_URL);
  if (!['http:', 'https:'].includes(url.protocol) || url.username || url.password) {
    throw new Error('MODEL_BASE_URL 必须是 http/https 地址，认证信息请填写到 MODEL_API_KEY。');
  }
  const integer = (name, fallback) => {
    const value = Number(env[name] || fallback);
    if (!Number.isSafeInteger(value) || value <= 0 || value > 2147483647) throw new Error(`${name} 必须是正整数。`);
    return value;
  };
  const api = env.MODEL_API || 'openai-compatible';
  if (!['openai-compatible', 'openai-responses'].includes(api)) throw new Error('MODEL_API 支持 openai-compatible 或 openai-responses。');
  const context = integer('MODEL_CONTEXT', 131072);
  const output = integer('MODEL_OUTPUT', 16384);
  if (output >= context) throw new Error('MODEL_OUTPUT 必须小于 MODEL_CONTEXT。');
  const probe = '/workspace/.write-check-' + crypto.randomUUID();
  try { fs.writeFileSync(probe, '', {flag: 'wx'}); fs.unlinkSync(probe); }
  catch { throw new Error('/workspace 无法写入，请检查挂载权限和 APP_UID/APP_GID。'); }
  for (const directory of ['analysis', 'reconstructed']) fs.mkdirSync('/workspace/' + directory, {recursive: true});
  const config = {
    $schema: 'https://opencode.ai/config.json',
    autoupdate: false,
    share: 'disabled',
    model: `analysis/${env.MODEL_ID.trim()}`,
    small_model: `analysis/${env.MODEL_ID.trim()}`,
    enabled_providers: ['analysis'],
    instructions: ['/opt/rea-web/instructions.md'],
    provider: {
      analysis: {
        npm: api === 'openai-responses' ? '@ai-sdk/openai' : '@ai-sdk/openai-compatible',
        name: 'My Analysis Model',
        options: {baseURL: '{env:MODEL_BASE_URL}', apiKey: '{env:MODEL_API_KEY}'},
        models: {[env.MODEL_ID.trim()]: {name: env.MODEL_ID.trim(), limit: {context, output}, tool_call: true}},
      },
    },
    mcp: {
      rea: {
        type: 'local',
        command: ['node', '/opt/tools/node_modules/rea-agents/scripts/rea.mjs', 'mcp'],
        enabled: true,
        timeout: integer('MCP_TIMEOUT_MS', 900000),
        environment: {
          GHIDRA_INSTALL_DIR: env.GHIDRA_INSTALL_DIR,
          JAVA_HOME: env.JAVA_HOME,
          REA_ANALYSIS_PROVIDER: 'ghidra',
          REA_MCP_INPUT_SCHEMA_PROFILE: 'compact',
          REA_GHIDRA_STARTUP_TIMEOUT_MS: String(integer('REA_GHIDRA_STARTUP_TIMEOUT_MS', 600000)),
          GHIDRA_HEADLESS_MAXMEM: env.GHIDRA_HEADLESS_MAXMEM || '2G',
        },
      },
    },
  };
  fs.mkdirSync(path.dirname(env.OPENCODE_CONFIG), {recursive: true});
  fs.writeFileSync(env.OPENCODE_CONFIG, JSON.stringify(config, null, 2) + '\n', {mode: 0o600});
  console.log('配置就绪：工作目录 /workspace；REA 后端 Ghidra；模型 ' + env.MODEL_ID.trim());
} catch (error) { console.error('启动失败：' + error.message); process.exit(1); }
NODE

rea doctor --provider ghidra --json > /tmp/rea-doctor.json
node -e 'const fs=require("node:fs");const d=JSON.parse(fs.readFileSync("/tmp/rea-doctor.json","utf8"));if(!d.healthy){for(const c of d.scope_checks||[])if(!c.ok)console.error(c.name+": "+c.detail);process.exit(1)}'
echo 'Ghidra 环境就绪，Web 无需登录。'
exec "$@"
