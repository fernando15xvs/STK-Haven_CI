#!/usr/bin/env python3
"""Validate QA-only camera-focus evidence without signing off artwork."""
import argparse
import json
import math
from pathlib import Path

_IDS={'ex_bench_press','ex_barbell_row','ex_squat'}
_EXPECTED={(id,mode,view) for id in _IDS for mode in ('dark','light')
           for view in ('left','right')}


def verify(doc):
    if (doc.get('schema')!='stk_v945_anatomy_focus_flutter_raster_qa'
        or doc.get('sourceVersion')!=942
        or doc.get('comparisonCount')!=12
        or doc.get('catalogCount')!=229
        or doc.get('pilotCount')!=3
        or doc.get('approved') is not False
        or doc.get('enabled') is not False
        or doc.get('productionReady') is not False
        or doc.get('technicalArtistReviewComplete') is not False
        or doc.get('physicalDeviceTested') is not False):
        raise ValueError('Invalid artist-review-only v9.45 QA provenance')
    rows=doc.get('samples')
    if not isinstance(rows,list) or len(rows)!=12:
        raise ValueError('Missing 12 Flutter camera comparison samples')
    seen=set()
    for row in rows:
        key=(row['exerciseId'],row['theme'],row['view'])
        if key not in _EXPECTED or key in seen:
            raise ValueError('Invalid or duplicated exercise camera evidence')
        seen.add(key)
        before=row['wideForegroundPixels']
        after=row['focusForegroundPixels']
        ratio=row['focusToOverviewForegroundRatio']
        if (not isinstance(before,int) or not isinstance(after,int)
            or not 600<before<=360*360 or not 600<after<=360*360
            or not all(math.isfinite(x) for x in
                       (ratio,row['cameraWideZoom'],row['cameraFocusZoom']))
            or abs(ratio-after/before)>.00001
            or ratio<doc['minimumFocusMagnificationRatio']
            or not .65<=row['cameraFocusZoom']<row['cameraWideZoom']<=1.6
            or any(not 0<=row[key]<=360*360 for key in
                   ('wideEdgePixels','focusEdgePixels'))):
            raise ValueError('Incorrect close camera image measurements')
    if seen!=_EXPECTED:
        raise ValueError('Not all pilot, mode and camera views are audited')
    return {
        'schema':'stk_v945_focus_review_summary',
        'reviewPairs':len(seen),
        'smallestActualMagnificationRatio':min(
            x['focusToOverviewForegroundRatio'] for x in rows),
        'possibleCroppedFocusViews':sum(
            bool(x['detailMayCropRigidEquipment']) for x in rows),
        'artistAnatomicalSignoffRequired':True,
        'physicalDeviceApprovalRequired':True,
        'approved':False,'enabled':False,
    }


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--input',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    report=verify(json.loads(args.input.read_text(encoding='utf8')))
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(report,indent=2)+'\n',encoding='utf8')
    print(json.dumps(report))


if __name__=='__main__':
    main()
