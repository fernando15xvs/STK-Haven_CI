/// Offline animated glTF 2.0 skinning experiment; internal Flutter QA ONLY.
/// CPU joint skinning + perspective; Flutter's drawVertices handles rasterization.
/// NOT a native GPU skinner / final anatomical sculpt / production asset.
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'anatomical_glb_staging.dart';
import 'rigged_anatomy_engine.dart' show V3;

class _Matrix {
  _Matrix(this.data);
  final Float64List data;

  _Matrix times(_Matrix b) {
    final r=Float64List(16);
    for (var c=0;c<4;c++) for(var row=0;row<4;row++) {
      var sum=0.0;
      for(var k=0;k<4;k++) sum+=data[k*4+row]*b.data[c*4+k];
      r[c*4+row]=sum;
    }
    return _Matrix(r);
  }
  V3 point(V3 v) => V3(
    data[0]*v.x+data[4]*v.y+data[8]*v.z+data[12],
    data[1]*v.x+data[5]*v.y+data[9]*v.z+data[13],
    data[2]*v.x+data[6]*v.y+data[10]*v.z+data[14],
  );
  V3 direction(V3 v) => V3(
    data[0]*v.x+data[4]*v.y+data[8]*v.z,
    data[1]*v.x+data[5]*v.y+data[9]*v.z,
    data[2]*v.x+data[6]*v.y+data[10]*v.z,
  );
  static _Matrix trs(V3 p,List<double> q) {
    final x=q[0],y=q[1],z=q[2],w=q[3];
    final xx=x*x,yy=y*y,zz=z*z,xy=x*y,xz=x*z,yz=y*z;
    final wx=w*x,wy=w*y,wz=w*z;
    return _Matrix(Float64List.fromList([
      1-2*(yy+zz),2*(xy+wz),2*(xz-wy),0,
      2*(xy-wz),1-2*(xx+zz),2*(yz+wx),0,
      2*(xz+wy),2*(yz-wx),1-2*(xx+yy),0,
      p.x,p.y,p.z,1,
    ]));
  }
}

List<double> _mixQuat(List<double> a,List<double> b,double t) {
  var dot=0.0;
  for(var i=0;i<4;i++)dot+=a[i]*b[i];
  if(dot<0){b=b.map((v)=>-v).toList();dot=-dot;}
  final output=List<double>.filled(4,0);
  if(dot>.9995) {
    for(var i=0;i<4;i++)output[i]=a[i]*(1-t)+b[i]*t;
  } else {
    final theta=math.acos(dot.clamp(-1.0,1.0));
    final scale1=math.sin((1-t)*theta)/math.sin(theta);
    final scale2=math.sin(t*theta)/math.sin(theta);
    for(var i=0;i<4;i++)output[i]=a[i]*scale1+b[i]*scale2;
  }
  final norm=math.sqrt(output.fold<double>(0,(s,v)=>s+v*v));
  return output.map((v)=>v/norm).toList(growable:false);
}

class _Node {
  _Node(this.translation,this.rotation,this.children,this.mesh,this.skin);
  final V3 translation;
  final List<double> rotation;
  final List<int> children;
  final int? mesh,skin;
}

class _Sampler {
  _Sampler(this.times,this.frames,this.rotation);
  final List<double> times;
  final List<List<double>> frames;
  final bool rotation;
  List<double> at(double seconds) {
    if(seconds<=times.first)return frames.first;
    if(seconds>=times.last)return frames.last;
    var index=0;
    while(index+1<times.length-1 && seconds>times[index+1])index++;
    final t=(seconds-times[index])/(times[index+1]-times[index]);
    if(rotation)return _mixQuat(frames[index],frames[index+1],t);
    return List.generate(frames[index].length,
      (j)=>frames[index][j]*(1-t)+frames[index+1][j]*t);
  }
}
class _Channel {
  _Channel(this.node,this.path,this.sampler);
  final int node;
  final String path;
  final _Sampler sampler;
}
class _Primitive {
  _Primitive(this.positions,this.normals,this.joints,this.weights,
     this.indices,this.material,this.skinned);
  final List<V3> positions,normals;
  final List<List<int>> joints;
  final List<List<double>> weights;
  final List<int> indices;
  final String material;
  final bool skinned;
}
class _Instance {
  _Instance(this.node,this.primitives,this.skin);
  final int node;
  final List<_Primitive> primitives;
  final bool skin;
}

/// Predecoded immutable GLB. Load once; never parse binary per animation frame.
class GlbSkinnedScene {
  GlbSkinnedScene._(this.id,this.bytes,this._nodes,this._parents,
    this._inverseBind,this._jointNodes,this._channels,this._instances,
    this.vertexCount,this.triangleCount,this.durationSeconds);
  final String id;
  final int bytes,vertexCount,triangleCount;
  final double durationSeconds;
  final List<_Node> _nodes;
  final List<int> _parents,_jointNodes;
  final List<_Matrix> _inverseBind;
  final List<_Channel> _channels;
  final List<_Instance> _instances;

  static GlbSkinnedScene decode(Uint8List raw) {
    final staging=AnatomicalGlbStaging.parse(raw);
    final view=ByteData.sublistView(raw);
    final jsonLength=view.getUint32(12,Endian.little);
    final doc=jsonDecode(utf8.decode(raw.sublist(20,20+jsonLength)))
       as Map<String,dynamic>;
    final blobOffset=20+jsonLength+8;
    final accessors=(doc['accessors'] as List).cast<Map<String,dynamic>>();
    final views=(doc['bufferViews'] as List).cast<Map<String,dynamic>>();
    final nodes=(doc['nodes'] as List).cast<Map<String,dynamic>>();
    final meshDefs=(doc['meshes'] as List).cast<Map<String,dynamic>>();
    final materials=(doc['materials'] as List).cast<Map<String,dynamic>>();
    if(nodes.length>128||views.length>600||accessors.length>600||
       meshDefs.length>8||raw.length>850*1024) {
      throw const FormatException('GLB complexity budget exceeded');
    }
    List<List<num>> access(int i,int dim,{required bool integer}) {
      if(i<0||i>=accessors.length)throw const FormatException('Accessor index');
      final a=accessors[i],count=a['count'] as int;
      final type=a['type'] as String;
      final expected={1:'SCALAR',3:'VEC3',4:'VEC4',16:'MAT4'}[dim];
      if(type!=expected||count<1||
          count>(integer&&dim==1?75000:25000)||a.containsKey('sparse')) {
        throw const FormatException('Unsupported glTF accessor');
      }
      final component=a['componentType'] as int;
      if(component!=(integer?5123:5126)) {
        throw const FormatException('Unsupported component type');
      }
      final bufferView=a['bufferView'] as int;
      if(bufferView<0||bufferView>=views.length)throw const FormatException('View');
      final v=views[bufferView];
      if(v['buffer']!=0 || v.containsKey('byteStride')) {
        throw const FormatException('Unsupported strided or external glTF buffer');
      }
      final elementSize=integer?2:4,span=count*dim*elementSize;
      final viewOffset=(v['byteOffset'] as int?) ?? 0;
      final accessorOffset=(a['byteOffset'] as int?) ?? 0;
      final base=blobOffset+viewOffset+accessorOffset;
      final limit=blobOffset+viewOffset+(v['byteLength'] as int);
      if(base<blobOffset||base+span>limit||base+span>raw.length) {
        throw const FormatException('Accessor out of bounds');
      }
      return List.generate(count,(r)=>List.generate(dim,(c){
        final at=base+(r*dim+c)*elementSize;
        return integer?view.getUint16(at,Endian.little):
            view.getFloat32(at,Endian.little);
      },growable:false),growable:false);
    }
    List<V3> coords(int accessor) => access(accessor,3,integer:false)
      .map((r)=>V3(r[0].toDouble(),r[1].toDouble(),r[2].toDouble()))
      .toList(growable:false);
    final parsedNodes=nodes.map((n) {
      if(n.containsKey('matrix')||n.containsKey('scale')) {
        throw const FormatException('Unsupported animated node matrix/scale');
      }
      final p=(n['translation'] as List?)?.cast<num>() ?? [0,0,0];
      final q=(n['rotation'] as List?)?.cast<num>() ?? [0,0,0,1];
      if(p.length!=3||q.length!=4)throw const FormatException('Node TRS');
      final cs=(n['children'] as List? ?? []).cast<int>();
      return _Node(V3(p[0].toDouble(),p[1].toDouble(),p[2].toDouble()),
        q.map((x)=>x.toDouble()).toList(),cs,
        n['mesh'] as int?,n['skin'] as int?);
    }).toList(growable:false);
    final parents=List<int>.filled(nodes.length,-1);
    for(var i=0;i<parsedNodes.length;i++) {
      for(final c in parsedNodes[i].children) {
        if(c<0||c>=nodes.length||parents[c]!=-1) {
          throw const FormatException('Invalid node hierarchy');
        }
        parents[c]=i;
      }
    }
    final skin=(doc['skins'] as List).single as Map<String,dynamic>;
    final joints=(skin['joints'] as List).cast<int>();
    final ibm=access(skin['inverseBindMatrices'] as int,16,integer:false);
    if(ibm.length!=joints.length)throw const FormatException('Skin matrix count');
    final inverse=ibm.map((m)=>_Matrix(Float64List.fromList(
         m.map((x)=>x.toDouble()).toList()))).toList(growable:false);
    final clips=(doc['animations'] as List).single as Map<String,dynamic>;
    final samplers=(clips['samplers'] as List).cast<Map<String,dynamic>>();
    final channels=< _Channel>[];
    var duration=0.0;
    for(final item in (clips['channels'] as List).cast<Map<String,dynamic>>()) {
      final target=item['target'] as Map<String,dynamic>;
      final node=target['node'] as int,path=target['path'] as String;
      if(node<0||node>=nodes.length||!['rotation','translation'].contains(path)){
        throw const FormatException('Unsupported animation target');
      }
      final sample=samplers[item['sampler'] as int];
      if(sample['interpolation']!='LINEAR')throw const FormatException('Interpolation');
      final ts=access(sample['input'] as int,1,integer:false)
          .map((r)=>r[0].toDouble()).toList();
      final frames=access(sample['output'] as int,
         path=='rotation'?4:3,integer:false)
          .map((row)=>row.map((n)=>n.toDouble()).toList()).toList();
      if(ts.length!=frames.length||ts.length<2||ts.first!=0) {
        throw const FormatException('Invalid keyframes');
      }
      for(var i=1;i<ts.length;i++) {
        if(ts[i]<=ts[i-1])throw const FormatException('Unsorted keyframes');
      }
      duration=math.max(duration,ts.last);
      channels.add(_Channel(node,path,_Sampler(ts,frames,path=='rotation')));
    }
    if(duration<=0||duration>10)throw const FormatException('Animation duration');
    final instances=<_Instance>[];
    var vertices=0,triangles=0;
    for(var ni=0;ni<parsedNodes.length;ni++) {
      final node=parsedNodes[ni];
      if(node.mesh==null)continue;
      if(node.mesh!<0||node.mesh!>=meshDefs.length){
        throw const FormatException('Invalid mesh index');
      }
      final mesh=meshDefs[node.mesh!];
      final primitives=< _Primitive>[];
      for(final p in (mesh['primitives'] as List).cast<Map<String,dynamic>>()) {
        if(p['mode']!=null&&p['mode']!=4)throw const FormatException('Triangles only');
        final attrs=p['attributes'] as Map<String,dynamic>;
        final pos=coords(attrs['POSITION'] as int);
        final normals=coords(attrs['NORMAL'] as int);
        if(pos.length!=normals.length)throw const FormatException('Normals');
        final indices=access(p['indices'] as int,1,integer:true)
             .map((v)=>v[0].toInt()).toList(growable:false);
        if(indices.length%3!=0||indices.any((i)=>i>=pos.length)) {
          throw const FormatException('Invalid face indices');
        }
        final skinned=node.skin!=null;
        final jointRows=skinned?access(attrs['JOINTS_0'] as int,4,integer:true)
            .map((r)=>r.map((n)=>n.toInt()).toList()).toList():
            <List<int>>[];
        final weightRows=skinned?access(attrs['WEIGHTS_0'] as int,4,integer:false)
            .map((r)=>r.map((n)=>n.toDouble()).toList()).toList():
            <List<double>>[];
        if(skinned&&(jointRows.length!=pos.length ||
           weightRows.length!=pos.length))throw const FormatException('Vertex skin count');
        if(skinned)for(var v=0;v<pos.length;v++){
          final js=jointRows[v],ws=weightRows[v];
          if(js.any((i)=>i<0||i>=joints.length)||
             ws.any((w)=>!w.isFinite||w<0)|| 
             (ws.reduce((a,b)=>a+b)-1).abs()>.025){
            throw const FormatException('Invalid vertex weights');
          }
        }
        final mat=p['material'] as int;
        if(mat<0||mat>=materials.length)throw const FormatException('Material');
        final name=materials[mat]['name'] as String;
        if(!name.startsWith('STK_'))throw const FormatException('Material namespace');
        vertices+=pos.length;triangles+=indices.length~/3;
        primitives.add(_Primitive(pos,normals,jointRows,weightRows,indices,name,skinned));
      }
      instances.add(_Instance(ni,primitives,node.skin!=null));
    }
    if(vertices>30000||triangles>25000||instances.isEmpty) {
      throw const FormatException('GLB vertex budget exceeded');
    }
    return GlbSkinnedScene._(staging.id,raw.length,parsedNodes,parents,inverse,
        joints,channels,instances,vertices,triangles,duration);
  }

  List<_Matrix> _world(double elapsed) {
    final duration=durationSeconds;
    final seconds=((elapsed%duration)+duration)%duration;
    final translations=_nodes.map((n)=>n.translation).toList();
    final rotations=_nodes.map((n)=>n.rotation).toList();
    for(final channel in _channels) {
      final v=channel.sampler.at(seconds);
      if(channel.path=='rotation'){
        rotations[channel.node]=v;
      } else {
        translations[channel.node]=V3(v[0],v[1],v[2]);
      }
    }
    final result=List<_Matrix?>.filled(_nodes.length,null);
    final active=<int>{};
    _Matrix traverse(int index) {
      final cached=result[index];
      if(cached!=null)return cached;
      if(!active.add(index))throw const FormatException('Cycle in GLB nodes');
      final local=_Matrix.trs(translations[index],rotations[index]);
      final parent=_parents[index];
      final matrix=parent<0?local:traverse(parent).times(local);
      active.remove(index);
      result[index]=matrix;
      return matrix;
    }
    for(var i=0;i<_nodes.length;i++)traverse(i);
    return result.cast<_Matrix>();
  }

  /// One pose from GLB animation; positions are skinned using WEIGHTS_0/JOINTS_0.
  /// Geometry and skin data are cached, only joints and projections vary.
  GlbDrawFrame frame(double elapsed,Size size,Map<String,Color> theme,
      {bool dark=true,double orbit=0}) {
    final world=_world(elapsed);
    final joints=List<_Matrix>.generate(_jointNodes.length,
       (i)=>world[_jointNodes[i]].times(_inverseBind[i]));
    // Per-exercise camera composition: lower elevation and closer framing.
    // Bench is supine along -Z, row uses a back three-quarter viewpoint.
    final bench=id=='ex_bench_press';
    final row=id=='ex_barbell_row';
    final center=bench ? const V3(0,.80,-.22)
        : row ? const V3(0,.92,.15) : const V3(0,.88,0);
    final yaw=(row ? math.pi+.68 : bench ? .88 : .43)+orbit;
    final distance=bench ? 3.65 : row ? 3.75 : 3.9;
    final height=bench ? 1.50 : row ? 1.55 : 1.72;
    final eye=center+V3(math.sin(yaw)*distance,height,
                        math.cos(yaw)*distance);
    final forward=(center-eye).unit;
    final right=forward.cross(const V3(0,1,0)).unit;
    final up=right.cross(forward).unit;
    final light=const V3(.55,1,.65).unit;
    final drawn=<GlbDrawPart>[];
    for(final instance in _instances) {
      for(final prim in instance.primitives) {
        final points=<Offset>[],colors=<Color>[];
        var meanDepth=0.0;
        final base=theme[prim.material] ??
          _fallback(prim.material, dark);
        for(var index=0;index<prim.positions.length;index++) {
          var position=prim.positions[index];
          var normal=prim.normals[index];
          if(prim.skinned) {
            var p=const V3(0,0,0),n=const V3(0,0,0);
            for(var k=0;k<4;k++) {
              final weight=prim.weights[index][k];
              if(weight<.00001)continue;
              final joint=joints[prim.joints[index][k]];
              p=p+joint.point(position)*weight;
              n=n+joint.direction(normal)*weight;
            }
            position=p;normal=n.unit;
          } else {
            position=world[instance.node].point(position);
            normal=world[instance.node].direction(normal).unit;
          }
          final ray=position-eye;
          final depth=math.max(.6,ray.dot(forward));
          meanDepth+=depth;
          final scale=size.shortestSide*1.58/depth;
          points.add(Offset(size.width*.5+ray.dot(right)*scale,
             size.height*.55-ray.dot(up)*scale));
          final brightness=(.51+.45*math.max(0.0,normal.dot(light)))
              .clamp(.39,1.0);
          colors.add(Color.lerp(Colors.black,base,brightness)!);
        }
        meanDepth/=points.length;
        drawn.add(GlbDrawPart(points,colors,prim.indices,meanDepth,prim.material));
      }
    }
    // Object-depth ordering has no per-pixel Z buffer: occlusion QA required.
    drawn.sort((a,b)=>b.depth.compareTo(a.depth));
    return GlbDrawFrame(drawn,vertexCount,triangleCount);
  }
  static Color _fallback(String name,bool dark) => switch(name) {
    'STK_BODY' => dark?const Color(0xFFC5CBD3):const Color(0xFF9099A4),
    'STK_MUSCLE' => dark?const Color(0xFFE5E9EE):const Color(0xFFBBC3CD),
    'STK_PRIMARY' => const Color(0xFF2962FF),
    'STK_SECONDARY' => const Color(0xFF7DA0FF),
    'STK_HAIR' => const Color(0xFF414954),
    'STK_SHOE' => const Color(0xFF58616C),
    'STK_EQUIPMENT' => const Color(0xFFABB3BF),
    'STK_PLATE' => const Color(0xFF414852),
    'STK_CUSHION' => const Color(0xFF353B46),
    _ => const Color(0xFF9099A4),
  };
}
class GlbDrawPart {
  const GlbDrawPart(this.positions,this.colors,this.indices,this.depth,this.material);
  final List<Offset> positions;
  final List<Color> colors;
  final List<int> indices;
  final double depth;
  final String material;
}
class GlbDrawFrame {
  const GlbDrawFrame(this.parts,this.vertices,this.triangles);
  final List<GlbDrawPart> parts;
  final int vertices,triangles;
  bool get finite => parts.every((p)=>p.depth.isFinite&&p.positions.every(
    (v)=>v.dx.isFinite&&v.dy.isFinite));
}
class GlbSkinnedPainter extends CustomPainter {
  const GlbSkinnedPainter(this.frame,this.background);
  final GlbDrawFrame frame;
  final Color background;
  @override
  void paint(Canvas canvas,Size size) {
    canvas.drawRect(Offset.zero&size,Paint()..color=background);
    for(final part in frame.parts) {
      final mesh=ui.Vertices(ui.VertexMode.triangles,part.positions,
          colors:part.colors,indices:part.indices);
      canvas.drawVertices(mesh,BlendMode.modulate,Paint()..color=Colors.white);
      mesh.dispose();
    }
  }
  @override
  bool shouldRepaint(covariant GlbSkinnedPainter old) =>
      old.frame!=frame||old.background!=background;
}
