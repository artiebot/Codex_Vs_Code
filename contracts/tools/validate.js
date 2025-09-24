#!/usr/bin/env node

const fs = require("fs");
const path = require("path");
const Ajv = require("ajv/dist/2020");
const addFormats = require("ajv-formats");

const args = process.argv.slice(2);

if (args.length === 0 || args.length % 2 !== 0) {
  console.error("Usage: node tools/validate.js <schema> <payload> [<schema> <payload> ...]");
  process.exit(1);
}

const ajv = new Ajv({
  allErrors: true,
  strict: false,
  allowUnionTypes: true
});
addFormats(ajv);

const schemaCache = new Map();

function loadJson(filePath) {
  try {
    return JSON.parse(fs.readFileSync(filePath, "utf8"));
  } catch (err) {
    console.error(`Failed to read ${filePath}: ${err.message}`);
    process.exit(1);
  }
}

for (let i = 0; i < args.length; i += 2) {
  const schemaPath = path.resolve(args[i]);
  const payloadPath = path.resolve(args[i + 1]);
  const schema = loadJson(schemaPath);
  const payload = loadJson(payloadPath);

  let validate = schemaCache.get(schemaPath);
  if (!validate) {
    try {
      validate = ajv.compile(schema);
    } catch (err) {
      console.error(`Schema error in ${schemaPath}: ${err.message}`);
      process.exit(1);
    }
    schemaCache.set(schemaPath, validate);
  }

  const valid = validate(payload);
  if (valid) {
    console.log(`✔ ${path.basename(payloadPath)} valid against ${path.basename(schemaPath)}`);
  } else {
    console.error(`✖ ${path.basename(payloadPath)} invalid against ${path.basename(schemaPath)}`);
    for (const issue of validate.errors ?? []) {
      console.error(`  • ${issue.instancePath || "/"} ${issue.message}`);
    }
    process.exitCode = 1;
  }
}

if (process.exitCode) {
  process.exit(1);
}
