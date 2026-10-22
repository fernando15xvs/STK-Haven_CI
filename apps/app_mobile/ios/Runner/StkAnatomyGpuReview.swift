import Flutter
import Metal
import MetalKit
import UIKit

// Experimental anatomical STATIC GLB pose rasterizer for internal review.
// The Flutter CPU renderer still handles 55 joint skinning + 8 morphs.
// Metal provides interpolated vertex color and real per-pixel depth testing.
// No animation/catalog routing, textures, network or additional packages.
final class StkAnatomyGpuReviewFactory: NSObject, FlutterPlatformViewFactory {
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
    return StkAnatomyGpuReviewView(
      frame: frame, identifier: viewId, messenger: messenger
    )
  }
}

private final class StkAnatomyGpuReviewView: NSObject, FlutterPlatformView {
  private let metalView: MTKView
  private let renderer: StkGpuMetalRenderer?
  private let channel: FlutterMethodChannel

  init(frame: CGRect, identifier: Int64, messenger: FlutterBinaryMessenger) {
    metalView = MTKView(frame: frame, device: MTLCreateSystemDefaultDevice())
    metalView.colorPixelFormat = .bgra8Unorm
    metalView.depthStencilPixelFormat = .depth32Float
    metalView.isPaused = true
    metalView.enableSetNeedsDisplay = false
    metalView.framebufferOnly = true
    renderer = StkGpuMetalRenderer(view: metalView)
    channel = FlutterMethodChannel(
      name: "stk_haven/anatomy_gpu_static/\(identifier)",
      binaryMessenger: messenger
    )
    super.init()
    metalView.delegate = renderer
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "disposed", message: nil, details: nil))
        return
      }
      guard call.method == "draw" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let renderer = self.renderer,
            let args = call.arguments as? [String: Any],
            let data = args["vertices"] as? FlutterStandardTypedData,
            let colors = args["background"] as? FlutterStandardTypedData,
            data.data.count > 0,
            data.data.count <= 25000 * 3 * 7 * 4,
            data.data.count % (7 * 3 * 4) == 0,
            colors.data.count == 16,
            Self.isValidFloats(data.data),
            Self.isValidFloats(colors.data) else {
        result(FlutterError(
          code: "invalid_gpu_packet",
          message: "Metal unavailable or invalid static mesh payload",
          details: nil
        ))
        return
      }
      let background = colors.data.withUnsafeBytes { bytes -> [Float] in
        (0..<4).map {
          bytes.loadUnaligned(fromByteOffset: $0 * 4, as: Float.self)
        }
      }
      guard background.allSatisfy({ $0 >= 0 && $0 <= 1 }),
            renderer.load(data: data.data, color: background) else {
        result(FlutterError(
          code: "gpu_upload_failed", message: "Metal buffer unavailable",
          details: nil
        ))
        return
      }
      self.metalView.draw()
      result(true)
    }
  }

  static func isValidFloats(_ data: Data) -> Bool {
    guard data.count % 4 == 0 else { return false }
    return data.withUnsafeBytes { raw in
      for offset in stride(from: 0, to: data.count, by: 4) {
        if !raw.loadUnaligned(fromByteOffset: offset, as: Float.self).isFinite {
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

private final class StkGpuMetalRenderer: NSObject, MTKViewDelegate {
  private let device: MTLDevice
  private let queue: MTLCommandQueue
  private let pipeline: MTLRenderPipelineState
  private let depthState: MTLDepthStencilState
  private var vertexBuffer: MTLBuffer?
  private var vertices = 0
  private var background = [Float](repeating: 0, count: 4)

  private static let shaderSource = """
    #include <metal_stdlib>
    using namespace metal;

    struct Input {
      float3 position [[attribute(0)]];
      float4 color [[attribute(1)]];
    };
    struct Output {
      float4 position [[position]];
      float4 color;
    };

    vertex Output v_main(Input v [[stage_in]]) {
      Output out;
      out.position = float4(v.position, 1.0);
      out.color = v.color;
      return out;
    }

    fragment float4 f_main(Output v [[stage_in]]) {
      return v.color;
    }
    """

  init?(view: MTKView) {
    guard let device = view.device,
          let queue = device.makeCommandQueue(),
          let library = try? device.makeLibrary(source: Self.shaderSource, options: nil),
          let vertex = library.makeFunction(name: "v_main"),
          let fragment = library.makeFunction(name: "f_main") else {
      return nil
    }
    let desc = MTLRenderPipelineDescriptor()
    desc.vertexFunction = vertex
    desc.fragmentFunction = fragment
    desc.colorAttachments[0].pixelFormat = view.colorPixelFormat
    desc.depthAttachmentPixelFormat = view.depthStencilPixelFormat
    let attrs = MTLVertexDescriptor()
    attrs.attributes[0].format = .float3
    attrs.attributes[0].offset = 0
    attrs.attributes[0].bufferIndex = 0
    attrs.attributes[1].format = .float4
    attrs.attributes[1].offset = 12
    attrs.attributes[1].bufferIndex = 0
    attrs.layouts[0].stride = 28
    attrs.layouts[0].stepFunction = .perVertex
    desc.vertexDescriptor = attrs
    let depth = MTLDepthStencilDescriptor()
    depth.depthCompareFunction = .less
    depth.isDepthWriteEnabled = true
    guard let pipeline = try? device.makeRenderPipelineState(descriptor: desc),
          let depthState = device.makeDepthStencilState(descriptor: depth) else {
      return nil
    }
    self.device = device
    self.queue = queue
    self.pipeline = pipeline
    self.depthState = depthState
    background = [0.07, 0.09, 0.12, 1.0]
    super.init()
  }

  func load(data: Data, color: [Float]) -> Bool {
    let buffer = data.withUnsafeBytes { raw -> MTLBuffer? in
      guard let pointer = raw.baseAddress else { return nil }
      return device.makeBuffer(
        bytes: pointer, length: data.count, options: .storageModeShared
      )
    }
    guard let buffer else { return false }
    vertexBuffer = buffer
    vertices = data.count / (7 * 4)
    background = color
    return true
  }

  func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

  func draw(in view: MTKView) {
    guard let pass = view.currentRenderPassDescriptor,
          let drawable = view.currentDrawable,
          let cmd = queue.makeCommandBuffer(),
          let buffer = vertexBuffer else { return }
    pass.colorAttachments[0].loadAction = .clear
    pass.colorAttachments[0].clearColor = MTLClearColor(
      red: Double(background[0]),
      green: Double(background[1]),
      blue: Double(background[2]),
      alpha: Double(background[3])
    )
    pass.depthAttachment.loadAction = .clear
    pass.depthAttachment.clearDepth = 1.0
    guard let encoder = cmd.makeRenderCommandEncoder(descriptor: pass) else {
      return
    }
    encoder.setRenderPipelineState(pipeline)
    encoder.setDepthStencilState(depthState)
    encoder.setCullMode(.none)
    encoder.setVertexBuffer(buffer, offset: 0, index: 0)
    encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices)
    encoder.endEncoding()
    cmd.present(drawable)
    cmd.commit()
  }
}
