#!/usr/bin/env python3
"""Validate Flutter-produced v9.44 raster measurements without claiming signoff.

Reporting no visible difference is a *finding*, not a reason to claim green
equals final anatomy. Preserve an explicit block for professional review.
"""
from __future__ import annotations
import argparse
import json
import math
from pathlib import Path

EXERCISES={'ex_bench_press','ex_barbell_row','ex_squat'}
MODES={'dark','light'}
SECONDS={0,2,4}
SCALES={1,2}
EXPECTED={(exercise,theme,second,scale) for exercise in EXERCISES
          for theme in MODES for second in SECONDS for scale in SCALES}


def verify(report):
    if (report.get('schema')!='stk_v944_real_flutter_pixel_visibility_qa'
        or report.get('frameCount')!=18
        or report.get('rasterComparisons')!=36
        or report.get('pilotCount')!=3
        or report.get('catalogCount')!=229
        or report.get('approved') is not False
        or report.get('enabled') is not False
        or report.get('productionReady') is not False
        or report.get('perceptualQualityCertified') is not False
        or report.get('visualAppearanceProfessionallyApproved') is not False):
        raise ValueError('Missing explicit v9.44 visual safety restrictions')
    rows=report.get('results')
    if not isinstance(rows,list) or len(rows)!=len(EXPECTED):
        raise ValueError('Expected 36 full-scale Flutter raster comparisons')
    visited=set()
    flagged=0
    for row in rows:
        key=(row['exerciseId'],row['theme'],row['second'],
             row['devicePixelRatio'])
        if key not in EXPECTED or key in visited:
            raise ValueError('Duplicate/unknown visual pilot sample')
        visited.add(key)
        scale=row['devicePixelRatio']
        if row['widthPx']!=360*scale or row['heightPx']!=360*scale:
            raise ValueError('Unexpected raster size')
        n=row['foregroundPixels']
        changed=row['changedForegroundPixels']
        background=row['changedOnFlatBackgroundPixels']
        peak=row['peakChannelDelta']
        pct=row['changedForegroundPercent']
        mean=row['meanMaxChannelDeltaInForeground']
        if (not 500<n<=360*360*scale*scale
            or not 0<=changed<=n or not 0<=background
            or not 0<=peak<=255
            or not all(math.isfinite(x) for x in (pct,mean))
            or abs(pct-(100*changed/n))>0.0001
            or not 0<=mean<=255):
            raise ValueError('Invalid or non-finite raster evidence')
        heuristic=pct>=report['visibleDifferenceHeuristicPercent']
        if row['heuristicVisibleDifference'] is not heuristic:
            raise ValueError('Heuristic flag is inconsistent with pixels')
        flagged+=int(heuristic)
    if visited!=EXPECTED or flagged!=report['heuristicFlaggedComparisons']:
        raise ValueError('Raster evidence incomplete')
    return {
        'schema':'stk_v944_raster_visibility_summary',
        'comparisons':len(rows),
        'heuristicFlaggedComparisons':flagged,
        'notFlagged':len(rows)-flagged,
        'interpretation':(
          'Measured changes do not demonstrate artistic improvement. '
          'All pilots remain blocked pending independent visual review.'),
        'requiresHumanAnatomicalReview':True,
        'approved':False,'enabled':False,
    }


def main():
    cli=argparse.ArgumentParser()
    cli.add_argument('--input',type=Path,required=True)
    cli.add_argument('--output',type=Path,required=True)
    options=cli.parse_args()
    report=json.loads(options.input.read_text(encoding='utf8'))
    summary=verify(report)
    options.output.parent.mkdir(parents=True,exist_ok=True)
    options.output.write_text(
        json.dumps(summary,indent=2)+'\n',encoding='utf8')
    print(json.dumps(summary))


if __name__=='__main__':
    main()
