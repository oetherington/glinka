/*
 * Exceptions
 */

try {
	console.log("Beginning try block");
	const aNumber = 4;
	console.log("Before throwing");
	throw true;
	console.log("After throwing");
} catch (e) {
	console.log("Catching exception");
} finally {
	console.log("Running finally block");
}
