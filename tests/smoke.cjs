const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const { createRequire } = require('node:module');
const req = createRequire('/opt/tools/node_modules/rea-agents/package.json');
const { Client } = req('@modelcontextprotocol/client');
const { StdioClientTransport } = req('@modelcontextprotocol/client/stdio');
const target = process.argv[2] || '/opt/rea-web/tests/fixtures/smoke';
assert.ok(path.isAbsolute(target), 'Provide an absolute container target path');
const outputRoot = '/workspace/analysis';
fs.mkdirSync(outputRoot, { recursive: true });
const directory = fs.mkdtempSync(path.join(outputRoot, 'verification-'));
const hash = () => crypto.createHash('sha256').update(fs.readFileSync(target)).digest('hex');
const before = hash();
const config = JSON.parse(fs.readFileSync(process.env.OPENCODE_CONFIG, 'utf8'));
const entry = config.mcp.rea;
const transport = new StdioClientTransport({ command: entry.command[0], args: entry.command.slice(1), env: { ...process.env, ...entry.environment }, stderr: 'pipe' });
transport.stderr?.on('data', () => {});
const client = new Client({ name: 'rea-web-smoke', version: '0.1.0' }, { capabilities: {} });
let opened = false;
async function call(name, args = {}) {
  const result = await client.callTool({ name, arguments: args }, { timeout: 900000, onprogress: () => {} });
  if (result.isError) throw new Error(name + ': ' + result.content?.find(item => item.type === 'text')?.text);
  const record = result.structuredContent ?? JSON.parse(result.content.find(item => item.type === 'text').text);
  fs.writeFileSync(path.join(directory, name + '.json'), JSON.stringify(record, null, 2));
  console.log(JSON.stringify({ operation: name, success: true, evidence_id: record.evidence_id || null }));
  return record.normalized_result ?? record.result;
}
(async () => {
  try {
    await client.connect(transport);
    const tools = await client.listTools();
    assert.ok(tools.tools.some(tool => tool.name === 'procedure_pseudo_code'));
    await call('open_binary', { path: target, provider_id: 'ghidra' });
    opened = true;
    await call('binary_overview');
    const procedures = await call('list_procedures');
    assert.ok(procedures.length > 0);
    const selected = procedures.find(item => item.value === 'rea_add') ?? procedures.find(item => item.value === 'entry') ?? procedures.find(item => !item.address.startsWith('EXTERNAL:'));
    assert.ok(selected);
    const pseudocode = await call('procedure_pseudo_code', { procedure: selected.address });
    assert.ok(typeof pseudocode === 'string' && pseudocode.includes('{'));
    fs.writeFileSync(path.join(directory, 'pseudocode.c'), pseudocode + '\n');
    const session = await call('binary_session');
    assert.equal(session.analysis_provider_binding.provider.id, 'ghidra');
    await call('export_evidence_bundle', { path: path.join(directory, 'evidence-bundle.json') });
    await call('close_binary');
    opened = false;
    const closed = await call('binary_session');
    assert.equal(closed.open, false);
    assert.equal(hash(), before);
    const summary = { success: true, provider: session.analysis_provider_binding.provider, target, procedureCount: procedures.length, procedure: selected, originalUnchanged: true, outputDirectory: directory };
    fs.writeFileSync(path.join(directory, 'summary.json'), JSON.stringify(summary, null, 2));
    console.log(JSON.stringify(summary));
  } finally {
    if (opened) await client.callTool({ name: 'close_binary', arguments: {} }, { timeout: 60000 }).catch(() => {});
    await client.close();
  }
})().catch(error => { console.error(error.message); process.exitCode = 1; });
