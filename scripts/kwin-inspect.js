// KWin script: report only the Float Frame test window (matched by the test clip's name
// so the user's own Haruna window is never touched). console.error lands in the journal.
const wins = workspace.windowList().filter(w => /letterbox-test/.test(w.caption));
console.error("FLOATFRAME-INSPECT count=" + wins.length);
for (const w of wins) {
    const g = w.frameGeometry, c = w.clientGeometry;
    console.error("FLOATFRAME-INSPECT class=" + w.resourceClass + " desktopFile=" + w.desktopFileName
        + " noBorder=" + w.noBorder + " fullScreen=" + w.fullScreen
        + " frame=" + g.width + "x" + g.height + " client=" + c.width + "x" + c.height
        + " normal=" + w.normalWindow + " moveable=" + w.moveable + " resizeable=" + w.resizeable
        + " active=" + w.active);
}
