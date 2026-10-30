"""Fast deterministic unit checks for raster evidence review."""
import copy
import unittest
from check_pixel_visibility_v944 import verify,EXPECTED


def sample_report():
    rows=[]
    for ex,mode,second,scale in sorted(EXPECTED):
        rows.append({
            'exerciseId':ex,'theme':mode,'second':second,
            'devicePixelRatio':scale,
            'widthPx':360*scale,'heightPx':360*scale,
            'foregroundPixels':30000*scale*scale,
            'changedForegroundPixels':0,
            'changedOnFlatBackgroundPixels':0,
            'changedForegroundPercent':0.0,
            'meanMaxChannelDeltaInForeground':0.0,
            'peakChannelDelta':0,
            'heuristicVisibleDifference':False,
        })
    return {'schema':'stk_v944_real_flutter_pixel_visibility_qa',
        'frameCount':18,'rasterComparisons':36,'pilotCount':3,
        'catalogCount':229,'approved':False,'enabled':False,
        'productionReady':False,'perceptualQualityCertified':False,
        'visualAppearanceProfessionallyApproved':False,
        'visibleDifferenceHeuristicPercent':0.5,
        'heuristicFlaggedComparisons':0,'results':rows}


class RasterReviewTest(unittest.TestCase):
    def test_invisible_art_is_reported_not_approved(self):
        summary=verify(sample_report())
        self.assertEqual(summary['comparisons'],36)
        self.assertEqual(summary['notFlagged'],36)
        self.assertFalse(summary['approved'])
        self.assertTrue(summary['requiresHumanAnatomicalReview'])

    def test_detects_broken_raster_and_unsafe_approval(self):
        data=sample_report()
        for mutation in ('missing','duplicate','approved','delta','nan'):
            broken=copy.deepcopy(data)
            if mutation=='missing':broken['results'].pop()
            if mutation=='duplicate':broken['results'][1]=broken['results'][0]
            if mutation=='approved':broken['approved']=True
            if mutation=='delta':
                broken['results'][0]['changedForegroundPercent']=10.
            if mutation=='nan':
                broken['results'][0]['meanMaxChannelDeltaInForeground']=float('nan')
            with self.assertRaises(ValueError):
                verify(broken)


if __name__=='__main__':
    unittest.main()
