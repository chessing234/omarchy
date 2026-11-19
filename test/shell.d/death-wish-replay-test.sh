#!/bin/bash

set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

run_node_test <<'JS'
const fs = require('fs')
const vm = require('vm')
const gameDir = root + '/default/games/vibes/death-wish'
const game = fs.readFileSync(gameDir + '/index.html', 'utf8')
const row = '#' + '.'.repeat(30) + '#'
const map = Array.from({length: 18}, (_, i) => i === 0 || i === 17 ? '#'.repeat(32) : row)
map[16] = '#P.G' + '.'.repeat(27) + '#'
const room = {name: 'FIXTURE', hint: '', tint: 'blue', map, saws: []}
// Small rooms keep the check cheap; the real solver and physics still run.
const fixture = game.replace('// </PHYSICS>', 'LEVELS.splice(0, LEVELS.length, ' + JSON.stringify(room) + ', ' + JSON.stringify(room) + ');\n// </PHYSICS>')
const output = []
vm.runInNewContext(fs.readFileSync(gameDir + '/solve.js', 'utf8'), {
  __dirname: gameDir,
  require: name => name === 'fs' ? {readFileSync: () => fixture} : require(name),
  process: {argv: ['node', 'solve.js', '--replay', '2']},
  console: {log: line => output.push(String(line))},
})
assert(/^\.[0-5]+$/.test(output.join('\n')), 'a subset replay keeps room two at index one', output.join('\n'))
JS
