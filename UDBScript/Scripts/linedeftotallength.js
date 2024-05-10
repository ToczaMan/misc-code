/// <reference path="../udbscript.d.ts" />

`#version 4`;
`#name Linedef Total Length`;
`#description Calculates the total length of selected linedefs.`;

let linedefs = UDB.Map.getSelectedLinedefs();

if (linedefs.length === 0) {
    UDB.die("No linedefs highlighted!");
}

UDB.showMessage(`Total length: ${linedefs.reduce((sum, {length}) => sum + length, 0)}`);
