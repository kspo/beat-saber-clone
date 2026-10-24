#!/usr/bin/env python3
"""Pinned, project-local macOS Godot toolchain and Quest 2 development commands."""
import argparse
import hashlib
import json
import os
import re
from pathlib import Path
import shutil
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
LOCAL = ROOT / '.tools'
ARTIFACTS = ROOT / 'artifacts'
GODOT = LOCAL / 'Godot.app/Contents/MacOS/Godot'
PACKAGE = 'org.godotengine.open_saber_plus.dev'
APK = ARTIFACTS / 'OpenSaberPlus-Quest2-0.8.0-dev.apk'
LOCK = json.loads((ROOT / 'tools/toolchain.lock.json').read_text())


def run(args, **kwargs):
    print('+', ' '.join(map(str, args)), flush=True)
    return subprocess.run(list(map(str, args)), cwd=ROOT, check=True, **kwargs)


def bootstrap():
    if sys.platform != 'darwin':
        raise SystemExit('This pinned bootstrap targets macOS. Use the matching Godot 4.6 editor on other hosts.')
    downloads = LOCAL / 'downloads'
    downloads.mkdir(parents=True, exist_ok=True)
    for name, spec in LOCK['files'].items():
        path = downloads / name
        if not path.exists():
            run(['curl', '-sSL', '--fail', '--retry', '3', spec['url'], '-o', path])
        with path.open('rb') as stream:
            digest = hashlib.new(spec['algorithm'])
            for block in iter(lambda: stream.read(1024 * 1024), b''):
                digest.update(block)
            actual = digest.hexdigest()
        if actual != spec['digest']:
            raise SystemExit(f'Checksum mismatch: {path}; remove this file and retry.')
    if not GODOT.exists():
        with zipfile.ZipFile(downloads / 'godot.zip') as archive:
            archive.extractall(LOCAL)
    GODOT.chmod(0o755)
    (LOCAL / '_sc_').touch()  # macOS self-contained editor data lives next to the .app
    template_dir = LOCAL / 'editor_data/export_templates/4.6.stable'
    template_dir.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(downloads / 'templates.tpz') as archive:
        for name in archive.namelist():
            if name.startswith('templates/android') or name == 'templates/version.txt':
                (template_dir / Path(name).name).write_bytes(archive.read(name))
    vendor = ROOT / 'addons/godotopenxrvendors'
    if not vendor.exists():
        with zipfile.ZipFile(downloads / 'vendors.zip') as archive:
            for item in archive.infolist():
                if item.filename.startswith('asset/addons/') and not item.is_dir():
                    dest = ROOT / item.filename.removeprefix('asset/')
                    dest.parent.mkdir(parents=True, exist_ok=True)
                    dest.write_bytes(archive.read(item))
    ARTIFACTS.mkdir(exist_ok=True)
    print('Verified Godot 4.6-stable and XR Vendors 4.3.1-stable.')


def engine(arguments, log_name):
    if not GODOT.exists():
        raise SystemExit('Run python3 tools/quest.py bootstrap first.')
    ARTIFACTS.mkdir(exist_ok=True)
    output = ARTIFACTS / (log_name + '.log')
    args = [GODOT, '--headless', '--xr-mode', 'off', '--path', ROOT,
            '--log-file', str(ARTIFACTS / (log_name + '-engine.log')), *arguments]
    with output.open('w') as stream:
        result = subprocess.run(list(map(str, args)), cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT, timeout=600 if "--export-debug" in arguments else 120)
    text = output.read_text(errors='replace')
    if result.returncode or 'SCRIPT ERROR:' in text or 'Parse Error:' in text or 'SHADER ERROR:' in text or 'Shader compilation failed' in text:
        print(text[-18000:])
        if 'java.net.SocketException: Operation not permitted' in text:
            print('Gradle cannot open its local socket in this sandbox. Run the same build command in macOS Terminal.')
        raise SystemExit(f'Godot failed; see {output}')
    print(f'Godot completed: {output}')
    return text


def default_java():
    if sys.platform == 'darwin':
        found = subprocess.run(['/usr/libexec/java_home', '-v', '17'],
                               capture_output=True, text=True)
        if found.returncode == 0:
            return found.stdout.strip()
    return os.environ.get('JAVA_HOME', '')


def prepare_android_resources(build):
    """Ignore generated Android files and remove stale Godot resource sidecars."""
    build.mkdir(parents=True, exist_ok=True)
    (build / '.gdignore').touch()
    removed = 0
    # Only Android resource directories: Godot's exported assets legitimately
    # contain .import remaps and must remain intact.
    resource_dirs = [build / 'res', *(build / 'src').glob('*/res')]
    for resources in resource_dirs:
        for sidecar in resources.rglob('*.import'):
            if not sidecar.is_symlink() and sidecar.read_text(errors='replace').startswith('[remap]'):
                sidecar.unlink()
                removed += 1
    if removed:
        print(f'Removed {removed} stale Godot sidecars from Android resources.')
    return removed


def configure_build(sdk, java):
    bootstrap()
    build = ROOT / 'android/build'
    prepare_android_resources(build)
    engine(['--editor', '--import', '--quit'], 'import')
    sdk, java = Path(sdk).expanduser().resolve(), Path(java).expanduser().resolve()
    for path in [sdk / 'platform-tools/adb', sdk / 'platforms/android-35', sdk / 'build-tools/35.0.0', java / 'bin/java']:
        if not path.exists():
            raise SystemExit(f'Missing build dependency: {path}')
    version = subprocess.run([str(java / 'bin/java'), '-version'], capture_output=True, text=True, check=True)
    match = re.search(r'version "(\d+)', version.stderr + version.stdout)
    if not match or int(match.group(1)) not in (17, 21):
        raise SystemExit('Use JDK 17 (recommended) or 21; this Gradle version does not support newer JDKs.')
    settings = LOCAL / 'editor_data/editor_settings-4.6.tres'
    text = settings.read_text()
    replacements = {
        'export/android/java_sdk_path': str(java),
        'export/android/android_sdk_path': str(sdk),
        'export/android/debug_keystore': str(LOCAL / 'debug.keystore'),
        'export/android/debug_keystore_user': 'androiddebugkey',
        'export/android/debug_keystore_pass': 'android',
    }
    for key, value in replacements.items():
        lines = [line for line in text.splitlines() if not line.startswith(key + ' =')]
        text = '\n'.join(lines) + '\n' + key + ' = ' + json.dumps(value) + '\n'
    settings.write_text(text)
    key = LOCAL / 'debug.keystore'
    if not key.exists():
        run([java / 'bin/keytool', '-genkeypair', '-keystore', key, '-storepass', 'android',
             '-alias', 'androiddebugkey', '-keypass', 'android', '-dname', 'CN=OpenSaberPlus Dev',
             '-keyalg', 'RSA', '-keysize', '2048', '-validity', '10000'])
    os.environ['GRADLE_USER_HOME'] = str(LOCAL / 'gradle')
    os.environ['ANDROID_HOME'] = str(sdk)
    os.environ['JAVA_HOME'] = str(java)
    build = ROOT / 'android/build'
    if not (build / 'build.gradle').exists():
        with zipfile.ZipFile(LOCAL / 'editor_data/export_templates/4.6.stable/android_source.zip') as archive:
            archive.extractall(build)
        (ROOT / 'android/.build_version').write_text('4.6.stable')
        (build / 'gradlew').chmod(0o755)
    prepare_android_resources(build)
    # Bootstrap downloads Gradle with curl and verifies it before Java starts.
    # This also permits reuse on hosts where Java cannot access the download CDN.
    wrapper = build / 'gradle/wrapper/gradle-wrapper.properties'
    lines = [line for line in wrapper.read_text().splitlines()
             if not line.startswith(('distributionUrl=', 'distributionSha256Sum='))]
    distribution = LOCAL / 'downloads/gradle-8.11.1-bin.zip'
    lines += ['distributionUrl=' + distribution.as_uri(),
              'distributionSha256Sum=' + LOCK['files'][distribution.name]['digest']]
    wrapper.write_text('\n'.join(lines) + '\n')
    # Keep the current template manifest; enable shell profiling without copying obsolete activities.
    manifest = build / 'src/main/AndroidManifest.xml'
    data = manifest.read_text()
    if '<profileable' not in data:
        data = data.replace('</application>', '<profileable android:shell="true" android:enabled="true" />\n    </application>')
        manifest.write_text(data)
    engine(['--export-debug', 'Quest 2 Dev', str(APK)], 'build')
    if not APK.exists():
        raise SystemExit('Export did not produce an APK; inspect artifacts/build.log.')
    commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    metadata = {'apk': APK.name, 'sha256': hashlib.sha256(APK.read_bytes()).hexdigest(),
                'base_commit': commit, 'working_tree_changes': bool(subprocess.check_output(['git', 'status', '--porcelain'], cwd=ROOT)),
                'toolchain': LOCK, 'device_validation': 'NOT RUN', 'target': 'Quest 2, 72 Hz'}
    APK.with_suffix('.json').write_text(json.dumps(metadata, indent=2) + '\n')
    print(APK)


def adb_command(args, sdk, serial):
    binary = shutil.which('adb') or str(Path(sdk).expanduser() / 'platform-tools/adb')
    return run([binary, *(['-s', serial] if serial else []), *args])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['bootstrap', 'test', 'build', 'install', 'collect'])
    parser.add_argument('--sdk', default=str(Path.home() / 'Library/Android/sdk'))
    parser.add_argument('--java', default=default_java())
    parser.add_argument('--serial', default='')
    args = parser.parse_args()
    if args.command == 'bootstrap': bootstrap()
    elif args.command == 'test':
        engine(['--editor', '--import', '--quit'], 'import')
        text = engine(['res://tests/run.tscn'], 'tests')
        if 'ALL TESTS PASSED' not in text: raise SystemExit('Test completion marker missing.')
        print(text[text.index('TEST SUMMARY'):])
    elif args.command == 'build': configure_build(args.sdk, args.java)
    elif args.command == 'install':
        if not APK.exists(): raise SystemExit('Build the APK first.')
        adb_command(['install', '-r', str(APK)], args.sdk, args.serial)
        adb_command(['shell', 'monkey', '-p', PACKAGE, '1'], args.sdk, args.serial)
    elif args.command == 'collect':
        ARTIFACTS.mkdir(exist_ok=True)
        adb_command(['pull', f'/sdcard/Android/data/{PACKAGE}/files/metrics', str(ARTIFACTS / 'device-metrics')], args.sdk, args.serial)
        adb_command(['logcat', '-d', '-s', 'godot', 'OpenXR', 'OVRPlugin'], args.sdk, args.serial)


if __name__ == '__main__': main()
