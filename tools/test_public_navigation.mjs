// Exercise the actual QML navigation handler without a display or flight hardware.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
const source = fs.readFileSync(new URL('../src/MainWindow/MainWindow.qml', import.meta.url), 'utf8');
const start = source.indexOf('    function navigateWorkspace(');
const finish = source.indexOf('    function showAITuningTool()', start);
assert(start >= 0 && finish > start);
const handler = source.slice(start, finish);
const pages = ['flight', 'plan', 'setup', 'analyze', 'settings', 'ai'];
let cases = 0;
function makeContext(initial, allowed = true) {
    const flyView = { name: 'flight' }, planView = { name: 'plan' }, toolDrawer = { name: 'drawer' };
    let current = initial === 'flight' ? flyView : initial === 'plan' ? planView : toolDrawer;
    const calls = [];
    const c = {
        hdzxWorkspace: initial, hdzxNavigationCommit: false, hdzxOutgoingWorkspace: null,
        flyView, planView, toolDrawer, toolDrawerLoader: { name: initial },
        workspaceSlide: { running: true, settle() { calls.push('settle'); },
            slide(from, to, forward, gesture) { assert(from && to); calls.push({ from, to, forward, gesture }); } },
        allowViewSwitch() { return allowed; }, closeIndicatorDrawer() {},
        visibleWorkspaceItem() { return current; }, releaseInactiveTool() { calls.push('release'); },
        showToolSelectDialog() { calls.push('tools'); },
    };
    for (const [fn, page] of Object.entries({ showFlyView: 'flight', showPlanView: 'plan',
        showVehicleConfig: 'setup', showAnalyzeTool: 'analyze', showSettingsTool: 'settings', showAITuningTool: 'ai' })) {
        c[fn] = () => {
            c.hdzxWorkspace = page;
            current = page === 'flight' ? flyView : page === 'plan' ? planView : toolDrawer;
            if (current === toolDrawer) c.toolDrawerLoader = { name: page };
        };
    }
    vm.createContext(c); vm.runInContext(handler, c);
    return { c, calls };
}
for (const initial of pages) {
    for (const destination of pages) {
        const { c, calls } = makeContext(initial);
        c.navigateWorkspace(destination);
        assert.equal(c.hdzxWorkspace, destination);
        assert.equal(c.hdzxNavigationCommit, false);
        const slides = calls.filter(x => typeof x === 'object');
        assert.equal(slides.length, initial === destination ? 0 : 1);
        if (slides.length) {
            const slide = slides[0];
            const target = destination === 'flight' ? c.flyView : destination === 'plan' ? c.planView
                : !['flight', 'plan'].includes(initial) ? c.toolDrawerLoader : c.toolDrawer;
            assert.equal(slide.to, target);
            assert.equal(slide.forward, pages.indexOf(destination) > pages.indexOf(initial));
        }
        ++cases;
    }
}
for (const destination of [...pages, 'unknown', 'tools']) {
    const { c, calls } = makeContext('flight', false);
    c.navigateWorkspace(destination);
    assert.equal(c.hdzxWorkspace, 'flight'); assert.equal(calls.length, 0); ++cases;
}
{
    const { c, calls } = makeContext('flight'); c.navigateWorkspace('tools');
    assert.deepEqual(calls, ['tools']); ++cases;
}
{
    const { c, calls } = makeContext('flight'); c.navigateWorkspace('unknown');
    assert.equal(c.hdzxWorkspace, 'flight'); assert.equal(calls.length, 0); ++cases;
}
console.log(`Public navigation passed: ${cases} transitions, same-page requests and blocked navigation cases.`);
