/*
 * Complex types
 */

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

// Array accesses
const anElement = aHomogeneousArray[1];

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

// Delete
const yetAnotherObject = { a: 0, b: 1 };
delete yetAnotherObject.b;

// Class
class MyClass {
	static protected readonly aValue: number = 123456;
}

class MyOtherClass extends MyClass {}

// typeof as an expression
const typeOfAUnion: string = typeof aUnion;
console.log(typeOfAUnion);
