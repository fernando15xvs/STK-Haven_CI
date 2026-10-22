package com.Fernando_S_ac.gym_tracker

import android.app.ActivityManager
import android.content.Context
import android.opengl.GLES30
import android.opengl.GLSurfaceView
import android.os.Handler
import android.os.Looper
import android.view.View
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import javax.microedition.khronos.egl.EGLConfig
import javax.microedition.khronos.opengles.GL10

/**
 * INACTIVE, experimental ES3.0 55-joint vertex-shader skinning.
 * CPU preprocesses glTF's 8 position morph targets, GPU multiplies
 * JOINTS_0 / WEIGHTS_0 by a uniform matrix palette.
 * This renderer is NOT attached to workout playback and has no 24Hz loop.
 */
internal class StkAnatomyGpuSkinnedFactory(
    private val messenger: BinaryMessenger,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView =
        StkAnatomyGpuSkinnedView(context, viewId, messenger)
}

private class StkAnatomyGpuSkinnedView(
    context: Context,
    id: Int,
    messenger: BinaryMessenger,
) : PlatformView {
    private val channel = MethodChannel(messenger, "stk_haven/anatomy_gpu_skinning/$id")
    private val renderer = StkGpuJointRenderer()
    private val surface = GLSurfaceView(context)
    private var destroyed = false

    init {
        val manager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val glVersion = manager.deviceConfigurationInfo.reqGlEsVersion
        if (glVersion >= 0x30000) {
            surface.setEGLContextClientVersion(3)
            surface.setEGLConfigChooser(8, 8, 8, 8, 16, 0)
            surface.setRenderer(renderer)
            surface.renderMode = GLSurfaceView.RENDERMODE_WHEN_DIRTY
        }
        channel.setMethodCallHandler { call, result ->
            if (destroyed) {
                result.error("disposed", "GPU skinning view disposed", null)
                return@setMethodCallHandler
            }
            if (call.method != "drawSkinned" && call.method != "drawMorphed") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            if (glVersion < 0x30000) {
                result.error("unsupported_gpu", "Requires OpenGL ES 3.0", null)
                return@setMethodCallHandler
            }
            val params = call.arguments as? Map<*, *>
            val positions = params?.get("vertices") as? FloatArray
            val reuseMesh = params?.get("reuseMesh") == true
            val morphMode = call.method == "drawMorphed"
            val reuseMorphMesh = params?.get("reuseMorphMesh") == true
            val morphDeltas = params?.get("morphDeltas") as? FloatArray
            val morphWeights = params?.get("morphWeights") as? FloatArray
            val bones = params?.get("bones") as? FloatArray
            val camera = params?.get("camera") as? FloatArray
            val background = params?.get("background") as? FloatArray
            // Compact packets are legal only when vertices are omitted.
            // Native GL thread verifies that the current view owns a mesh.
            val meshValid = if (morphMode) {
                if (reuseMorphMesh) positions == null && morphDeltas == null
                else positions != null && positions.isNotEmpty() &&
                    positions.size % (18 * 3) == 0 &&
                    positions.size <= 25000 * 3 * 18 &&
                    positions.all { it.isFinite() } &&
                    morphDeltas != null &&
                    morphDeltas.size == (positions.size / 18) * 24 &&
                    morphDeltas.all { it.isFinite() }
            } else if (reuseMesh) positions == null else
                positions != null && positions.isNotEmpty() &&
                positions.size % (18 * 3) == 0 &&
                positions.size <= 25000 * 3 * 18 &&
                positions.all { it.isFinite() }
            val weightsValid = if (!morphMode) morphDeltas == null &&
                morphWeights == null && !reuseMorphMesh else
                morphWeights != null && morphWeights.size == 8 &&
                morphWeights.all { it.isFinite() && it >= 0f && it <= 1.025f }
            if (!meshValid || !weightsValid || bones == null || camera == null ||
                background == null || bones.size != 55 * 16 ||
                camera.size != 20 || background.size != 4 ||
                bones.any { !it.isFinite() } ||
                camera.any { !it.isFinite() } ||
                background.any { !it.isFinite() || it < 0f || it > 1f }) {
                result.error("invalid_skin_mesh", "Unsafe GPU joint packet", null)
                return@setMethodCallHandler
            }
            if (positions != null) {
                for (offset in positions.indices step 18) {
                    var weight = 0f
                    for (j in 0..3) {
                        val joint = positions[offset + 6 + j]
                        val w = positions[offset + 10 + j]
                        if (joint < 0f || joint > 54f ||
                            joint != joint.toInt().toFloat() ||
                            w < 0f || w > 1.025f) {
                            result.error("invalid_skin_weights", "Invalid joint blend", null)
                            return@setMethodCallHandler
                        }
                        weight += w
                    }
                    if (kotlin.math.abs(weight - 1f) > 0.025f) {
                        result.error("invalid_skin_weights", "Unnormalized skinning", null)
                        return@setMethodCallHandler
                    }
                }
            }
            surface.queueEvent {
                if ((morphMode && reuseMorphMesh && !renderer.hasMorphMesh()) ||
                    (!morphMode && reuseMesh && !renderer.hasStandardMesh())) {
                    Handler(Looper.getMainLooper()).post {
                        result.error("missing_gpu_mesh",
                            "Compact frame has no acknowledged mesh", null)
                    }
                    return@queueEvent
                }
                if (morphMode) {
                    if (positions != null && morphDeltas != null) {
                        renderer.updateMorph(positions, morphDeltas,
                            morphWeights!!, bones, camera, background)
                    } else {
                        renderer.updateMorphPose(
                            morphWeights!!, bones, camera, background)
                    }
                } else if (positions != null) {
                    renderer.update(positions, bones, camera, background)
                } else {
                    renderer.updatePose(bones, camera, background)
                }
                // GLSurfaceView may process queued events BEFORE the first
                // onSurfaceCreated. A false early verdict would disable GPU
                // even on compatible hardware. Acknowledge after shader init.
                renderer.whenInitialized { supported ->
                    Handler(Looper.getMainLooper()).post {
                        if (destroyed) {
                            result.error("disposed", "GPU view disposed", null)
                        } else if (!supported ||
                            (morphMode && !renderer.supportsMorphs())) {
                            result.error("shader_unavailable",
                                "Device cannot compile the 55-bone GLES3 shader", null)
                        } else {
                            surface.requestRender()
                            result.success(true)
                        }
                    }
                }
            }
        }
    }

    override fun getView(): View = surface
    override fun dispose() {
        destroyed = true
        channel.setMethodCallHandler(null)
        surface.onPause()
    }
}

private class StkGpuJointRenderer : GLSurfaceView.Renderer {
    private val vertexSource = """
        #version 300 es
        precision highp float;
        in vec3 aPosition;
        in vec3 aNormal;
        in vec4 aJoint;
        in vec4 aWeight;
        in vec4 aColor;
        uniform mat4 uBones[55];
        uniform vec4 uCamera[5];
        out vec4 vColor;

        void main() {
            ivec4 j = ivec4(aJoint + vec4(0.5));
            mat4 skin =
                aWeight.x * uBones[j.x] + aWeight.y * uBones[j.y] +
                aWeight.z * uBones[j.z] + aWeight.w * uBones[j.w];
            vec3 world = (skin * vec4(aPosition, 1.0)).xyz;
            vec3 normal = normalize(mat3(skin) * aNormal);
            vec3 ray = world - uCamera[0].xyz;
            float depth = max(0.6, dot(ray, uCamera[3].xyz));
            float xx = dot(ray, uCamera[1].xyz) * uCamera[1].w;
            float yy = dot(ray, uCamera[2].xyz) * uCamera[2].w
                + uCamera[3].w * depth;
            float zz = depth * clamp((depth - 0.5) / 30.0, 0.0, 1.0);
            gl_Position = vec4(xx, yy, zz, depth);
            float shade = clamp(0.51 +
                0.45 * max(0.0, dot(normal, uCamera[4].xyz)), 0.39, 1.0);
            vColor = vec4(aColor.rgb * shade, aColor.a);
        }
    """.trimIndent()

    // Seven extra attribute streams are not added to the stable ES3 shader:
    // v9.3 compiles a separate 13-attribute morph shader for internal QA.
    private val morphVertexSource = vertexSource
        .replace("uniform mat4 uBones[55];", """
            in vec3 aMorph0;
            in vec3 aMorph1;
            in vec3 aMorph2;
            in vec3 aMorph3;
            in vec3 aMorph4;
            in vec3 aMorph5;
            in vec3 aMorph6;
            in vec3 aMorph7;
            uniform vec4 uMorphWeights[2];
            uniform mat4 uBones[55];
        """.trimIndent())
        .replace("vec3 world = (skin * vec4(aPosition, 1.0)).xyz;", """
            vec3 morphPosition = aPosition +
                aMorph0 * uMorphWeights[0].x +
                aMorph1 * uMorphWeights[0].y +
                aMorph2 * uMorphWeights[0].z +
                aMorph3 * uMorphWeights[0].w +
                aMorph4 * uMorphWeights[1].x +
                aMorph5 * uMorphWeights[1].y +
                aMorph6 * uMorphWeights[1].z +
                aMorph7 * uMorphWeights[1].w;
            vec3 world = (skin * vec4(morphPosition, 1.0)).xyz;
        """.trimIndent())

    private val fragmentSource = """
        #version 300 es
        precision mediump float;
        in vec4 vColor;
        out vec4 fragColor;
        void main() { fragColor = vColor; }
    """.trimIndent()

    private var program = 0
    private var indices = intArrayOf()
    private var bonesLocation = -1
    private var cameraLocation = -1
    private var morphProgram = 0
    private var morphReady = false
    private var morphIndices = intArrayOf()
    private var morphBonesLocation = -1
    private var morphCameraLocation = -1
    private var morphWeightsLocation = -1
    private var positions: FloatBuffer? = null
    private var meshBufferId = 0
    private var uploadedBytes = 0
    private var meshDirty = false
    private var morphActive = false
    private var morphWeights = FloatArray(8)
    private var matrixPalette = FloatArray(55 * 16)
    private var cameraValues = FloatArray(20)
    private var background = floatArrayOf(0.07f, 0.09f, 0.12f, 1f)
    private var count = 0
    private var ready = false
    private var initialized = false
    private val pending = mutableListOf<(Boolean) -> Unit>()

    fun whenInitialized(callback: (Boolean) -> Unit) {
        if (initialized) callback(ready) else pending.add(callback)
    }

    private fun finishInitialize(supported: Boolean) {
        ready = supported
        initialized = true
        val callbacks = pending.toList()
        pending.clear()
        callbacks.forEach { it(supported) }
    }

    fun hasStandardMesh(): Boolean = positions != null &&
        count > 0 && !morphActive
    fun hasMorphMesh(): Boolean = positions != null &&
        count > 0 && morphActive
    fun supportsMorphs(): Boolean = morphReady

    fun update(vertices: FloatArray, bones: FloatArray, camera: FloatArray, bg: FloatArray) {
        val direct = ByteBuffer.allocateDirect(vertices.size * 4)
            .order(ByteOrder.nativeOrder()).asFloatBuffer()
        direct.put(vertices)
        direct.position(0)
        positions = direct
        count = vertices.size / 18
        morphActive = false
        meshDirty = true
        updatePose(bones, camera, bg)
    }

    fun updateMorph(vertices: FloatArray, deltas: FloatArray,
        weights: FloatArray, bones: FloatArray, camera: FloatArray, bg: FloatArray) {
        val vertexCount = vertices.size / 18
        val combined = ByteBuffer.allocateDirect(vertexCount * 42 * 4)
            .order(ByteOrder.nativeOrder()).asFloatBuffer()
        for (v in 0 until vertexCount) {
            combined.put(vertices, v * 18, 18)
            combined.put(deltas, v * 24, 24)
        }
        combined.position(0)
        positions = combined
        count = vertexCount
        meshDirty = true
        morphActive = true
        updateMorphPose(weights, bones, camera, bg)
    }

    fun updateMorphPose(weights: FloatArray, bones: FloatArray,
        camera: FloatArray, bg: FloatArray) {
        morphWeights = weights
        updatePose(bones, camera, bg)
    }

    fun updatePose(bones: FloatArray, camera: FloatArray, bg: FloatArray) {
        matrixPalette = bones
        cameraValues = camera
        background = bg
    }

    private fun compile(type: Int, source: String): Int {
        val shader = GLES30.glCreateShader(type)
        GLES30.glShaderSource(shader, source)
        GLES30.glCompileShader(shader)
        val status = IntArray(1)
        GLES30.glGetShaderiv(shader, GLES30.GL_COMPILE_STATUS, status, 0)
        if (status[0] != GLES30.GL_TRUE) {
            val info = GLES30.glGetShaderInfoLog(shader)
            GLES30.glDeleteShader(shader)
            throw IllegalStateException("GPU skin shader failed: $info")
        }
        return shader
    }

    override fun onSurfaceCreated(gl: GL10?, config: EGLConfig?) {
        initialized = false
        ready = false
        // EGL context loss invalidates GL objects, but retains the CPU copy
        // for re-uploading the mesh on this view's next static frame.
        meshBufferId = 0
        uploadedBytes = 0
        meshDirty = true
        morphReady = false
        morphProgram = 0
        try {
        val capacity = IntArray(1)
        GLES30.glGetIntegerv(GLES30.GL_MAX_VERTEX_UNIFORM_VECTORS, capacity, 0)
        if (capacity[0] < 225) {
            // 55 mat4 bone uniforms + 5 camera vec4, with shader headroom.
            finishInitialize(false)
            return
        }
        val vertex = compile(GLES30.GL_VERTEX_SHADER, vertexSource)
        val fragment = compile(GLES30.GL_FRAGMENT_SHADER, fragmentSource)
        program = GLES30.glCreateProgram()
        GLES30.glAttachShader(program, vertex)
        GLES30.glAttachShader(program, fragment)
        GLES30.glLinkProgram(program)
        GLES30.glDeleteShader(vertex)
        GLES30.glDeleteShader(fragment)
        val ok = IntArray(1)
        GLES30.glGetProgramiv(program, GLES30.GL_LINK_STATUS, ok, 0)
        if (ok[0] != GLES30.GL_TRUE) {
            throw IllegalStateException(GLES30.glGetProgramInfoLog(program))
        }
        indices = intArrayOf(
            GLES30.glGetAttribLocation(program, "aPosition"),
            GLES30.glGetAttribLocation(program, "aNormal"),
            GLES30.glGetAttribLocation(program, "aJoint"),
            GLES30.glGetAttribLocation(program, "aWeight"),
            GLES30.glGetAttribLocation(program, "aColor"),
        )
        bonesLocation = GLES30.glGetUniformLocation(program, "uBones[0]")
        cameraLocation = GLES30.glGetUniformLocation(program, "uCamera[0]")
        ready = indices.all { it >= 0 } && bonesLocation >= 0 && cameraLocation >= 0
        if (ready) {
            try {
                val attributes = IntArray(1)
                GLES30.glGetIntegerv(GLES30.GL_MAX_VERTEX_ATTRIBS, attributes, 0)
                if (attributes[0] >= 13) {
                    val morphVertex = compile(GLES30.GL_VERTEX_SHADER, morphVertexSource)
                    val morphFragment = compile(GLES30.GL_FRAGMENT_SHADER, fragmentSource)
                    morphProgram = GLES30.glCreateProgram()
                    GLES30.glAttachShader(morphProgram, morphVertex)
                    GLES30.glAttachShader(morphProgram, morphFragment)
                    GLES30.glLinkProgram(morphProgram)
                    GLES30.glDeleteShader(morphVertex)
                    GLES30.glDeleteShader(morphFragment)
                    val linked = IntArray(1)
                    GLES30.glGetProgramiv(morphProgram, GLES30.GL_LINK_STATUS, linked, 0)
                    if (linked[0] == GLES30.GL_TRUE) {
                        val names = arrayOf("aPosition", "aNormal", "aJoint",
                            "aWeight", "aColor", "aMorph0", "aMorph1",
                            "aMorph2", "aMorph3", "aMorph4", "aMorph5",
                            "aMorph6", "aMorph7")
                        morphIndices = names.map {
                            GLES30.glGetAttribLocation(morphProgram, it)
                        }.toIntArray()
                        morphBonesLocation = GLES30.glGetUniformLocation(
                            morphProgram, "uBones[0]")
                        morphCameraLocation = GLES30.glGetUniformLocation(
                            morphProgram, "uCamera[0]")
                        morphWeightsLocation = GLES30.glGetUniformLocation(
                            morphProgram, "uMorphWeights[0]")
                        morphReady = morphIndices.all { it >= 0 } &&
                            morphBonesLocation >= 0 && morphCameraLocation >= 0 &&
                            morphWeightsLocation >= 0
                    }
                }
            } catch (_: Exception) {
                // Optional shader failure must not disable the old v9.2 path.
                morphReady = false
            }
        }
        GLES30.glEnable(GLES30.GL_DEPTH_TEST)
        GLES30.glDepthFunc(GLES30.GL_LESS)
        GLES30.glDisable(GLES30.GL_CULL_FACE)
        finishInitialize(ready)
        } catch (_: Exception) {
            // Shader compile or link problems must trigger Flutter fallback,
            // NEVER crash the GL render thread of the full application.
            finishInitialize(false)
        }
    }
    override fun onSurfaceChanged(gl: GL10?, width: Int, height: Int) {
        GLES30.glViewport(0, 0, width, height)
    }

    override fun onDrawFrame(gl: GL10?) {
        GLES30.glClearColor(background[0], background[1],
            background[2], background[3])
        GLES30.glClear(GLES30.GL_COLOR_BUFFER_BIT or GLES30.GL_DEPTH_BUFFER_BIT)
        val mesh = positions ?: return
        if (!ready || count == 0 || (morphActive && !morphReady)) return
        val activeStride = if (morphActive) 42 else 18
        if (meshBufferId == 0) {
            val ids = IntArray(1)
            GLES30.glGenBuffers(1, ids, 0)
            meshBufferId = ids[0]
            if (meshBufferId == 0) return
        }
        GLES30.glBindBuffer(GLES30.GL_ARRAY_BUFFER, meshBufferId)
        if (meshDirty) {
            mesh.position(0)
            val bytes = count * activeStride * 4
            if (uploadedBytes != bytes) {
                GLES30.glBufferData(GLES30.GL_ARRAY_BUFFER, bytes,
                    mesh, GLES30.GL_DYNAMIC_DRAW)
                uploadedBytes = bytes
            } else {
                GLES30.glBufferSubData(GLES30.GL_ARRAY_BUFFER, 0, bytes, mesh)
            }
            meshDirty = false
        }
        val activeProgram = if (morphActive) morphProgram else program
        val activeIndices = if (morphActive) morphIndices else indices
        val boneUniform = if (morphActive) morphBonesLocation else bonesLocation
        val cameraUniform = if (morphActive) morphCameraLocation else cameraLocation
        GLES30.glUseProgram(activeProgram)
        GLES30.glUniformMatrix4fv(boneUniform, 55, false, matrixPalette, 0)
        GLES30.glUniform4fv(cameraUniform, 5, cameraValues, 0)
        if (morphActive) {
            GLES30.glUniform4fv(morphWeightsLocation, 2, morphWeights, 0)
        }
        val offsets = intArrayOf(0, 3, 6, 10, 14,
            18, 21, 24, 27, 30, 33, 36, 39)
        val sizes = intArrayOf(3, 3, 4, 4, 4,
            3, 3, 3, 3, 3, 3, 3, 3)
        for (i in activeIndices.indices) {
            GLES30.glVertexAttribPointer(activeIndices[i], sizes[i],
                GLES30.GL_FLOAT, false, activeStride * 4, offsets[i] * 4)
            GLES30.glEnableVertexAttribArray(activeIndices[i])
        }
        GLES30.glDrawArrays(GLES30.GL_TRIANGLES, 0, count)
        for (index in activeIndices) GLES30.glDisableVertexAttribArray(index)
        GLES30.glBindBuffer(GLES30.GL_ARRAY_BUFFER, 0)
    }
}
