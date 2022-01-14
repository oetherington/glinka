/*
 * Functions
 */

// Functions
function adder(a: number, b: number) : number {
	return a + b;
}

const aResult = adder(4, 5);
adder(3, 5);

// Functions with fake this
function subtracter(this: number, amount: number) {}
