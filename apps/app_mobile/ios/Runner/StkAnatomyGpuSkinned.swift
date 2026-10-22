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
      guard call.method == "drawSkinned" else {
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
      let reuseMesh = args["reuseMesh"] as? Bool == true
      let meshBytes = (args["vertices"] as? FlutterStandardTypedData)?.data
      let meshValid: Bool
      if reuseMesh {
        meshValid = meshBytes == nil && renderer.hasMesh
      } else if let meshBytes {
        meshValid = meshBytes.count > 0 &&
          meshBytes.count <= 25000 * 3 * 18 * 4 &&
          meshBytes.count % (18 * 3 * 4) == 0 &&
          Self.valid(meshBytes)
      } else {
        meshValid = false
      }
      guard meshValid else {
        result(FlutterError(
          code: "missing_or_invalid_gpu_mesh",
          message: "Compact frame requires a retained mesh in this view",
          details: nil
        ))
        return
      }
      let background = rawBackground.data.withUnsafeBytes { bytes -> [Float] in
        (0..<4).map { bytes.loadUnaligned(fromByteOffset: $0 * 4, as: Float.self) }
      }
      guard background.allSatisfy({ $0 >= 0 && $0 <= 1 }),
            renderer.load(vertices: meshBytes,
                          bones: rawBones.data,
                          camera: rawCamera.data,
                          color: background) else {
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
  private let depth: MTLDepthStencilState
  private var vertexBuffer: MTLBuffer?
  private var boneBuffer: MTLBuffer?
  private var cameraBuffer: MTLBuffer?
  private var vertexCount = 0
  private var background: [Float] = [0.07, 0.09, 0.12, 1.0]

  var hasMesh: Bool { vertexBuffer != nil && vertexCount > 0 }

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

    vertex Output skinnedVertex(
        Input v [[stage_in]],
        constant float4x4* bones [[buffer(1)]],
        constant float4* camera [[buffer(2)]]) {
      uint4 joint = uint4(v.joint + 0.5);
      float4x4 skin =
          bones[joint.x] * v.weight.x +
          bones[joint.y] * v.weight.y +
          bones[joint.z] * v.weight.z +
          bones[joint.w] * v.weight.w;
      float3 world = (skin * float4(v.position, 1.0)).xyz;
      float3 normal = normalize((skin * float4(v.normal, 0.0)).xyz);
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
      o.color = float4(v.color.rgb * shade, v.color.a);
      return o;
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
    self.depth = depth
    super.init()
  }

  func load(
    vertices: Data?, bones: Data, camera: Data, color: [Float]
  ) -> Bool {
    func upload(_ bytes: Data) -> MTLBuffer? {
      bytes.withUnsafeBytes { raw -> MTLBuffer? in
        guard let pointer = raw.baseAddress else { return nil }
        return device.makeBuffer(bytes: pointer,
                                 length: bytes.count,
                                 options: .storageModeShared)
      }
    }
    // Reuse the retained Metal vertex buffer for an unchanged morph mesh.
    // Changed morph poses allocate a fresh buffer so in-flight GPU reads
    // cannot race with CPU writes to the previous vertex allocation.
    let vertex = vertices.flatMap { upload($0) } ?? vertexBuffer
    guard let vertex,
          let bone = upload(bones),
          let cam = upload(camera) else { return false }
    vertexBuffer = vertex
    boneBuffer = bone
    cameraBuffer = cam
    if let vertices { vertexCount = vertices.count / (18 * 4) }
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
    encoder.setRenderPipelineState(pipeline)
    encoder.setDepthStencilState(depth)
    encoder.setCullMode(.none)
    encoder.setVertexBuffer(vertices, offset: 0, index: 0)
    encoder.setVertexBuffer(bones, offset: 0, index: 1)
    encoder.setVertexBuffer(camera, offset: 0, index: 2)
    encoder.drawPrimitives(type: .triangle,
                           vertexStart: 0,
                           vertexCount: vertexCount)
    encoder.endEncoding()
    command.present(drawable)
    command.commit()
  }
}
