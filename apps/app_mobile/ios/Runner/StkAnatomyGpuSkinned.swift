import Flutter
import Metal
import MetalKit
import UIKit

// Separate opt-in Metal vertex skinning QA. CPU still samples eight morph
// curves; GPU transforms positions/normals with 55 bone matrices. Disabled
// in 229-exercise production library and not used for animated playback.
final class StkAnatomyGpuSkinnedFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    StkAnatomyGpuSkinnedView(
      frame: frame, identifier: viewId, messenger: messenger
    )
  }
}

private final class StkAnatomyGpuSkinnedView: NSObject, FlutterPlatformView {
  private let metalView: MTKView
  private let renderer: StkGpuSkinnedMetalRenderer?
  private let channel: FlutterMethodChannel

  init(frame: CGRect, identifier: Int64, messenger: FlutterBinaryMessenger) {
    metalView = MTKView(frame: frame, device: MTLCreateSystemDefaultDevice())
    metalView.colorPixelFormat = .bgra8Unorm
    metalView.depthStencilPixelFormat = .depth32Float
    metalView.isPaused = true
    metalView.enableSetNeedsDisplay = false
    metalView.framebufferOnly = true
    renderer = StkGpuSkinnedMetalRenderer(view: metalView)
    channel = FlutterMethodChannel(
      name: "stk_haven/anatomy_gpu_skinning/\(identifier)",
      binaryMessenger: messenger
    )
    super.init()
    metalView.delegate = renderer
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "disposed", message: nil, details: nil))
        return
      }
      guard call.method == "drawSkinned" ||
            call.method == "drawMorphed" ||
            call.method == "drawIndexedMorph" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let renderer = self.renderer,
            let args = call.arguments as? [String: Any],
            let rawBones = args["bones"] as? FlutterStandardTypedData,
            let rawCamera = args["camera"] as? FlutterStandardTypedData,
            let rawBackground = args["background"] as? FlutterStandardTypedData,
            rawBones.data.count == 55 * 16 * 4,
            rawCamera.data.count == 20 * 4,
            rawBackground.data.count == 4 * 4,
            Self.valid(rawBones.data),
            Self.valid(rawCamera.data),
            Self.valid(rawBackground.data) else {
        result(FlutterError(
          code: "invalid_gpu_skinning",
          message: "Invalid or unsupported Metal 55-joint mesh packet",
          details: nil
        ))
        return
      }
      let indexedMode = call.method == "drawIndexedMorph"
      let isMorph = call.method == "drawMorphed" || indexedMode
      let reuseMesh = args["reuseMesh"] as? Bool == true
      let reuseMorphMesh = args["reuseMorphMesh"] as? Bool == true
      let reuseIndexedMesh = args["reuseIndexedMesh"] as? Bool == true
      let indexedVertices = (args["indexedVertices"] as? FlutterStandardTypedData)?.data
      let indexedIndices = (args["indices"] as? FlutterStandardTypedData)?.data
      let meshBytes = (args["vertices"] as? FlutterStandardTypedData)?.data
      let deltas = (args["morphDeltas"] as? FlutterStandardTypedData)?.data
      let morphWeights = (args["morphWeights"] as? FlutterStandardTypedData)?.data
      let meshShapeValid: Bool
      if indexedMode {
        if reuseIndexedMesh {
          meshShapeValid = indexedVertices == nil && indexedIndices == nil &&
            meshBytes == nil && deltas == nil && renderer.hasIndexedMorphMesh
        } else if let indexedVertices, let indexedIndices {
          let vertexCount = indexedVertices.count / (42 * 4)
          let payloadBytes = indexedVertices.count + indexedIndices.count
          let validIndices = indexedIndices.withUnsafeBytes { raw -> Bool in
            (0..<(indexedIndices.count / 4)).allSatisfy { i in
              let index = raw.loadUnaligned(
                fromByteOffset: i * 4, as: UInt32.self)
              return index < UInt32(vertexCount)
            }
          }
          meshShapeValid = meshBytes == nil && deltas == nil &&
            indexedVertices.count > 0 &&
            indexedVertices.count % (42 * 4) == 0 &&
            vertexCount <= 25000 * 3 &&
            indexedIndices.count >= 3 * 4 &&
            indexedIndices.count % (3 * 4) == 0 &&
            indexedIndices.count <= 25000 * 3 * 4 &&
            payloadBytes <= 12 * 1024 * 1024 &&
            Self.valid(indexedVertices) && validIndices
        } else {
          meshShapeValid = false
        }
      } else if isMorph {
        if reuseMorphMesh {
          meshShapeValid = meshBytes == nil && deltas == nil &&
            renderer.hasMorphMesh
        } else if let meshBytes, let deltas {
          meshShapeValid = meshBytes.count > 0 &&
            meshBytes.count <= 25000 * 3 * 18 * 4 &&
            meshBytes.count % (18 * 3 * 4) == 0 &&
            deltas.count == (meshBytes.count / (18 * 4)) * 24 * 4 &&
            Self.valid(meshBytes) && Self.valid(deltas)
        } else {
          meshShapeValid = false
        }
      } else if reuseMesh {
        meshShapeValid = meshBytes == nil && deltas == nil &&
          morphWeights == nil && renderer.hasMesh
      } else if let meshBytes {
        meshShapeValid = meshBytes.count > 0 &&
          meshBytes.count <= 25000 * 3 * 18 * 4 &&
          meshBytes.count % (18 * 3 * 4) == 0 &&
          deltas == nil && morphWeights == nil &&
          Self.valid(meshBytes)
      } else {
        meshShapeValid = false
      }
      let weightsValid = !isMorph || (
        morphWeights?.count == 8 * 4 &&
        morphWeights.map { Self.valid($0) } == true &&
        morphWeights.map { raw in
          raw.withUnsafeBytes { bytes in
            (0..<8).allSatisfy {
              let weight = bytes.loadUnaligned(
                fromByteOffset: $0 * 4, as: Float.self)
              return weight >= 0 && weight <= 1.025
            }
          }
        } == true
      )
      guard meshShapeValid && weightsValid else {
        result(FlutterError(
          code: "missing_or_invalid_gpu_mesh",
          message: "Morph frame requires valid reusable geometry and weights",
          details: nil
        ))
        return
      }
      let background = rawBackground.data.withUnsafeBytes { bytes -> [Float] in
        (0..<4).map { bytes.loadUnaligned(fromByteOffset: $0 * 4, as: Float.self) }
      }
      let uploaded: Bool
      if indexedMode {
        uploaded = renderer.loadIndexedMorph(vertices: indexedVertices,
          indices: indexedIndices, weights: morphWeights!,
          bones: rawBones.data, camera: rawCamera.data, color: background)
      } else if isMorph {
        uploaded = renderer.loadMorph(vertices: meshBytes,
          deltas: deltas, weights: morphWeights!,
          bones: rawBones.data, camera: rawCamera.data, color: background)
      } else {
        uploaded = renderer.load(vertices: meshBytes,
          bones: rawBones.data, camera: rawCamera.data, color: background)
      }
      guard background.allSatisfy({ $0 >= 0 && $0 <= 1 }),
            uploaded else {
        result(FlutterError(
          code: "gpu_skin_upload_failed",
          message: "Unable to allocate a bounded Metal palette/mesh",
          details: nil
        ))
        return
      }
      self.metalView.draw()
      result(true)
    }
  }

  static func valid(_ bytes: Data) -> Bool {
    if bytes.count % 4 != 0 { return false }
    return bytes.withUnsafeBytes { data in
      for offset in stride(from: 0, to: bytes.count, by: 4) {
        if !data.loadUnaligned(fromByteOffset: offset, as: Float.self).isFinite {
          return false
        }
      }
      return true
    }
  }

  func view() -> UIView { metalView }

  deinit {
    channel.setMethodCallHandler(nil)
    metalView.delegate = nil
  }
}

private final class StkGpuSkinnedMetalRenderer: NSObject, MTKViewDelegate {
  private let device: MTLDevice
  private let queue: MTLCommandQueue
  private let pipeline: MTLRenderPipelineState
  private let morphPipeline: MTLRenderPipelineState?
  private let depth: MTLDepthStencilState
  private var vertexBuffer: MTLBuffer?
  private var indexBuffer: MTLBuffer?
  private var indexCount = 0
  private var indexedActive = false
  private var boneBuffer: MTLBuffer?
  private var cameraBuffer: MTLBuffer?
  private var morphWeightsBuffer: MTLBuffer?
  private var morphActive = false
  private var vertexCount = 0
  private var background: [Float] = [0.07, 0.09, 0.12, 1.0]

  var hasMesh: Bool {
    vertexBuffer != nil && vertexCount > 0 && !morphActive && !indexedActive
  }
  var hasMorphMesh: Bool {
    vertexBuffer != nil && vertexCount > 0 &&
      morphActive && !indexedActive && morphPipeline != nil
  }
  var hasIndexedMorphMesh: Bool {
    vertexBuffer != nil && indexBuffer != nil && indexCount > 0 &&
      indexedActive && morphActive && morphPipeline != nil
  }

  private static let shaderSource = """
    #include <metal_stdlib>
    using namespace metal;

    struct Input {
      float3 position [[attribute(0)]];
      float3 normal [[attribute(1)]];
      float4 joint [[attribute(2)]];
      float4 weight [[attribute(3)]];
      float4 color [[attribute(4)]];
    };
    struct Output {
      float4 position [[position]];
      float4 color;
    };

    struct MorphInput {
      float3 position [[attribute(0)]];
      float3 normal [[attribute(1)]];
      float4 joint [[attribute(2)]];
      float4 weight [[attribute(3)]];
      float4 color [[attribute(4)]];
      float3 morph0 [[attribute(5)]];
      float3 morph1 [[attribute(6)]];
      float3 morph2 [[attribute(7)]];
      float3 morph3 [[attribute(8)]];
      float3 morph4 [[attribute(9)]];
      float3 morph5 [[attribute(10)]];
      float3 morph6 [[attribute(11)]];
      float3 morph7 [[attribute(12)]];
    };

    Output shadeSkinned(float3 bindPosition, float3 originalNormal,
        float4 joints, float4 weights, float4 baseColor,
        constant float4x4* bones, constant float4* camera) {
      uint4 joint = uint4(joints + 0.5);
      float4x4 skin =
          bones[joint.x] * weights.x +
          bones[joint.y] * weights.y +
          bones[joint.z] * weights.z +
          bones[joint.w] * weights.w;
      float3 world = (skin * float4(bindPosition, 1.0)).xyz;
      float3 normal = normalize((skin * float4(originalNormal, 0.0)).xyz);
      float3 ray = world - camera[0].xyz;
      float distance = max(0.6, dot(ray, camera[3].xyz));
      float px = dot(ray, camera[1].xyz) * camera[1].w;
      float py = dot(ray, camera[2].xyz) * camera[2].w +
          camera[3].w * distance;
      float pz = distance * clamp((distance - 0.5) / 30.0, 0.0, 1.0);
      Output o;
      o.position = float4(px, py, pz, distance);
      float shade = clamp(0.51 + 0.45 *
          max(0.0, dot(normal, camera[4].xyz)), 0.39, 1.0);
      o.color = float4(baseColor.rgb * shade, baseColor.a);
      return o;
    }

    vertex Output skinnedVertex(
        Input v [[stage_in]],
        constant float4x4* bones [[buffer(1)]],
        constant float4* camera [[buffer(2)]]) {
      return shadeSkinned(v.position, v.normal, v.joint, v.weight,
        v.color, bones, camera);
    }

    vertex Output morphedVertex(
        MorphInput v [[stage_in]],
        constant float4x4* bones [[buffer(1)]],
        constant float4* camera [[buffer(2)]],
        constant float4* morphWeights [[buffer(3)]]) {
      float3 position = v.position +
        v.morph0 * morphWeights[0].x +
        v.morph1 * morphWeights[0].y +
        v.morph2 * morphWeights[0].z +
        v.morph3 * morphWeights[0].w +
        v.morph4 * morphWeights[1].x +
        v.morph5 * morphWeights[1].y +
        v.morph6 * morphWeights[1].z +
        v.morph7 * morphWeights[1].w;
      return shadeSkinned(position, v.normal, v.joint, v.weight,
        v.color, bones, camera);
    }

    fragment float4 skinnedFragment(Output v [[stage_in]]) {
      return v.color;
    }
    """

  init?(view: MTKView) {
    guard let device = view.device,
          let queue = device.makeCommandQueue(),
          let lib = try? device.makeLibrary(source: Self.shaderSource, options: nil),
          let vertex = lib.makeFunction(name: "skinnedVertex"),
          let fragment = lib.makeFunction(name: "skinnedFragment") else {
      return nil
    }
    let desc = MTLRenderPipelineDescriptor()
    desc.vertexFunction = vertex
    desc.fragmentFunction = fragment
    desc.colorAttachments[0].pixelFormat = view.colorPixelFormat
    desc.depthAttachmentPixelFormat = view.depthStencilPixelFormat
    let vertexDesc = MTLVertexDescriptor()
    let formats: [MTLVertexFormat] = [.float3, .float3, .float4, .float4, .float4]
    let offsets = [0, 12, 24, 40, 56]
    for index in 0..<5 {
      vertexDesc.attributes[index].format = formats[index]
      vertexDesc.attributes[index].offset = offsets[index]
      vertexDesc.attributes[index].bufferIndex = 0
    }
    vertexDesc.layouts[0].stride = 18 * 4
    vertexDesc.layouts[0].stepFunction = .perVertex
    desc.vertexDescriptor = vertexDesc
    let depthInfo = MTLDepthStencilDescriptor()
    depthInfo.isDepthWriteEnabled = true
    depthInfo.depthCompareFunction = .less
    guard let pipeline = try? device.makeRenderPipelineState(descriptor: desc),
          let depth = device.makeDepthStencilState(descriptor: depthInfo) else {
      return nil
    }
    self.device = device
    self.queue = queue
    self.pipeline = pipeline
    let morphDesc = MTLRenderPipelineDescriptor()
    morphDesc.vertexFunction = lib.makeFunction(name: "morphedVertex")
    morphDesc.fragmentFunction = fragment
    morphDesc.colorAttachments[0].pixelFormat = view.colorPixelFormat
    morphDesc.depthAttachmentPixelFormat = view.depthStencilPixelFormat
    let morphVertexDesc = MTLVertexDescriptor()
    for index in 0..<5 {
      morphVertexDesc.attributes[index].format = formats[index]
      morphVertexDesc.attributes[index].offset = offsets[index]
      morphVertexDesc.attributes[index].bufferIndex = 0
    }
    for index in 0..<8 {
      morphVertexDesc.attributes[index + 5].format = .float3
      morphVertexDesc.attributes[index + 5].offset = (18 + index * 3) * 4
      morphVertexDesc.attributes[index + 5].bufferIndex = 0
    }
    morphVertexDesc.layouts[0].stride = 42 * 4
    morphVertexDesc.layouts[0].stepFunction = .perVertex
    morphDesc.vertexDescriptor = morphVertexDesc
    self.morphPipeline = try? device.makeRenderPipelineState(descriptor: morphDesc)
    self.depth = depth
    super.init()
  }

  private func upload(_ bytes: Data) -> MTLBuffer? {
    bytes.withUnsafeBytes { raw -> MTLBuffer? in
      guard let pointer = raw.baseAddress else { return nil }
      return device.makeBuffer(bytes: pointer, length: bytes.count,
                               options: .storageModeShared)
    }
  }

  func load(
    vertices: Data?, bones: Data, camera: Data, color: [Float]
  ) -> Bool {
    let vertex = vertices.flatMap { upload($0) } ??
      (morphActive ? nil : vertexBuffer)
    guard let vertex,
          let bone = upload(bones),
          let cam = upload(camera) else { return false }
    vertexBuffer = vertex
    boneBuffer = bone
    cameraBuffer = cam
    morphActive = false
    indexedActive = false
    indexBuffer = nil
    indexCount = 0
    morphWeightsBuffer = nil
    if let vertices { vertexCount = vertices.count / (18 * 4) }
    background = color
    return true
  }

  func loadMorph(
    vertices: Data?, deltas: Data?, weights: Data,
    bones: Data, camera: Data, color: [Float]
  ) -> Bool {
    guard morphPipeline != nil else { return false }
    var candidate = hasMorphMesh ? vertexBuffer : nil
    var newCount = vertexCount
    if let vertices, let deltas {
      let count = vertices.count / (18 * 4)
      // Compose once into a GPU buffer. Later poses reuse the exact buffer.
      // Neither static stream nor its 8 delta targets are resent.
      var combined = Data(count: count * 42 * 4)
      combined.withUnsafeMutableBytes { destination in
        vertices.withUnsafeBytes { positions in
          deltas.withUnsafeBytes { targets in
            guard let out = destination.baseAddress,
                  let base = positions.baseAddress,
                  let morph = targets.baseAddress else { return }
            for i in 0..<count {
              out.advanced(by: i * 42 * 4).copyMemory(
                from: base.advanced(by: i * 18 * 4),
                byteCount: 18 * 4)
              out.advanced(by: (i * 42 + 18) * 4).copyMemory(
                from: morph.advanced(by: i * 24 * 4),
                byteCount: 24 * 4)
            }
          }
        }
      }
      candidate = upload(combined)
      newCount = count
    }
    guard let vertex = candidate,
          let bone = upload(bones),
          let cam = upload(camera),
          let morph = upload(weights) else { return false }
    vertexBuffer = vertex
    boneBuffer = bone
    cameraBuffer = cam
    morphWeightsBuffer = morph
    vertexCount = newCount
    morphActive = true
    indexedActive = false
    indexBuffer = nil
    indexCount = 0
    background = color
    return true
  }

  func loadIndexedMorph(
    vertices: Data?, indices: Data?, weights: Data,
    bones: Data, camera: Data, color: [Float]
  ) -> Bool {
    guard morphPipeline != nil else { return false }
    let newVertex = vertices.flatMap { upload($0) } ??
      (indexedActive ? vertexBuffer : nil)
    let newIndices = indices.flatMap { upload($0) } ??
      (indexedActive ? indexBuffer : nil)
    guard let vertex = newVertex, let index = newIndices,
          let bone = upload(bones), let cam = upload(camera),
          let morph = upload(weights) else { return false }
    vertexBuffer = vertex
    indexBuffer = index
    if let vertices { vertexCount = vertices.count / (42 * 4) }
    if let indices { indexCount = indices.count / 4 }
    boneBuffer = bone
    cameraBuffer = cam
    morphWeightsBuffer = morph
    morphActive = true
    indexedActive = true
    background = color
    return true
  }

  func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

  func draw(in view: MTKView) {
    guard let pass = view.currentRenderPassDescriptor,
          let drawable = view.currentDrawable,
          let command = queue.makeCommandBuffer(),
          let vertices = vertexBuffer,
          let bones = boneBuffer,
          let camera = cameraBuffer else { return }
    pass.colorAttachments[0].loadAction = .clear
    pass.colorAttachments[0].clearColor = MTLClearColor(
      red: Double(background[0]), green: Double(background[1]),
      blue: Double(background[2]), alpha: Double(background[3])
    )
    pass.depthAttachment.loadAction = .clear
    pass.depthAttachment.clearDepth = 1.0
    guard let encoder = command.makeRenderCommandEncoder(
      descriptor: pass
    ) else { return }
    guard let activePipeline = morphActive ? morphPipeline : pipeline else {
      encoder.endEncoding()
      return
    }
    encoder.setRenderPipelineState(activePipeline)
    encoder.setDepthStencilState(depth)
    encoder.setCullMode(.none)
    encoder.setVertexBuffer(vertices, offset: 0, index: 0)
    encoder.setVertexBuffer(bones, offset: 0, index: 1)
    encoder.setVertexBuffer(camera, offset: 0, index: 2)
    if morphActive {
      guard let morph = morphWeightsBuffer else {
        encoder.endEncoding()
        return
      }
      encoder.setVertexBuffer(morph, offset: 0, index: 3)
    }
    if indexedActive {
      guard let indices = indexBuffer else {
        encoder.endEncoding()
        return
      }
      encoder.drawIndexedPrimitives(type: .triangle,
        indexCount: indexCount, indexType: .uint32,
        indexBuffer: indices, indexBufferOffset: 0)
    } else {
      encoder.drawPrimitives(type: .triangle,
        vertexStart: 0, vertexCount: vertexCount)
    }
    encoder.endEncoding()
    command.present(drawable)
    command.commit()
  }
}
