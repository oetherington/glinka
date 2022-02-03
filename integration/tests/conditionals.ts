/*
 * Branching statements
 */

// Declarations
let aString: string = "string";
var aNumber: number = 2;
const aBool: boolean = !false;

// If statements
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
		aString = "a";
	case 2:
		aBool = false;
		break;
	default:
		aString = "b";
		break;
}

// Check output
console.log(aString);
console.log(aNumber);
console.log(aBool);
