"""Review the CC0 bind-pose muscle regions and bilateral symmetry.

These numerical masks are NOT an anatomist-approved segmentation.
"""
import json,os,unittest
from pathlib import Path
import muscle_region_atlas as atlas
import retarget_cc0_glb as rig

SOURCE=Path(os.environ.get("STK_CC0_MODEL",
    "build/cc0_model_stage/human-base-rigged-cc0.glb"))
OUT=Path(os.environ.get("STK_CC0_RETARGET","build/cc0_53bone_retarget"))

class AtlasRegionTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.glb=rig.GLB(SOURCE.read_bytes())

    def test_11_bilateral_regions_remain_separate_and_reviewable(self):
        report={}
        source=self.glb.doc['meshes'][0]['primitives'][0]
        vertices=self.glb.accessor(source['attributes']['POSITION'])
        original_faces=len(self.glb.accessor(source['indices']))//3
        for exercise,roles in atlas.EXERCISE_ROLES.items():
            groups=atlas.classify_mesh(self.glb,exercise)
            self.assertEqual(sum(len(v)//3 for v in groups.values()),
                             original_faces)
            audit={}
            for region,role in roles.items():
                face_ids=groups[(region,role)]
                sides=[0,0]
                for index in range(0,len(face_ids),3):
                    mean=sum(vertices[k][0] for k in face_ids[index:index+3])/3
                    sides[0 if mean<0 else 1]+=1
                self.assertGreater(min(sides),20,region)
                self.assertLess(abs(sides[0]-sides[1])/sum(sides),.10,region)
                audit[region]={'role':role,'triangles':len(face_ids)//3,
                    'left':sides[0],'right':sides[1],
                    'accurateAnatomicalSculpt':False}
            report[exercise]=audit
        OUT.mkdir(parents=True,exist_ok=True)
        (OUT/'muscle_region_audit.json').write_text(json.dumps({
            'status':'unapproved_skin_weight_normal_regions',
            'approved':False,'enabled':False,'exercises':report
        },indent=2)+'\n',encoding='utf8')

    def test_source_53_joint_mesh_is_not_modified_by_atlas(self):
        src=self.glb.doc['meshes'][0]['primitives'][0]
        attrs=dict(src['attributes'])
        before=len(self.glb.accessor(src['indices']))
        atlas.classify_mesh(self.glb,'ex_squat')
        self.assertEqual(src['attributes'],attrs)
        self.assertEqual(len(self.glb.accessor(src['indices'])),before)

if __name__=='__main__':unittest.main()
