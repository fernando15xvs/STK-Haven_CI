/// STK Haven experimental procedural 3D mesh + joint rig for iOS/Android.
/// Real 3D geometry, native Canvas projection. NOT final sculpted anatomy.
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

@immutable
class V3 {
  const V3(this.x,this.y,this.z);
  final double x,y,z;
  V3 operator +(V3 b)=>V3(x+b.x,y+b.y,z+b.z);
  V3 operator -(V3 b)=>V3(x-b.x,y-b.y,z-b.z);
  V3 operator *(double k)=>V3(x*k,y*k,z*k);
  double dot(V3 b)=>x*b.x+y*b.y+z*b.z;
  V3 cross(V3 b)=>V3(y*b.z-z*b.y,z*b.x-x*b.z,x*b.y-y*b.x);
  double get length=>math.sqrt(dot(this));
  V3 get unit=>length<1e-9?const V3(0,1,0):this*(1/length);
  V3 mix(V3 b,double t)=>this*(1-t)+b*t;
  bool get finite=>x.isFinite&&y.isFinite&&z.isFinite;
}
enum Exercise3d {
  bench('ex_bench_press','Press de banca'),
  row('ex_barbell_row','Remo con barra'),
  squat('ex_squat','Sentadilla');
  const Exercise3d(this.id,this.title);
  final String id,title;
}
enum Material3d {body,muscle,shade,primary,secondary,shorts,hair,metal,plate,shoe}
class Pose3d {
  const Pose3d(this.joints,this.bar,this.flexion);
  final Map<String,V3> joints;
  final V3 bar;
  final double flexion;
  V3 at(String name)=>joints[name]!;
}
class Rig3d {
  static double phase(double progress) {
    final t=progress.clamp(0.0,1.0);
    double ease(double x)=>x*x*(3-2*x);
    if(t<=.10||t>=.96)return 0;
    if(t<.48)return ease((t-.10)/.38);
    if(t<.58)return 1;
    return 1-ease((t-.58)/.38);
  }
  /// Analytic two-bone inverse kinematics: immutable lengths throughout a rep.
  static V3 ik(V3 a,V3 b,double first,double second,V3 bend) {
    final d=(b-a).length;
    if(d<1e-5||d>first+second+1e-5||
       d<(first-second).abs()-1e-5) {
      throw StateError('Unreachable skeletal joint');
    }
    final dir=(b-a).unit;
    final lateral=(bend-dir*bend.dot(dir)).unit;
    final x=(first*first-second*second+d*d)/(2*d);
    final h=math.sqrt(math.max(0,first*first-x*x));
    return a+dir*x+lateral*h;
  }
  static Pose3d sample(Exercise3d exercise,double progress) {
    final q=phase(progress);
    final j=<String,V3>{};
    V3 bar;
    if(exercise==Exercise3d.bench) {
      j['hip']=const V3(0,.97,.20);
      j['chest']=const V3(0,1.00,-.40);
      j['head']=const V3(0,1.02,-.73);
      bar=V3(0,1.52-.36*q,-.38+.06*q);
      for(final side in [-1.0,1.0]) {
        final s=side<0?'l':'r';
        final shoulder=V3(side*.26,1.00,-.43);
        final hand=V3(side*.57,bar.y,bar.z);
        j['s'+s]=shoulder;j['h'+s]=hand;
        j['e'+s]=ik(shoulder,hand,.38,.35,V3(side*.08,-.22,.4));
        j['u'+s]=V3(side*.18,.96,.21);
        j['k'+s]=V3(side*.24,.56,.59);
        j['a'+s]=V3(side*.28,.14,.70);
        j['t'+s]=V3(side*.28,.11,.91);
      }
    } else if(exercise==Exercise3d.row) {
      j['hip']=const V3(0,1.00,-.10);
      j['chest']=const V3(0,1.18,.51);
      j['head']=const V3(0,1.39,.69);
      bar=V3(0,.59+.43*q,.68-.13*q);
      for(final side in [-1.0,1.0]) {
        final s=side<0?'l':'r';
        final shoulder=V3(side*.27,1.19,.50);
        final hand=V3(side*.55,bar.y,bar.z);
        j['s'+s]=shoulder;j['h'+s]=hand;
        j['e'+s]=ik(shoulder,hand,.40,.34,V3(side*.04,-.04,-.6));
        j['u'+s]=V3(side*.18,1.00,-.10);
        j['k'+s]=V3(side*.24,.61,.10);
        j['a'+s]=V3(side*.25,.15,.28);
        j['t'+s]=V3(side*.25,.11,.48);
      }
    } else {
      final hip=V3(0,1.08-.44*q,-.14-.20*q);
      final chest=hip+V3(0,.52,.05+.12*q);
      j['hip']=hip;j['chest']=chest;
      j['head']=chest+const V3(0,.30,.035);
      bar=V3(0,chest.y+.04,chest.z-.16);
      for(final side in [-1.0,1.0]) {
        final s=side<0?'l':'r';
        final root=hip+V3(side*.17,0,0);
        final ankle=V3(side*.25,.13,.21);
        final shoulder=chest+V3(side*.26,0,0);
        j['u'+s]=root;j['a'+s]=ankle;
        j['t'+s]=ankle+const V3(0,-.025,.22);
        j['k'+s]=ik(root,ankle,.54,.50,const V3(0,0,.9));
        j['s'+s]=shoulder;
        j['e'+s]=shoulder+V3(side*.23,-.15,-.08);
        j['h'+s]=V3(side*.66,bar.y,bar.z);
      }
    }
    return Pose3d(j,bar,q);
  }
}
class Part3d {
  const Part3d(this.name,this.center,this.radii,this.axis,this.material);
  final String name;
  final V3 center,radii,axis;
  final Material3d material;
}
class Body3d {
  static List<Part3d> build(Exercise3d ex,Pose3d pose) {
    final j=pose.at;
    final out=<Part3d>[];
    void orb(String name,V3 center,V3 radii,Material3d m,
        [V3 axis=const V3(0,1,0)]) =>
      out.add(Part3d(name,center,radii,axis,m));
    void bone(String name,V3 a,V3 b,double radius,Material3d m,
        [double widen=1]) {
      final v=b-a;
      orb(name,a.mix(b,.5),V3(radius*widen,v.length*.59,radius),m,v.unit);
    }
    final hip=j('hip'),chest=j('chest'),head=j('head');
    bone('abdomen',hip,chest,.16,Material3d.body,1.34);
    bone('thorax',hip.mix(chest,.38),chest,.21,Material3d.body,1.38);
    bone('neck',chest,head,.079,Material3d.body);
    orb('head',head,const V3(.135,.163,.115),Material3d.body);
    orb('hair',head+const V3(0,.11,-.017),
        const V3(.139,.058,.119),Material3d.hair);
    final rear=ex==Exercise3d.row;
    for(final side in [-1.0,1.0]) {
      final suffix=side<0?'l':'r';
      final shoulder=j('s'+suffix),elbow=j('e'+suffix);
      final hand=j('h'+suffix),root=j('u'+suffix);
      final knee=j('k'+suffix),ankle=j('a'+suffix),toe=j('t'+suffix);
      orb('deltoid_'+suffix,shoulder,const V3(.106,.109,.11),
          ex==Exercise3d.squat?Material3d.muscle:Material3d.secondary);
      bone('upper_arm_'+suffix,shoulder,elbow,.091,Material3d.body);
      bone('forearm_'+suffix,elbow,hand,.072,Material3d.body);
      orb('hand_'+suffix,hand,const V3(.057,.059,.065),Material3d.body);
      bone('triceps_'+suffix,shoulder.mix(elbow,.21),
        shoulder.mix(elbow,.74),.052,
        ex==Exercise3d.bench?Material3d.secondary:Material3d.muscle);
      orb('glute_'+suffix,root+V3(side*.04,-.076,-.077),
        const V3(.148,.162,.122),
        ex==Exercise3d.squat?Material3d.primary:Material3d.body);
      bone('thigh_'+suffix,root,knee,.144,Material3d.body);
      bone('calf_'+suffix,knee,ankle,.094,Material3d.body);
      bone('quadriceps_'+suffix,root.mix(knee,.16)+const V3(0,0,.08),
        root.mix(knee,.78)+const V3(0,0,.075),.081,
        ex==Exercise3d.squat?Material3d.primary:Material3d.muscle);
      bone('adductor_'+suffix,root.mix(knee,.24)+V3(-side*.067,0,.04),
        root.mix(knee,.71)+V3(-side*.045,0,.028),.043,
        ex==Exercise3d.squat?Material3d.secondary:Material3d.shade);
      bone('foot_'+suffix,ankle,toe,.096,Material3d.shoe,1.08);
      final central=hip.mix(chest,.77);
      if(ex==Exercise3d.bench) {
        orb('pectoralis_'+suffix,central+V3(side*.123,.17,0),
          const V3(.143,.068,.12),Material3d.primary,(chest-hip).unit);
      } else if(rear) {
        bone('latissimus_'+suffix,hip.mix(chest,.28)+
            V3(side*.12,0,-.15),hip.mix(chest,.84)+
            V3(side*.15,0,-.15),.077,Material3d.primary);
        orb('rhomboid_'+suffix,central+V3(side*.065,.04,-.19),
           const V3(.076,.114,.049),Material3d.secondary,(chest-hip).unit);
      } else {
        for(var index=0;index<3;index++) {
          orb('abdominal_'+suffix+'_'+index.toString(),
            hip.mix(chest,.25+index*.17)+V3(side*.069,0,.172),
            const V3(.062,.061,.037),Material3d.muscle,(chest-hip).unit);
        }
      }
    }
    if(rear) bone('trapezius',hip.mix(chest,.72)+const V3(0,0,-.166),
      chest+const V3(0,0,-.166),.085,Material3d.primary,1.5);
    bone('barbell',pose.bar+const V3(-1.13,0,0),
      pose.bar+const V3(1.13,0,0),.021,Material3d.metal);
    for(final side in [-1.0,1.0]) {
      final suffix=side<0?'l':'r';
      orb('plate_'+suffix,pose.bar+V3(side*.94,0,0),
        const V3(.054,.174,.174),Material3d.plate,const V3(1,0,0));
      orb('hub_'+suffix,pose.bar+V3(side*1.01,0,0),
        const V3(.015,.041,.041),Material3d.metal,const V3(1,0,0));
    }
    if(ex==Exercise3d.bench) {
      bone('bench_cushion',const V3(0,.88,-.73),
        const V3(0,.88,.43),.135,Material3d.shorts,1.5);
      for(final z in [-.56,.29]) {
        bone('bench_leg',V3(0,.86,z),V3(0,.13,z),.04,Material3d.metal);
        bone('bench_foot',V3(-.24,.12,z),V3(.24,.12,z),.037,
          Material3d.metal);
      }
    }
    return out;
  }
}
class MeshFrame3d {
  const MeshFrame3d(this.positions,this.colors,this.triangles,this.depthSpread);
  final List<Offset> positions;
  final List<Color> colors;
  final int triangles;
  final double depthSpread;
}
class _Face {
  const _Face(this.depth,this.points,this.color);
  final double depth;
  final List<Offset> points;
  final Color color;
}
class Mesh3d {
  static const int slices=10,rings=7;
  static final List<V3> sphere=_sphere();
  static final List<List<int>> faces=_faces();
  static List<V3> _sphere() {
    final data=<V3>[];
    for(var a=0;a<=rings;a++) {
      final polar=math.pi*a/rings;
      for(var b=0;b<=slices;b++) {
        final azimuth=2*math.pi*b/slices;
        data.add(V3(math.sin(polar)*math.cos(azimuth),math.cos(polar),
           math.sin(polar)*math.sin(azimuth)));
      }
    }
    return data;
  }
  static List<List<int>> _faces() {
    final list=<List<int>>[];
    for(var row=0;row<rings;row++)for(var col=0;col<slices;col++) {
      final a=row*(slices+1)+col,b=a+slices+1;
      list.add([a,b,a+1]);list.add([b,b+1,a+1]);
    }
    return list;
  }
  static Color materialColor(Material3d material,Color accent,bool dark) {
    switch(material) {
      case Material3d.primary:return accent;
      case Material3d.secondary:
        return Color.lerp(accent,Colors.white,dark ? .25 : .13)!;
      case Material3d.body:
        return dark?const Color(0xFFC4CBD3):const Color(0xFF919BA5);
      case Material3d.muscle:
        return dark?const Color(0xFFE5E9EE):const Color(0xFFBFC6CE);
      case Material3d.shade:return const Color(0xFF79838E);
      case Material3d.shorts:return const Color(0xFF454D58);
      case Material3d.hair:return const Color(0xFF3A424D);
      case Material3d.metal:return const Color(0xFFB5BDC6);
      case Material3d.plate:return const Color(0xFF3F4853);
      case Material3d.shoe:return const Color(0xFF596472);
    }
  }
  /// Per-triangle perspective projection + depth sort. No plugin/webview/GIF.
  static MeshFrame3d render(Exercise3d exercise,Pose3d pose,
      Size size,Color accent,bool dark,{double orbit=0}) {
    final pivot=exercise==Exercise3d.bench
       ?const V3(0,.91,-.04):const V3(0,1.02,.10);
    final yaw=(exercise==Exercise3d.row?math.pi:0)+.58+orbit;
    final eye=pivot+V3(math.sin(yaw)*4.7,2.4,math.cos(yaw)*4.7);
    final forward=(pivot-eye).unit;
    final right=forward.cross(const V3(0,1,0)).unit;
    final up=right.cross(forward).unit;
    final light=const V3(.5,1,.7).unit;
    final triangles=<_Face>[];
    for(final part in Body3d.build(exercise,pose)) {
      final axis=part.axis.unit;
      final ref=axis.y.abs()>.91?const V3(0,0,1):const V3(0,1,0);
      final side=ref.cross(axis).unit;
      final depthAxis=axis.cross(side).unit;
      final verts=sphere.map((v)=>part.center+
        side*(v.x*part.radii.x)+axis*(v.y*part.radii.y)+
        depthAxis*(v.z*part.radii.z)).toList(growable:false);
      for(final indices in faces) {
        final a=verts[indices[0]],b=verts[indices[1]],c=verts[indices[2]];
        final middle=(a+b+c)*(1/3);
        var normal=(b-a).cross(c-a).unit;
        if(normal.dot(middle-part.center)<0)normal=normal*-1;
        if(normal.dot(eye-middle)<=.003)continue;
        final points=<Offset>[];
        var average=0.0;
        for(final v in [a,b,c]) {
          final ray=v-eye,z=ray.dot(forward);
          average+=z/3;
          final scale=size.shortestSide*1.36/math.max(.5,z);
          points.add(Offset(size.width*.5+ray.dot(right)*scale,
             size.height*.5-ray.dot(up)*scale));
        }
        final color=materialColor(part.material,accent,dark);
        final brightness=(.53+.43*math.max(0.0,normal.dot(light)))
          .clamp(.42,1.0);
        triangles.add(_Face(average,points,
           Color.lerp(Colors.black,color,brightness)!));
      }
    }
    triangles.sort((a,b)=>b.depth.compareTo(a.depth));
    final vertices=<Offset>[], colors=<Color>[];
    for(final face in triangles) {
      vertices.addAll(face.points);
      colors.addAll([face.color,face.color,face.color]);
    }
    final spread=triangles.isEmpty?0.0:
      triangles.first.depth-triangles.last.depth;
    return MeshFrame3d(vertices,colors,triangles.length,spread);
  }
}
class MeshPainter3d extends CustomPainter {
  const MeshPainter3d({required this.exercise,required this.progress,
      required this.accent,required this.dark,required this.background,
      this.orbit=0});
  final Exercise3d exercise;
  final double progress,orbit;
  final Color accent,background;
  final bool dark;
  @override
  void paint(Canvas canvas,Size size) {
    canvas.drawRect(Offset.zero&size,Paint()..color=background);
    final frame=Mesh3d.render(exercise,Rig3d.sample(exercise,progress),
       size,accent,dark,orbit:orbit);
    if(frame.positions.isEmpty)return;
    final verts=ui.Vertices(ui.VertexMode.triangles,frame.positions,
       colors:frame.colors);
    canvas.drawVertices(verts,BlendMode.modulate,Paint()..color=Colors.white);
    verts.dispose();
  }
  @override
  bool shouldRepaint(covariant MeshPainter3d old)=>
    exercise!=old.exercise||progress!=old.progress||accent!=old.accent||
    background!=old.background||dark!=old.dark||orbit!=old.orbit;
}
