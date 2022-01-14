/*
 * Loops
 */

// C-style for loops
for (let i = 0; i < 10; i++) {
	i += 1;
	console.log(i);
}

// For-each loops
/* TODO: Classes/generics need to be implemented before iterables
for (let element in aHomogeneousArray)
	element += 2;

for (var element of anInhomogeneousArray) {
	null;
}
*/

// While loops
while (true) {
	console.log("while");
	break;
}

let index = 5;
while (index) {
	var aWhileLoopVar = false;
	console.log(index);
	index--;
}

// Do loops
do {
	++index;
	if (index % 3 === 0)
		continue;
	console.log(index);
} while (index < 10);
