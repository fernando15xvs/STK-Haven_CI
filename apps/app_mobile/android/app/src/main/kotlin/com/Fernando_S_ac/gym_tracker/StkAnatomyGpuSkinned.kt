package com.Fernando_S_ac.gym_tracker

import android.app.ActivityManager
import android.content.Context
import android.opengl.GLES30
import android.opengl.GLSurfaceView
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
            if (call.method != "drawSkinned") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            if (glVersion < 0x30000) {
                result.error("unsupported_gpu", "Requires OpenGL ES 3.0", null)
                return@setMethodCallHandler
            }
            val params = call.arguments as? Map<*, *>
            val positions = params?.get("vertices") as? FloatArray
            val bones = params?.get("bones") as? FloatArray
            val camera = params?.get("camera") as? FloatArray
            val background = params?.get("background") as? FloatArray
            if (positions == null || bones == null || camera == null ||
                background == null ||
                positions.isEmpty() ||
                positions.size % (18 * 3) != 0 ||
                positions.size > 25000 * 3 * 18 ||
                bones.size != 55 * 16 || camera.size != 20 ||
                background.size != 4 ||
                positions.any { !it.isFinite() } ||
                bones.any { !it.isFinite() } ||
                camera.any { !it.isFinite() } ||
                background.any { !it.isFinite() || it < 0f || it > 1f }) {
                result.error("invalid_skin_mesh", "Unsafe GPU joint packet", null)
                return@setMethodCallHandler
            }
            for (offset in positions.indices step 18) {
                var weight = 0f
                for (j in 0..3) {
                    val joint = positions[offset + 6 + j]
                    val w = positions[offset + 10 + j]
                    if (joint < 0f || joint > 54f || joint != joint.toInt().toFloat() ||
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
            surface.queueEvent { renderer.update(positions, bones, camera, background) }
            surface.requestRender()
            result.success(true)
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
    private var positions: FloatBuffer? = null
    private var matrixPalette = FloatArray(55 * 16)
    private var cameraValues = FloatArray(20)
    private var background = floatArrayOf(0.07f, 0.09f, 0.12f, 1f)
    private var count = 0
    private var ready = false

    fun update(vertices: FloatArray, bones: FloatArray, camera: FloatArray, bg: FloatArray) {
        val direct = ByteBuffer.allocateDirect(vertices.size * 4)
            .order(ByteOrder.nativeOrder()).asFloatBuffer()
        direct.put(vertices)
        direct.position(0)
        positions = direct
        count = vertices.size / 18
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
        val capacity = IntArray(1)
        GLES30.glGetIntegerv(GLES30.GL_MAX_VERTEX_UNIFORM_VECTORS, capacity, 0)
        if (capacity[0] < 225) {
            // 55 mat4 bone uniforms + 5 camera vec4, with shader headroom.
            ready = false
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
        GLES30.glEnable(GLES30.GL_DEPTH_TEST)
        GLES30.glDepthFunc(GLES30.GL_LESS)
        GLES30.glDisable(GLES30.GL_CULL_FACE)
    }

    override fun onSurfaceChanged(gl: GL10?, width: Int, height: Int) {
        GLES30.glViewport(0, 0, width, height)
    }

    override fun onDrawFrame(gl: GL10?) {
        GLES30.glClearColor(background[0], background[1],
            background[2], background[3])
        GLES30.glClear(GLES30.GL_COLOR_BUFFER_BIT or GLES30.GL_DEPTH_BUFFER_BIT)
        val mesh = positions ?: return
        if (!ready || count == 0) return
        GLES30.glUseProgram(program)
        GLES30.glUniformMatrix4fv(bonesLocation, 55, false, matrixPalette, 0)
        GLES30.glUniform4fv(cameraLocation, 5, cameraValues, 0)
        val offsets = intArrayOf(0, 3, 6, 10, 14)
        val sizes = intArrayOf(3, 3, 4, 4, 4)
        for (i in indices.indices) {
            mesh.position(offsets[i])
            GLES30.glVertexAttribPointer(indices[i], sizes[i],
                GLES30.GL_FLOAT, false, 18 * 4, mesh)
            GLES30.glEnableVertexAttribArray(indices[i])
        }
        GLES30.glDrawArrays(GLES30.GL_TRIANGLES, 0, count)
        for (index in indices) GLES30.glDisableVertexAttribArray(index)
        mesh.position(0)
    }
}
