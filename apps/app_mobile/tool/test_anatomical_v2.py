"""Candidate anatomy rendering checks; NOT visual or biomechanical approval."""
import json
import tempfile
import unittest
from pathlib import Path
import build_anatomical_v2 as v2

class CandidateTest(unittest.TestCase):
    def test_three_generated_assets_keep_approval_gates_closed(self):
        with tempfile.TemporaryDirectory() as tmp:
            generated=v2.build(Path(tmp))
            self.assertEqual([x['id'] for x in generated['items']],list(v2.IDS))
            self.assertFalse(generated['approved'])
            self.assertFalse(generated['enabled'])
            original=json.loads((v2.HERE/'tool/visual_pilots/manifest.json').read_text())
            self.assertFalse(original['approved'])
            self.assertFalse(original['enabled'])
            self.assertNotIn('build/anatomical_v2',
                             (v2.HERE/'pubspec.yaml').read_text())
            for item in generated['items']:
                self.assertLess(item['bytes'],260000)
                self.assertLess(item['layers'],75)
                doc=json.loads((Path(tmp)/(item['id']+'.json')).read_text())
                self.assertEqual((doc['fr'],doc['op'],doc['w'],doc['h']),
                                 (30,120,512,512))
                self.assertEqual(doc['assets'],[])
                fills=[s['nm'] for layer in doc['layers']
                       for s in layer['shapes'][0]['it'] if s['ty']=='fl']
                self.assertIn('color_targetPrimary',fills)
                self.assertIn('color_targetSecondary',fills)
                self.assertNotIn('color_kit',fills)
                self.assertTrue((Path(tmp)/(item['id']+'.svg')).exists())
                for layer in doc['layers']:
                    self.assertEqual(layer['ty'],4)
                    self.assertNotIn('masksProperties',layer)
                    self.assertNotIn('ef',layer)
                    ks=layer['shapes'][0]['it'][0]['ks']
                    if ks['a']==1:
                        self.assertEqual(ks['k'][0]['s'],ks['k'][-1]['s'])

    def test_reproducible(self):
        with tempfile.TemporaryDirectory() as a, tempfile.TemporaryDirectory() as b:
            v2.build(Path(a))
            v2.build(Path(b))
            for p in Path(a).iterdir():
                self.assertEqual(p.read_bytes(),(Path(b)/p.name).read_bytes())

if __name__=='__main__':
    unittest.main()
