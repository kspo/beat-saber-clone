import tempfile
import unittest
from pathlib import Path

from quest import prepare_android_resources


class AndroidResourcePreparationTests(unittest.TestCase):
    def test_removes_stale_resource_sidecars_without_touching_exported_assets(self):
        with tempfile.TemporaryDirectory() as directory:
            build = Path(directory)
            sidecars = [build / 'res/mipmap/icon.webp.import',
                        build / 'src/debug/res/drawable/icon.png.import']
            for sidecar in sidecars:
                sidecar.parent.mkdir(parents=True, exist_ok=True)
                sidecar.write_text('[remap]\nimporter="texture"\n')
            icon = build / 'res/mipmap/icon.webp'
            icon.write_bytes(b'original icon')
            exported_remap = build / 'src/main/assets/icon.webp.import'
            exported_remap.parent.mkdir(parents=True)
            exported_remap.write_text('[remap]\npath="res://.godot/imported/icon.ctex"\n')

            self.assertEqual(prepare_android_resources(build), 2)
            self.assertTrue((build / '.gdignore').exists())
            self.assertTrue(all(not sidecar.exists() for sidecar in sidecars))
            self.assertEqual(icon.read_bytes(), b'original icon')
            self.assertTrue(exported_remap.exists())
            self.assertEqual(prepare_android_resources(build), 0)


if __name__ == '__main__':
    unittest.main()
