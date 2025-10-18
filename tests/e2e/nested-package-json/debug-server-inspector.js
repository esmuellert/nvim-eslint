#!/usr/bin/env node

/**
 * Advanced ESLint Server Debugger with Inspector API
 * 
 * This uses Node.js's inspector API to programmatically debug the ESLint server
 * and extract the actual resolved workingDirectory.
 * 
 * Usage: node debug-server-inspector.js
 */

const inspector = require('inspector');
const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');

const logFile = '/tmp/eslint-server-inspector-debug.log';
const logStream = fs.createWriteStream(logFile, { flags: 'w' });

function log(message) {
  const timestamp = new Date().toISOString();
  const msg = `[${timestamp}] ${message}`;
  logStream.write(msg + '\n');
  console.error(msg); // Also to stderr so it doesn't interfere with LSP protocol
}

log('='.repeat(80));
log('ESLint Language Server Inspector Debugger');
log('='.repeat(80));

// Start the ESLint server with inspector enabled
const eslintServerPath = path.join(__dirname, '../../../vscode-eslint/server/out/eslintServer.js');

log(`Starting server with inspector: ${eslintServerPath}`);

const serverProcess = spawn('node', [
  '--inspect=9229',
  eslintServerPath
], {
  stdio: ['pipe', 'pipe', 'pipe'],
  env: { ...process.env, NODE_OPTIONS: '' }
});

// Forward stdio
process.stdin.pipe(serverProcess.stdin);
serverProcess.stdout.pipe(process.stdout);
serverProcess.stderr.on('data', (data) => {
  const text = data.toString();
  log(`STDERR: ${text}`);
  
  // Check if inspector is ready
  if (text.includes('Debugger listening on')) {
    log('Inspector is ready!');
    setTimeout(() => {
      connectToInspector();
    }, 1000);
  }
  
  process.stderr.write(data);
});

serverProcess.on('close', (code) => {
  log(`Server exited with code ${code}`);
  logStream.end();
  process.exit(code);
});

function connectToInspector() {
  log('Attempting to connect to inspector...');
  
  const session = new inspector.Session();
  session.connect();
  
  log('Inspector session connected');
  
  // Enable debugger
  session.post('Debugger.enable', (err) => {
    if (err) {
      log(`Error enabling debugger: ${err}`);
      return;
    }
    log('Debugger enabled');
    
    // Set up script parsing to find where to set breakpoints
    session.on('Debugger.scriptParsed', (params) => {
      const scriptUrl = params.url;
      
      // Look for the main ESLint server script
      if (scriptUrl.includes('eslintServer.js') || scriptUrl.includes('eslint.ts')) {
        log(`Found script: ${scriptUrl}`);
        // We could set breakpoints here if we knew the exact line numbers
      }
    });
    
    // Listen for console messages
    session.post('Runtime.enable');
    session.post('Console.enable');
    
    session.on('Runtime.consoleAPICalled', (params) => {
      log(`Console: ${JSON.stringify(params.args.map(a => a.value))}`);
    });
  });
}

process.on('SIGTERM', () => {
  log('Received SIGTERM, closing...');
  serverProcess.kill();
  logStream.end();
  process.exit(0);
});

process.on('SIGINT', () => {
  log('Received SIGINT, closing...');
  serverProcess.kill();
  logStream.end();
  process.exit(0);
});
