"""Validate false QA approvals, missing frames, and camera coverage."""
import copy
import unittest
from check_focus_v945 import verify,_EXPECTED


def baseline():
    rows=[{'exerciseId':id,'theme':mode,'view':view,
           'wideForegroundPixels':10000,'focusForegroundPixels':17000,
           'focusToOverviewForegroundRatio':1.7,
           'wideEdgePixels':0,'focusEdgePixels':1,
           'cameraWideZoom':1.2,'cameraFocusZoom':.72,
           'detailMayCropRigidEquipment':True}
          for id,mode,view in sorted(_EXPECTED)]
    return {'schema':'stk_v945_anatomy_focus_flutter_raster_qa',
        'sourceVersion':942,'comparisonCount':12,'catalogCount':229,
        'pilotCount':3,'approved':False,'enabled':False,
        'productionReady':False,'technicalArtistReviewComplete':False,
        'physicalDeviceTested':False,'minimumFocusMagnificationRatio':1.1,
        'samples':rows}


class FocusEvidenceV945Tests(unittest.TestCase):
    def test_valid_data_still_requires_artist_review(self):
        r=verify(baseline())
        self.assertEqual(r['reviewPairs'],12)
        self.assertFalse(r['approved'])
        self.assertTrue(r['artistAnatomicalSignoffRequired'])

    def test_unsafe_or_missing_evidence_rejected(self):
        for edit in ('approve','remove','duplicate','tiny','ratio'):
            doc=copy.deepcopy(baseline())
            if edit=='approve':doc['approved']=True
            if edit=='remove':doc['samples'].pop()
            if edit=='duplicate':doc['samples'][1]=doc['samples'][0]
            if edit=='tiny':doc['samples'][0]['focusForegroundPixels']=10001
            if edit=='ratio':doc['samples'][0]['focusToOverviewForegroundRatio']=12.
            with self.assertRaises(ValueError):
                verify(doc)


if __name__=='__main__':
    unittest.main()
