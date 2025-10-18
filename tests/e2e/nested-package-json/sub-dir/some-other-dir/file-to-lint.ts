// Deep nested TypeScript file - this is the problematic one
export function deepNestedFunction() {
  let unusedDeepVar = 42; // Should trigger @typescript-eslint/no-unused-vars
  let y = 'deep'; // Should trigger prefer-const
  console.log('Hello from deep nested dir'); // Should trigger no-console
  
  const data: any = {}; // Should trigger @typescript-eslint/no-explicit-any
  
  if (y == 'deep') { // Should trigger eqeqeq
    return true;
  }
  
  return false;
}
