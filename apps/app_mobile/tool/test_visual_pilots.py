"""Geometric regression and asset budgets, NOT biomechanical approval."""
import json
import math
import tempfile
import unittest
from pathlib import Path
import build_visual_pilots as b

class VisualPilotsTest(unittest.TestCase):
    def test_ids_and_approval_gates(self):
        manifest=json.loads((b.ROOT/'tool/exercise_lottie_batches.json').read_text())
        source={i['id']:i for batch in manifest['batches'] for i in batch['items']}
        candidate=json.loads((b.OUT/'manifest.json').read_text())
        self.assertEqual([i['id'] for i in candidate['items']],list(b.IDS))
        self.assertFalse(candidate['approved']);self.assertFalse(candidate['enabled'])
        self.assertFalse(any(candidate['review'].values()))
        for id in b.IDS:
            self.assertIn(id,source);self.assertFalse(source[id]['approved'])
        self.assertNotIn('visual_pilots/',(b.ROOT/'pubspec.yaml').read_text())

    def test_generated_files_are_reproducible(self):
        with tempfile.TemporaryDirectory() as tmp:
            b.build(Path(tmp))
            for file in b.OUT.iterdir():
                if file.name == 'manifest.json' or (file.stem in b.IDS and file.suffix in ('.json', '.svg')):
                    self.assertEqual(file.read_bytes(),(Path(tmp)/file.name).read_bytes(),file.name)

    def test_asset_budget_and_supported_shapes(self):
        for id in b.IDS:
            raw=(b.OUT/(id+'.json')).read_bytes();doc=json.loads(raw)
            self.assertLess(len(raw),230000)
            self.assertLess(len(doc['layers']),55)
            self.assertEqual(doc['assets'],[])
            self.assertEqual((doc['fr'],doc['op'],doc['w'],doc['h']),(30,120,512,512))
            for layer in doc['layers']:
                self.assertEqual(layer['ty'],4)
                self.assertNotIn('ef',layer);self.assertNotIn('masksProperties',layer)
                for part in layer['shapes'][0]['it']:
                    self.assertIn(part['ty'],('sh','fl','st','tr'))
                    if part['ty']=='sh' and part['ks']['a']==1:
                        keys=part['ks']['k']
                        self.assertEqual(keys[0]['s'],keys[-1]['s'])

    def test_fixed_contacts_and_rigid_segment_lengths(self):
        for id in b.IDS:
            initial=b.pose(id,0)
            for frame in range(121):
                p=b.pose(id,frame)
                self.assertEqual(p['ankle'],initial['ankle'])
                if id == b.IDS[1]:
                    self.assertLess(math.dist(p['neck'],p['head']),20)
                if id != b.IDS[2]:
                    self.assertEqual(p['hip'],initial['hip'])
                    self.assertEqual(p['shoulder'],initial['shoulder'])
                    self.assertEqual(p['bar'],p['wrist'])
                    lengths=(60,59) if id==b.IDS[0] else (61,59)
                    self.assertAlmostEqual(math.dist(p['shoulder'],p['elbow']),lengths[0])
                    self.assertAlmostEqual(math.dist(p['elbow'],p['wrist']),lengths[1])
                else:
                    self.assertAlmostEqual(math.dist(p['hip'],p['knee']),90)
                    self.assertAlmostEqual(math.dist(p['knee'],p['ankle']),90)
                    self.assertAlmostEqual(math.dist(p['hip'],p['shoulder']),102)
                    self.assertEqual(p['bar'][0],268)

    def test_curve_control_points_inside_canvas_and_topology(self):
        for id in b.IDS:
            reference=b.artwork(id,0)
            for frame in b.FRAMES:
                for before,after in zip(reference,b.artwork(id,frame)):
                    p=after['path']
                    self.assertEqual(len(before['path']['v']),len(p['v']))
                    for v,i,o in zip(p['v'],p['i'],p['o']):
                        for point in (v,b.add(v,i),b.add(v,o)):
                            self.assertTrue(all(math.isfinite(x) and 15<x<497 for x in point))

    def test_sampled_motion_has_bounded_interpolation_error(self):
        # Interpolated vectors do not exactly preserve IK between keys. Bound
        # the discrepancy explicitly; this is not a human technique verdict.
        for id in b.IDS:
            for f in range(120):
                lo=(f//10)*10;t=(f-lo)/10
                left,right,actual=b.pose(id,lo),b.pose(id,lo+10),b.pose(id,f)
                for joint in ('knee','elbow','wrist','shoulder'):
                    self.assertLess(math.dist(b.lerp(left[joint],right[joint],t),actual[joint]),5,id)


    def test_approved_anatomical_direction_is_not_approved_media(self):
        """A style decision must never implicitly publish Lottie drafts."""
        spec=json.loads((b.OUT/'anatomical_style_v2.json').read_text())
        old=json.loads((b.OUT/'manifest.json').read_text())
        self.assertEqual(spec['version'],2)
        self.assertTrue(spec['approved_reference'])
        self.assertFalse(spec['approved_assets'])
        self.assertFalse(spec['enabled_assets'])
        self.assertEqual(spec['character']['basePalette'],'neutral_grayscale')
        self.assertEqual(spec['character']['targetHighlight'],'theme_primary')
        self.assertEqual(set(spec['appearance']['modes']),{'light','dark'})
        self.assertEqual(len(spec['appearance']['accents']),8)
        self.assertTrue(spec['appearance']['highlightOnlyAnatomicalMuscles'])
        self.assertEqual([p['id'] for p in spec['pilots']],list(b.IDS))
        for pilot in spec['pilots']:
            self.assertTrue(pilot['primaryMuscles'])
            self.assertTrue(pilot['secondaryMuscles'])
            self.assertTrue(pilot['motionRequirements'])
        self.assertTrue(spec['rules']['noGifs'])
        self.assertTrue(spec['rules']['noAppWeb'])
        self.assertTrue(spec['rules']['preserveExerciseIds'])
        self.assertFalse(old['approved'])
        self.assertFalse(old['enabled'])
        self.assertFalse(any(spec['review'].values()))

if __name__=='__main__': unittest.main()
