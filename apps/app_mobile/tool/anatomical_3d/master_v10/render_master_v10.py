#!/usr/bin/env python3
"""Render the actual STK master V10 GLB via VTK, not concept artwork."""
import argparse
import json
from pathlib import Path
import vtk
from vtk.util import numpy_support
import trimesh
import numpy as np
from PIL import Image,ImageDraw,ImageFont


def render_view(mesh, view, out_path, dark=False, size=(700,850)):
    points=vtk.vtkPoints()
    points.SetData(numpy_support.numpy_to_vtk(mesh.vertices.astype(np.float32),deep=True))
    triangles=vtk.vtkCellArray()
    for face in mesh.faces:
        tri=vtk.vtkTriangle()
        for i,vi in enumerate(face):
            tri.GetPointIds().SetId(i,int(vi))
        triangles.InsertNextCell(tri)
    poly=vtk.vtkPolyData();poly.SetPoints(points);poly.SetPolys(triangles)
    norms=vtk.vtkPolyDataNormals()
    norms.SetInputData(poly)
    norms.SetFeatureAngle(52)
    norms.SplittingOff()
    norms.ConsistencyOn()
    norms.AutoOrientNormalsOn()
    norms.Update()
    mapper=vtk.vtkPolyDataMapper();mapper.SetInputConnection(norms.GetOutputPort())
    actor=vtk.vtkActor();actor.SetMapper(mapper)
    actor.GetProperty().SetColor(.74,.76,.80)
    actor.GetProperty().SetInterpolationToPhong()
    actor.GetProperty().SetAmbient(.22)
    actor.GetProperty().SetDiffuse(.78)
    actor.GetProperty().SetSpecular(.16)
    actor.GetProperty().SetSpecularPower(34)
    ren=vtk.vtkRenderer();ren.AddActor(actor)
    if dark:ren.SetBackground(.075,.095,.13)
    else: ren.SetBackground(.93,.945,.96)
    ren.AutomaticLightCreationOff()
    for pos,intensity in [((2.8,4.2,3.1),1.00),((-3.7,3.0,-.9),.64),((.6,2.,-3.4),.64)]:
        light=vtk.vtkLight();light.SetLightTypeToSceneLight()
        light.SetPosition(*pos);light.SetFocalPoint(0,1,0)
        light.SetIntensity(intensity)
        ren.AddLight(light)
    cam=ren.GetActiveCamera()
    distance=3.5
    positions={
        'front': (0,1.03,distance),
        'back': (0,1.03,-distance),
        'profile': (distance,1.03,0),
        'three_quarter': (distance*.68,1.08,distance*.75),
    }
    cam.SetPosition(*positions[view]);cam.SetFocalPoint(0,.98,0)
    cam.SetViewUp(0,1,0);cam.ParallelProjectionOn();cam.SetParallelScale(1.055)
    win=vtk.vtkRenderWindow();win.SetOffScreenRendering(1)
    win.AddRenderer(ren);win.SetSize(*size);win.SetMultiSamples(4)
    win.Render()
    filt=vtk.vtkWindowToImageFilter();filt.SetInput(win)
    filt.SetInputBufferTypeToRGB();filt.ReadFrontBufferOff();filt.Update()
    writer=vtk.vtkPNGWriter();writer.SetFileName(str(out_path));writer.SetInputConnection(filt.GetOutputPort());writer.Write()
    win.Finalize()


def render(output,source,dark=False):
    src=trimesh.load(source,force='mesh')
    output=Path(output);output.mkdir(parents=True,exist_ok=True)
    for view in ('front','back','profile','three_quarter'):
        render_view(src,view,output/(view+('_dark' if dark else '')+'.png'),dark)


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--glb',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True);args=p.parse_args()
    render(args.output,args.glb)