#!/usr/bin/env node

/**
 * Debug wrapper for ESLint language server
 * 
 * This script wraps the ESLint language server and intercepts messages
 * to log the actual workingDirectory that gets resolved.
 * 
 * Usage:
 *   node debug-server.js
 * 
 * Then configure Neovim to use this script as the ESLint server command.
 */

const fs = require('fs');
const path = require('path');
const readline = require('readline');

// Path to the actual ESLint server
const eslintServerPath = path.join(__dirname, '../../../vscode-eslint/server/out/eslintServer.js');

// Create a log file
const logFile = '/tmp/eslint-server-debug.log';
const logStream = fs.createWriteStream(logFile, { flags: 'a' });

function log(message) {
  const timestamp = new Date().toISOString();
  logStream.write(`[${timestamp}] ${message}\n`);
}

log('='.repeat(80));
log('ESLint Language Server Debug Wrapper Started');
log(`Server path: ${eslintServerPath}`);
log(`CWD: ${process.cwd()}`);
log('='.repeat(80));

// Intercept stdin/stdout
const originalStdin = process.stdin;
const originalStdout = process.stdout;
const originalStderr = process.stderr;

// Create interface to read line-by-line
const rl = readline.createInterface({
  input: originalStdin,
  output: process.stdout,
  terminal: false
});

let buffer = '';
let contentLength = 0;
let inHeader = true;

// Parse LSP messages
rl.on('line', (line) => {
  if (inHeader) {
    if (line === '') {
      // End of headers, next is the content
      inHeader = false;
    } else if (line.startsWith('Content-Length: ')) {
      contentLength = parseInt(line.substring(16));
    }
  }
});

// For now, let's just spawn the actual server and log what we can
const { spawn } = require('child_process');

const serverProcess = spawn('node', [eslintServerPath], {
  stdio: ['pipe', 'pipe', 'pipe']
});

// Forward stdin to server
process.stdin.pipe(serverProcess.stdin);

// Intercept and log messages from server
let serverBuffer = '';
let serverContentLength = 0;
let serverInHeader = true;

serverProcess.stdout.on('data', (data) => {
  process.stdout.write(data);
  
  // Try to parse the message
  const text = data.toString();
  serverBuffer += text;
  
  // Simple message extraction (this is simplified)
  const contentLengthMatch = text.match(/Content-Length: (\d+)/);
  if (contentLengthMatch) {
    log(`Response with Content-Length: ${contentLengthMatch[1]}`);
  }
  
  // Look for workingDirectory in responses
  if (text.includes('workingDirectory')) {
    log('FOUND workingDirectory in response:');
    log(text.substring(Math.max(0, text.indexOf('workingDirectory') - 100), 
                       Math.min(text.length, text.indexOf('workingDirectory') + 500)));
  }
});

serverProcess.stderr.on('data', (data) => {
  const text = data.toString();
  log(`STDERR: ${text}`);
  process.stderr.write(data);
});

serverProcess.on('close', (code) => {
  log(`Server process exited with code ${code}`);
  logStream.end();
  process.exit(code);
});

// Intercept incoming messages from client
const Transform = require('stream').Transform;
const interceptor = new Transform({
  transform(chunk, encoding, callback) {
    const text = chunk.toString();
    
    // Log if this contains configuration
    if (text.includes('workingDirectory') || text.includes('workspace/configuration')) {
      log('REQUEST contains workingDirectory or configuration:');
      log(text.substring(0, Math.min(text.length, 1000)));
    }
    
    this.push(chunk);
    callback();
  }
});

process.stdin.pipe(interceptor).pipe(serverProcess.stdin);
