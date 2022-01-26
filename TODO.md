# TODO

### Language Features

 - [x] Comments
 - [x] Int literals
 - [x] Float literals
 - [x] String/Template literals
 - [x] Boolean literals
 - [x] Null/undefined literals
 - [ ] Regex literals
 - [x] Prefix/postfix operators
 - [x] Binary operators
 - [x] Ternary expressions
 - [x] `var`/`let`/`const`
 - [x] `if`/`else if`/`else`
 - [x] `switch`
 - [x] While loops
 - [x] Do loops
 - [x] C-style for loops
 - [ ] For each loops
 - [x] `throw`
 - [x] `try`/`catch`/`finally`
 - [x] Functions
   - [x] `return`
   - [x] Fake 'this' parameter
   - [ ] Check all code paths return correctly
   - [ ] Inferred return types
   - [ ] Arrow functions
   - [ ] Variadic functions
 - [x] Function calls
 - [x] Unions
 - [ ] Tuples
 - [ ] `unknown` type
 - [ ] `never` type
 - [x] Arrays
   - [x] Array accesses
   - [ ] Array<> generic
 - [x] Type aliases
 - [x] Interfaces
   - [x] Inline with object literal syntax/type aliases
   - [x] `interface` syntax
   - `extends` for interfaces
 - [x] Object literals
 - [x] Object member accesses
 - [ ] Enums
   - [ ] Const enums
   - [ ] Ambient enums
 - [x] `delete`
 - [x] Classes
   - [ ] `new`
   - [x] Member variables
   - [ ] Member functions
   - [ ] `readonly`
   - [ ] `static`
   - [ ] `public`/`protected`/`private`
   - [ ] ECMAscript private fields with '#'
   - [ ] Parameter properties
   - [ ] `constructor`
   - [ ] `destructor`
   - [ ] Accessors with `get`/`set`
   - [ ] `extends` for classes
   - [ ] `abstract class`
   - [ ] `implements`
 - [ ] Generics
 - [ ] Recursive types
 - [ ] Modules/`import`/`export`
 - [ ] `declare`
 - [ ] `namespace`
 - [ ] `async`/`await`
 - [ ] Type casting
 - [ ] Type predicates
 - [ ] Object destructuring
 - [ ] Generator functions/`yield`
 - [ ] Decorators
 - [ ] Symbol/unique symbol
 - [ ] JSX

### Compiler Features

 - [x] Read code from file
 - [x] Read code from stdin
 - [ ] Read `tsconfig` files
 - [ ] GCC style command line interface
 - [ ] Strict flag
 - [ ] `strictNullChecks`

### Bugs

 - [ ] `var` declarations currently have block scoping, not function scoping
 - [ ] Multiple declarations of the same interface are not merged (maybe this should be hidden behind a feature flag?)
