// Local protocol fixture only: this is not the product's web server.
// Exercise OpenCode HTTP -> model stream -> REA MCP without a paid model key.
const http = require('node:http');
const fs = require('node:fs');
const assert = require('node:assert/strict');
if (process.env.MODEL_BASE_URL !== 'http://127.0.0.1:8877/v1') {
  console.error('此脚本只用于独立的本地协议测试容器，MODEL_BASE_URL 必须为 http://127.0.0.1:8877/v1。');
  process.exit(1);
}
const origin = process.env.TEST_WEB_URL || 'http://127.0.0.1:4096';
let observedTool = false;
let receivedToolResult = false;
let checkedParameters = false;
let replayedReasoning = false;
const mock = http.createServer(async (request, response) => {
  if (request.url !== '/v1/chat/completions') { response.writeHead(404).end(); return; }
  let raw = '';
  for await (const chunk of request) raw += chunk;
  const input = JSON.parse(raw);
  const hasTools = input.tools?.some(tool => tool.function?.name === 'rea_binary_session');
  const hasToolResult = input.messages.some(message => message.role === 'tool');
  if (hasTools) {
    assert.equal(input.model, process.env.MODEL_ID);
    if (process.env.MODEL_REASONING_EFFORT) assert.equal(input.reasoning_effort, process.env.MODEL_REASONING_EFFORT);
    if (process.env.MODEL_TEMPERATURE) assert.equal(input.temperature, Number(process.env.MODEL_TEMPERATURE));
    if (process.env.MODEL_TOP_P) assert.equal(input.top_p, Number(process.env.MODEL_TOP_P));
    assert.equal(input.max_tokens, Math.min(Number(process.env.MODEL_OUTPUT || 16384), 32000));
    checkedParameters = true;
  }
  const splitReasoning = input.model === 'MiniMax-M3.1-Flash-Preview';
  if (hasTools && hasToolResult && splitReasoning) {
    assert.ok(input.messages.some(message => message.role === 'assistant' && message.reasoning_content === 'Check the REA connection.'));
    replayedReasoning = true;
  }
  const delta = hasTools && !hasToolResult
    ? { ...(splitReasoning ? {reasoning_content: 'Check the REA connection.'} : {}), tool_calls: [{index: 0, id: 'call_rea_smoke', type: 'function', function: {name: 'rea_binary_session', arguments: '{}'}}] }
    : { content: hasToolResult ? 'REA MCP verified through OpenCode. This is a local test model.' : 'Local test session' };
  if (hasTools && !hasToolResult) observedTool = true;
  if (hasToolResult) receivedToolResult = true;
  response.writeHead(200, {'Content-Type': 'text/event-stream', 'Cache-Control': 'no-cache'});
  const chunk = {id: 'chatcmpl-local-test', object: 'chat.completion.chunk', created: Math.floor(Date.now()/1000), model: input.model, choices: [{index: 0, delta, finish_reason: null}]};
  response.write('data: ' + JSON.stringify(chunk) + '\n\n');
  chunk.choices = [{index: 0, delta: {}, finish_reason: delta.tool_calls ? 'tool_calls' : 'stop'}];
  response.end('data: ' + JSON.stringify(chunk) + '\n\ndata: [DONE]\n\n');
});
async function api(route, options = {}) {
  const response = await fetch(origin + route, {
    headers: {'Content-Type': 'application/json', 'x-opencode-directory': '/workspace'},
    signal: AbortSignal.timeout(180000), ...options,
  });
  assert.ok(response.ok, `${route}: HTTP ${response.status} ${await (!response.ok ? response.text() : '')}`);
  return response.json();
}
(async () => {
  await new Promise(resolve => mock.listen(8877, '127.0.0.1', resolve));
  try {
    const health = await api('/global/health');
    assert.equal(health.healthy, true);
    const ui = await fetch(origin);
    assert.equal(ui.status, 200);
    const html = await ui.text();
    assert.ok(html.toLowerCase().includes('<html'));
    const assetPath = html.match(/<script[^>]+src="([^"]+)"/)?.[1];
    assert.ok(assetPath, 'OpenCode must provide a frontend bundle');
    const asset = await fetch(new URL(assetPath, origin));
    assert.equal(asset.status, 200);
    const mcp = await api('/mcp');
    assert.equal(mcp.rea.status, 'connected');
    const session = await api('/session', {method: 'POST', body: JSON.stringify({title: 'Container web acceptance'})});
    const answer = await api(`/session/${session.id}/message`, {method: 'POST', body: JSON.stringify({model: {providerID: 'analysis', modelID: process.env.MODEL_ID}, parts: [{type: 'text', text: 'Call rea_binary_session and report whether the MCP is connected.'}]})});
    assert.ok(observedTool && receivedToolResult, 'OpenCode must execute the model-requested REA MCP tool and return its result');
    assert.ok(checkedParameters, 'Model parameters must reach the Chat Completions request');
    if (process.env.MODEL_ID === 'MiniMax-M3.1-Flash-Preview') assert.ok(replayedReasoning, 'Tool history must preserve reasoning_content');
    assert.ok(answer.parts.some(part => part.type === 'text' && part.text.includes('REA MCP verified')));
    fs.writeFileSync('/workspace/analysis/web-acceptance.json', JSON.stringify({success: true, sessionID: session.id, webWithoutPassword: true, mcpConnected: true, modelMode: 'local-protocol-fixture', toolRoundTrip: true}, null, 2));
    console.log(JSON.stringify({success: true, sessionID: session.id, webWithoutPassword: true, mcpConnected: true, modelMode: 'local-protocol-fixture', toolRoundTrip: true}));
  } finally { await new Promise(resolve => mock.close(resolve)); }
})().catch(error => { console.error(error.message); process.exitCode = 1; mock.close(); });
