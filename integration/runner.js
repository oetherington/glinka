const fs = require("fs");
const path = require("path");
const process = require("process");
const child_process = require("child_process");
const ts = require("typescript");

const testDir = __dirname + "/tests";
const nodeExe = "node";
const glinkaExe = __dirname + "/../zig-out/bin/glinka";

function getFiles() {
	const result = [];

	fs.readdirSync(testDir).forEach(file => {
		if (path.extname(file) === ".ts")
			result.push(file);
	});

	return result;
}

async function runCommand(code, command) {
	let resolve, reject;
	const promise = new Promise((resolve_, reject_) => {
		resolve = resolve_;
		reject = reject_;
	});

	const child = child_process.exec(`${command} -`, (err, stdout, stderr) =>
		resolve({ err, stdout, stderr }));

	console.log(code);
	child.stdin.write(code);
	child.stdin.end();

	return promise;
}

function compileTsc(code) {
	return ts.transpileModule(
		code,
		{ compilerOptions: { module: ts.ModuleKind.CommonJS }},
	);
}

async function runNode(code) {
	const compilation = compileTsc(code);
	const js = compilation.outputText;
	const result = await runCommand(js, nodeExe);
	return { js, ...result };
}

function compileGlinka(code) {
	return runCommand(code, glinkaExe);
}

async function runGlinka(code) {
	const compilation = await compileGlinka(code);
	if (compilation.err !== null || compilation.stderr?.length)
		return compilation;
	const js = compilation.stdout;
	const result = await runCommand(js, nodeExe);
	return { js, ...result };
}

function getError({ err, stdout, stderr }) {
	return err ? err : stderr && stderr.length ? stderr : stdout;
}

function showSummaryAndExit(tests) {
	const count = tests.length;
	const errors = [];
	let successCount = 0;

	for (const test of tests) {
		if (test.status.indexOf("Failure") > -1) {
			errors.push(test);
		} else {
			successCount++;
		}
	}

	const successMessage = successCount === 1
		? "1 success"
		: `${successCount} successes`;

	const errorMessage = errors.length === 1
		? "1 failure"
		: `${errors.length} failures`;

	console.log(`Ran ${count} tests: ${successMessage}, ${errorMessage}`);

	let withWithout = 'without';

	if (errors.length) {
		withWithout = 'with';
		console.log("\nSummary of errors:");

		const line = '-'.repeat(process.stdout.columns)
		console.log(line);
		for (const { file, nodeOutput, glinkaOutput } of errors) {
			console.log(`  In ${file}...`);
			console.log(`    Tsc generated JS: ${nodeOutput.js}`);
			console.log(`    Tsc output: ${getError(nodeOutput)}`);
			console.log(`    Glinka generated JS: ${glinkaOutput.js}`);
			console.log(`    Glinka output: ${getError(glinkaOutput)}`);
			console.log(line);
		}
	}

	console.log(`Glinka integration tests complete ${withWithout} errors\n`);

	process.exit(errors.length > 0 ? 1 : 0);
}

async function run() {
	console.clear();

	const files = getFiles();
	let tests = [];

	for (const file of files) {
		const index = tests.length;
		tests.push({ file, status: "Running...", done: false });

		const absPath = `${testDir}/${file}`;
		const code = String(fs.readFileSync(absPath));

		const [ nodeOutput, glinkaOutput ] = await Promise.all([
			runNode(code),
			runGlinka(code),
		]);

		const status = (nodeOutput.err !== null ||
			nodeOutput.stderr.length > 0 ||
			glinkaOutput.err !== null ||
			glinkaOutput.stderr.length > 0 ||
			nodeOutput.stdout !== glinkaOutput.stdout
		)
			? "\u2715 Failure"
			: "\u2714 Success";

		tests[index] = {
			file,
			status,
			nodeOutput,
			glinkaOutput,
			done: true,
		};

		console.clear();
		console.log("Glinka: Running integration tests...");
		console.table(tests, [ "file", "status" ]);

		if (tests.length === files.length && !tests.some(({ done }) => !done))
			showSummaryAndExit(tests);
	}
}

run();
