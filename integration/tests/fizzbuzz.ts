for (let i = 0; i < 100; i++) {
	let output = '';
	if (i % 3 === 0)
		output = output + 'fizz';
	if (i % 5 === 0)
		output = output + 'buzz';
	console.log(output);
}
