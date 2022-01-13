// A C-style comment
/* A C++-style comment */

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

// Conditionals
if (aNumber)
	aNumber = 4;
else if (aBool)
	aNumber = 5;
else if (aString)
	aNumber = 6;
else
	aNumber = 7;

// Switch
switch (aNumber) {
	case 1:
		break;
	case 2:
		null;
	default:
		break;
}

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
	return a + b;
}

const aResult = adder(4, 5);
adder(3, 5);

// Functions with fake this
function subtracter(this: number, amount: number) {}

// Unions
let aUnion: string|number = "hello world";
aUnion = 4;

// Arrays
let anEmptyArray: string[] = [];
let aHomogeneousArray: number[] = [ 1, 2, 3 ];
let anInhomogeneousArray: (string|number|boolean)[] = [ 1, 'a', true ];
aHomogeneousArray = [ 4, 5, 6 ];
anInhomogeneousArray = [ 'a', 'b', 'c' ];
anInhomogeneousArray = [ 1, 1, 2, 3, 5, 8, 13, ];
anInhomogeneousArray = [ true, true, false, ];
anInhomogeneousArray = [ false, 0, ];

const anElement = aHomogeneousArray[1];

// Loops
for (let i = 0; i < 10; i++)
	i += 1;

/* TODO: Objects need to be implemented before iterables
for (let element in aHomogeneousArray)
	element += 2;

for (var element of anInhomogeneousArray) {
	null;
}
*/

while (true)
	break;

while (true) {
	var aWhileLoopVar = false;
}

do {
	continue;
} while (true);

// Type aliases
type IntOrString = number | string;

let aliasTest1: IntOrString = 6;
aliasTest1 = 'hello world';

let aliasTest2: number | string = aliasTest1;
aliasTest2 = 4;
aliasTest1 = aliasTest2;

// Null and undefined can be used as values or type names
const aNullVariable: null = null;
const anUndefinedVariable: undefined = undefined;

// Interface types and object literals
let anObject: { a: number, b: string } = { a: 0, b: 'a string' };

interface AnInterface {
	maybeNum: number | null;
	aString: string;
}

const anotherObject: AnInterface = { maybeNum: null, aString: "hello" };

// Console
console.log("Hello world");

// Delete
const anotherObject = { a: 0, b: 1 };
// delete anotherObject.b;
