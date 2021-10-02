// A C-style comment
/* A C++-style comment */

// Declarations
var aNumber: number = 2;
let aString: string = "string";
const aBool: boolean = !false;
const aBinOp: number = 2 - 4;
const addNums: number = 2 + 4;
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

// Conditionals
if (aNumber)
	aNumber = 4;
else if (aBool)
	aNumber = 5;
else if (aString)
	aNumber = 6;
else
	aNumber = 7;

// Loops
while (true)
	break;

while (true) {
	var aWhileLoopVar = false;
}

do {
	continue;
} while (true);

// Exceptions
throw true;

try {
	const aNumber = 4;
} catch (e) {
	e;
} finally {
	3 + 4;
}

// Functions
function adder(a: number, b: number) : number {
	a + b;
}
