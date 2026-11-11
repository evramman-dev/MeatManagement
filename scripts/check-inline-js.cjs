const fs = require("node:fs");
const vm = require("node:vm");

const html = fs.readFileSync("index.html", "utf8");
const scripts = [...html.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/gi)]
  .map(match => match[1])
  .filter(source => source.trim().length > 0);

if (scripts.length === 0) {
  throw new Error("No inline JavaScript blocks were found in index.html");
}

scripts.forEach((source, index) => {
  new vm.Script(source, { filename: `index-inline-${index + 1}.js` });
});

process.stdout.write(`Validated JavaScript syntax in ${scripts.length} inline script block(s).\n`);
