// Sub-dir level TypeScript file
export function subDirFunction() {
  let unusedVariable = 100; // Should trigger @typescript-eslint/no-unused-vars
  let x = 'test'; // Should trigger prefer-const
  console.log('Hello from sub-dir'); // Should trigger no-console
  
  if (x == 'test') { // Should trigger eqeqeq
    return true;
  }
  
  return false;
}
