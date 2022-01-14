/*
 * Simple statements and expressions
 */

// Declarations
let aString: string = "string";
var aNumber: number = 2;
const aFloat: number = 2.3_273e-47;
const aBool: boolean = !false;
const aBinOp: number = 2 - 4;
const addNums: number = 2 + 4.543;
const concatStrings: string = "abc" + "def";
const inferredType = "foobar";
let uninitialized: number;

// Assignments
uninitialized = 3;
aNumber = 4;
aNumber += 1;

// Expression statements
aNumber++;
aNumber--;
++aNumber;
--aNumber;
aNumber ? aString : aBool;

// Check output
console.log(aString);
console.log(aNumber);
console.log(aFloat);
console.log(aBool);
console.log(aBinOp);
console.log(addNums);
console.log(concatStrings);
console.log(inferredType);
console.log(uninitialized);
