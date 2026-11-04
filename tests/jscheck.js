#!/usr/bin/env node
// ============================================================================
// JS SYNTAX CHECK
//
// The app is a single ~1.2MB HTML file with an inline <script>, so there is no
// build step and no bundler to catch a typo. This extracts every inline script
// and parses it, which catches the class of error that otherwise only shows up
// as a blank screen in the browser.
//
// Lives in tests/ rather than scratch/ because it is a permanent guard, not a
// one-off probe — scratch gets pruned and this would silently stop running.
// ============================================================================
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const target = process.argv[2] ||
  path.join(__dirname, '..', 'index.html');
const html = fs.readFileSync(target, 'utf8');

// Match <script> blocks that have no src attribute (i.e. inline).
const re = /<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/gi;
let m, n = 0, bad = 0;

while((m = re.exec(html)) !== null){
  n++;
  const code = m[1];
  if(!code.trim()) continue;
  try{
    // Constructing the script does a full parse without executing it.
    new vm.Script(code, { filename: `${path.basename(target)}#inline-${n}` });
  }catch(err){
    bad++;
    // Point at the offending line relative to the extracted block, and also
    // find the approximate offset in the HTML so it can be located directly.
    const lineMatch = /(\d+)/.exec(err.stack || '');
    console.error(`\nSYNTAX ERROR in inline script #${n}: ${err.message}`);
    if(lineMatch){
      const ln = parseInt(lineMatch[1], 10);
      const lines = code.split('\n');
      for(let i = Math.max(0, ln - 3); i < Math.min(lines.length, ln + 2); i++){
        console.error(`  ${String(i + 1).padStart(5)} | ${lines[i]}`);
      }
    }
  }
}

if(bad){
  console.error(`\nJS SYNTAX CHECK FAILED — ${bad} of ${n} inline script(s) did not parse`);
  process.exit(1);
}
console.log(`JS OK — ${n} inline script(s) parsed (${path.basename(target)})`);