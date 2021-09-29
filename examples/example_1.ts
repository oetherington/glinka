// A C-style comment
/* A C++-style comment */

// Declarations
var aNumber: number = 2;
let aString: string = "string";
const aBool: boolean = !false;
const aBinOp: number = 2 - 4;
const addNums: number = 2 + 4;
const concatStrings: string = "abc" + "def";

// Assignments
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
	var aWhileLoopVar = false;

do
	var aDoLoopVar = false;
while (true);
