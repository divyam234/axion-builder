#!/usr/bin/env python3
"""Fast regression tests; no source sync, image pull, or ROM build."""
import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('patches', ROOT / 'scripts/apply-patches.py')
patches = importlib.util.module_from_spec(spec)
spec.loader.exec_module(patches)


class BuilderTests(unittest.TestCase):
    def run_build_script(self, action='build', last_target=None, ax_result=0, **settings):
        with tempfile.TemporaryDirectory() as directory:
            d = Path(directory)
            builder = d / 'builder'
            (builder / 'scripts').mkdir(parents=True)
            (builder / 'scripts/arm64-env.sh').write_text(
                'configure_arm64_host_build() { :; }; export_active_llvm_env() { :; }\n')
            (d / 'build').mkdir()
            (d / 'build/envsetup.sh').write_text('''
skipGlobs() { printf '%s' "$1" > skip-result; }
axion() {
  printf '%s %s %s' "$1" "$2" "$3" > selection
  export TARGET_PRODUCT="lineage_$1" TARGET_BUILD_VARIANT="$2"
  if [[ "$3" == va ]]; then export WITH_GMS=false;
  else export WITH_GMS=true TARGET_GAPPS_VARIANT="$3"; fi
}
ax() { printf '%s ' "$@" > build-command; return "$AX_RESULT"; }
ccache() { :; }
''')
            keys = d / 'vendor/lineage-priv/keys'
            keys.mkdir(parents=True)
            (keys / 'keys.mk').write_text('fixture')
            (keys / 'releasekey.pk8').write_text('fixture, not a key')
            if last_target is not None:
                (d / '.axion-builder-last-target').write_text(last_target)
            script = (ROOT / 'scripts/in-container.sh').read_text()
            script = script.replace('/srv/axion', str(d)).replace('/builder/', str(builder) + '/')
            env = dict(os.environ, DEVICE='Pong', VARIANT='eng', GMS='core',
                       SKIP_GLOBS='1', AX_RESULT=str(ax_result))
            env.update(settings)
            result = subprocess.run(['bash', '-c', script, 'test-script', action],
                                    env=env, capture_output=True, text=True)
            outputs = {name: (d / name).read_text() for name in
                       ('selection', 'skip-result', 'build-command', '.axion-builder-last-target')
                       if (d / name).exists()}
            return result, outputs

    def run_host(self, **settings):
        with tempfile.TemporaryDirectory() as directory:
            d = Path(directory)
            binaries = d / 'bin'
            binaries.mkdir()
            for name, script in {
                'uname': '#!/bin/sh\necho aarch64\n',
                'podman': '#!/bin/sh\nprintf "%s\\n" "$@"\n',
            }.items():
                p = binaries / name
                p.write_text(script)
                p.chmod(0o755)
            env = os.environ.copy()
            for key in ('DEVICE', 'VARIANT', 'GMS', 'DEVICE_MANIFEST'):
                env.pop(key, None)
            env.update(PATH=str(binaries) + ':' + env['PATH'], AXION_WORK=str(d / 'work'))
            env.update(settings)
            return subprocess.run([str(ROOT / 'axion-builder'), 'status'], env=env,
                                  capture_output=True, text=True)

    def test_existing_defaults(self):
        result = self.run_host()
        self.assertEqual(result.returncode, 0, result.stderr)
        for item in ('DEVICE=lemonades', 'VARIANT=userdebug', 'GMS=gms'):
            self.assertIn(item, result.stdout)

    def test_other_device_and_flavor(self):
        result = self.run_host(DEVICE='Pong', VARIANT='user', GMS='vanilla')
        self.assertEqual(result.returncode, 0, result.stderr)
        for item in ('DEVICE=Pong', 'VARIANT=user', 'GMS=va'):
            self.assertIn(item, result.stdout)

    def test_full_alias(self):
        self.assertIn('GMS=gms', self.run_host(GMS='full').stdout)

    def test_invalid_inputs_stop_before_podman(self):
        for settings in ({'DEVICE': '../lemonades'}, {'DEVICE': 'x;true'},
                         {'VARIANT': 'invalid'}, {'GMS': 'invalid'}):
            result = self.run_host(**settings)
            self.assertEqual(result.returncode, 2, settings)
            self.assertNotIn('podman', result.stdout)

    def test_patch_isolation(self):
        common = patches.load_series(ROOT, 'Pong')
        lemonades = patches.load_series(ROOT, 'lemonades')
        self.assertEqual(len(common), 21)
        self.assertEqual(len(lemonades), 25)
        self.assertFalse(any(p['project'].startswith(('device/oneplus', 'hardware/oplus', 'vendor/oneplus'))
                             for p in common))
        for entry in lemonades:
            self.assertTrue((ROOT / 'patches' / entry['patch']).is_file())

    def test_split_manifest_equals_known_good(self):
        historical = ET.parse(ROOT / 'manifests/known-good.xml').getroot()
        core = ET.parse(ROOT / 'manifests/common.xml').getroot()
        device = ET.parse(ROOT / 'manifests/devices/lemonades.xml').getroot()
        def projects(m):
            return {p.get('path', p.get('name')): p.attrib for p in m.findall('project')}
        all_projects = projects(core)
        self.assertTrue(set(all_projects).isdisjoint(projects(device)))
        all_projects.update(projects(device))
        self.assertEqual(all_projects, projects(historical))
        self.assertEqual(len(projects(device)), 7)
        for p in core.findall('project'):
            self.assertFalse(p.get('path', p.get('name')).startswith(('device/oneplus/', 'kernel/oneplus/', 'hardware/oplus', 'vendor/oneplus/')))

    def test_local_manifest_install_and_overwrite_guard(self):
        with tempfile.TemporaryDirectory() as directory:
            source, destination = Path(directory) / 'in.xml', Path(directory) / 'out.xml'
            source.write_text('<manifest/>')
            command = ['python3', str(ROOT / 'scripts/install-device-manifest.py'),
                       str(source), str(destination)]
            subprocess.run(command, check=True)
            subprocess.run(command, check=True)
            source.write_text('<manifest><project name="example"/></manifest>')
            self.assertNotEqual(subprocess.run(command, capture_output=True).returncode, 0)
            self.assertEqual(destination.read_text(), '<manifest/>')
            source.write_text('<invalid/>')
            self.assertNotEqual(subprocess.run(command, capture_output=True).returncode, 0)

    def test_wrong_device_worktree_guard(self):
        # Exercise the guard before any operations; no Podman required.
        script = (ROOT / 'scripts/in-container.sh').read_text()
        guard = script[script.index('DEVICE='):script.index('case "$ACTION" in')]
        with tempfile.TemporaryDirectory() as directory:
            (Path(directory) / '.axion-builder-device').write_text('lemonades\n')
            env = dict(os.environ, DEVICE='Pong')
            result = subprocess.run(['bash', '-c', 'set -e; set -- build; ' + guard],
                                    cwd=directory, env=env, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('different device', result.stderr)

    def test_configure_uses_requested_cli_arguments_without_build(self):
        result, outputs = self.run_build_script(action='configure')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(outputs['selection'], 'Pong eng core')
        self.assertNotIn('build-command', outputs)

    def test_build_flavors_and_graph_invalidation(self):
        for flavor in ('gms', 'pico', 'core', 'va'):
            result, outputs = self.run_build_script(GMS=flavor)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(outputs['selection'], f'Pong eng {flavor}')
            self.assertEqual(outputs['skip-result'], '0')
            self.assertEqual(outputs['.axion-builder-last-target'], f'Pong:eng:{flavor}\n')
        result, outputs = self.run_build_script(last_target='Pong:eng:core\n')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(outputs['skip-result'], '1')

    def test_build_failure_propagates_without_marking_success(self):
        result, outputs = self.run_build_script(ax_result=42)
        self.assertEqual(result.returncode, 42, result.stderr)
        self.assertNotIn('.axion-builder-last-target', outputs)


if __name__ == '__main__':
    unittest.main()
