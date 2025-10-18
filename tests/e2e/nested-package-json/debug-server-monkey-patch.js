#!/usr/bin/env node

/**
 * ESLint Server Debug Wrapper with Monkey Patching
 * 
 * This script loads the ESLint server module and monkey-patches it to log
 * the actual resolved workingDirectory value.
 * 
 * Usage: node debug-server-monkey-patch.js
 */

const fs = require('fs');
const path = require('path');
const Module = require('module');

const logFile = '/tmp/eslint-server-monkey-patch.log';
const logStream = fs.createWriteStream(logFile, { flags: 'w' });

function log(message) {
  const timestamp = new Date().toISOString();
  const msg = `[${timestamp}] ${message}`;
  logStream.write(msg + '\n');
  console.error(msg);
}

log('='.repeat(80));
log('ESLint Language Server Debug Wrapper (Monkey Patch)');
log(`CWD: ${process.cwd()}`);
log('='.repeat(80));

// Monkey-patch the path module to intercept file system operations
const originalJoin = path.join;
path.join = function(...args) {
  const result = originalJoin.apply(this, args);
  
  // Log when workingDirectory-related paths are constructed
  const stackTrace = new Error().stack;
  if (stackTrace && (stackTrace.includes('workingDirectory') || stackTrace.includes('getWorkingDirectory'))) {
    log(`path.join called: ${JSON.stringify(args)} => ${result}`);
    log(`Stack: ${stackTrace.split('\n').slice(0, 5).join('\n')}`);
  }
  
  return result;
};

// Intercept process.chdir to see when working directory changes
const originalChdir = process.chdir;
process.chdir = function(directory) {
  log(`!!! process.chdir called with: ${directory}`);
  log(`!!! Stack: ${new Error().stack.split('\n').slice(0, 5).join('\n')}`);
  return originalChdir.call(this, directory);
};

// Intercept require to patch ESLint modules
const originalRequire = Module.prototype.require;
Module.prototype.require = function(id) {
  const module = originalRequire.apply(this, arguments);
  
  // If this is the ESLint module, patch its methods
  if (id.includes('eslint') && module && typeof module === 'object') {
    // Try to find and patch ESLint class
    if (module.ESLint && typeof module.ESLint === 'function') {
      log(`Found ESLint class in module: ${id}`);
      
      const OriginalESLint = module.ESLint;
      module.ESLint = class PatchedESLint extends OriginalESLint {
        constructor(options) {
          log(`!!! ESLint constructor called with options:`);
          log(JSON.stringify(options, null, 2));
          
          if (options && options.cwd) {
            log(`!!! FOUND CWD in ESLint options: ${options.cwd}`);
          }
          
          super(options);
        }
      };
      
      // Copy static methods
      Object.setPrototypeOf(module.ESLint, OriginalESLint);
      Object.assign(module.ESLint, OriginalESLint);
    }
    
    // Also check for CLIEngine (older API)
    if (module.CLIEngine && typeof module.CLIEngine === 'function') {
      log(`Found CLIEngine class in module: ${id}`);
      
      const OriginalCLIEngine = module.CLIEngine;
      module.CLIEngine = class PatchedCLIEngine extends OriginalCLIEngine {
        constructor(options) {
          log(`!!! CLIEngine constructor called with options:`);
          log(JSON.stringify(options, null, 2));
          
          if (options && options.cwd) {
            log(`!!! FOUND CWD in CLIEngine options: ${options.cwd}`);
          }
          
          super(options);
        }
      };
      
      Object.setPrototypeOf(module.CLIEngine, OriginalCLIEngine);
      Object.assign(module.CLIEngine, OriginalCLIEngine);
    }
  }
  
  return module;
};

// Now load the actual ESLint server
log('Loading ESLint server...');
const eslintServerPath = path.join(__dirname, '../../../vscode-eslint/server/out/eslintServer.js');

try {
  require(eslintServerPath);
  log('ESLint server loaded successfully');
} catch (error) {
  log(`Error loading ESLint server: ${error}`);
  log(`Stack: ${error.stack}`);
  process.exit(1);
}

// Cleanup on exit
process.on('exit', () => {
  logStream.end();
});

process.on('SIGTERM', () => {
  log('Received SIGTERM');
  process.exit(0);
});

process.on('SIGINT', () => {
  log('Received SIGINT');
  process.exit(0);
});
