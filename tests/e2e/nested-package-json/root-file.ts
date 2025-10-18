// Root level TypeScript file
export function rootFunction() {
  let unusedVar = 42; // Should trigger @typescript-eslint/no-unused-vars
  const shouldBeConst = 'test'; // Should trigger prefer-const
  console.log('Hello from root'); // Should trigger no-console
  
  if (1 == 1) { // Should trigger eqeqeq
    return true;
  }
  
  return false;
}
