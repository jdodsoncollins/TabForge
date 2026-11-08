#!/usr/bin/env python3
"""Record one App Store preview take: seed the draft, record the simulator screen
while the UI test presses real keys, and save the PREVIEW-MARK timings."""
import json, os, re, signal, subprocess, sys, time
from pathlib import Path
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
take, device, runtime = sys.argv[1], sys.argv[2], sys.argv[3]
mode = take.split('-')[0]  # e.g. themes-phone records the 'themes' mode
display = sys.argv[4] if len(sys.argv) > 4 else None  # a closed Duo records its outer display, primary-1
DRAFTS = {
    'phone': 'func run() {\nprint(items)\n}',
    'ipad': 'func run() {\n    let items = [1, 2]\n    print("debug")\n    render(items)\n}',
    'duo': 'let items = \nprint(items)',
    'themes': 'func run() {\n    let items = [1, 2]\n    render(items)\n}',
}
BUNDLE = 'org.example.TabForge'
PRODUCTS = ROOT / 'artifacts/screens-1.1.1/derived/Build/Products'
XCTESTRUN = PRODUCTS / 'ScriptKeyboard_iphonesimulator27.2-arm64-x86_64.xctestrun'
def run(*a, **k): return subprocess.run(a, check=True, capture_output=True, text=True, **k)
sim = run('xcrun', 'simctl', 'create', f'TabForge Preview {take}', device, runtime).stdout.strip()
try:
    run('xcrun', 'simctl', 'boot', sim)
    run('xcrun', 'simctl', 'bootstatus', sim, '-b')
    run('xcrun', 'simctl', 'ui', sim, 'appearance', 'light')
    run('xcrun', 'simctl', 'status_bar', sim, 'override', '--time', '9:41', '--dataNetwork', 'wifi', '--wifiMode', 'active', '--wifiBars', '3', '--batteryState', 'charged', '--batteryLevel', '100')
    run('xcrun', 'simctl', 'install', sim, str(PRODUCTS / 'Debug-iphonesimulator/ScriptKeyboard.app'))
    container = run('xcrun', 'simctl', 'get_app_container', sim, BUNDLE, 'data').stdout.strip()
    run('xcrun', 'simctl', 'spawn', sim, 'defaults', 'write', f'{container}/Library/Preferences/{BUNDLE}', 'playground.draft', '-string', DRAFTS[mode])
    video = HERE / f'{take}-take.mp4'
    rec = subprocess.Popen(['xcrun', 'simctl', 'io', sim, 'recordVideo', '--codec=h264', *([f'--display={display}'] if display else []), '--force', str(video)], stderr=subprocess.PIPE, text=True)
    started = None
    for line in rec.stderr:
        if 'Recording started' in line: started = time.time(); break
    env = dict(os.environ, TEST_RUNNER_TABFORGE_PREVIEW=mode)
    test = subprocess.Popen(['xcodebuild', 'test-without-building', '-xctestrun', str(XCTESTRUN), '-destination', f'platform=iOS Simulator,id={sim}',
        '-only-testing:ScriptKeyboardUITests/AppStoreCaptureTests/testRecordAppPreview', '-resultBundlePath', str(HERE / f'{take}-take.xcresult'),
        '-disableAutomaticPackageResolution', '-skipPackageUpdates'], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, env=env)
    output = []
    for line in test.stdout:
        output.append(line)
        if 'PREVIEW-MARK appearance-dark' in line:
            run('xcrun', 'simctl', 'ui', sim, 'appearance', 'dark')
    test.wait()
    test.stdout = ''.join(output); test.stderr = ''
    time.sleep(1)
    rec.send_signal(signal.SIGINT); rec.wait(timeout=60)
    (HERE / f'{take}-take.log').write_text(test.stdout + test.stderr)
    marks = [(m.group(1), float(m.group(2)) - started) for m in re.finditer(r'PREVIEW-MARK (\S+) ([0-9.]+)', test.stdout)]
    passed = ' passed (' in test.stdout and test.returncode == 0
    (HERE / f'{take}-take.json').write_text(json.dumps({'take': take, 'mode': mode, 'device': device, 'passed': passed, 'recordingStartedEpoch': started, 'marks': marks}, indent=2))
    print(json.dumps({'take': take, 'passed': passed, 'marks': marks}))
finally:
    subprocess.run(['xcrun', 'simctl', 'shutdown', sim], capture_output=True)
    subprocess.run(['xcrun', 'simctl', 'delete', sim], capture_output=True)
