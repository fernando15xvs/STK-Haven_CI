package com.Fernando_S_ac.gym_tracker

import android.content.Context
import android.opengl.GLES20
import android.opengl.GLSurfaceView
import android.view.View
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import java.nio.ByteBuffer
import java.nio.ByteOrder
import javax.microedition.khronos.egl.EGLConfig
import javax.microedition.khronos.opengles.GL10

/**
 * Experimental, OFFLINE ONLY GLES2 16-bit-Z-buffer rasterizer.
 * Dart still runs morph targets/55-joint CPU skinning, then sends STATIC
 * clip-space triangles. Native GLES handles interpolated vertex colors,
 * occlusion and frame clearing; NOT a production GPU skinner.
 */
internal class StkAnatomyGpuReviewFactory(
    private val messenger: BinaryMessenger,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView =
        StkAnatomyGpuReview(context, viewId, messenger)
}

private class StkAnatomyGpuReview(
    context: Context,
    id: Int,
    messenger: BinaryMessenger,
) : PlatformView {
    private val renderer = StkGpuTriangleRenderer()
    private val surface = GLSurfaceView(context)
    private val channel = MethodChannel(messenger, "stk_haven/anatomy_gpu_static/$id")
    private var destroyed = false

    init {
        surface.setEGLContextClientVersion(2)
        surface.setEGLConfigChooser(8, 8, 8, 8, 16, 0)
        surface.setRenderer(renderer)
        surface.renderMode = GLSurfaceView.RENDERMODE_WHEN_DIRTY
        channel.setMethodCallHandler { call, result ->
            if (destroyed) {
                result.error("disposed", "GPU view has been disposed", null)
                return@setMethodCallHandler
            }
            if (call.method != "draw") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val args = call.arguments as? Map<*, *>
            val vertices = args?.get("vertices") as? FloatArray
            val background = args?.get("background") as? FloatArray
            if (vertices == null || background == null ||
                vertices.size % 21 != 0 || vertices.isEmpty() ||
                vertices.size > 25000 * 3 * 7 || background.size != 4 ||
                vertices.any { !it.isFinite() } ||
                background.any { !it.isFinite() || it < 0f || it > 1f }) {
                result.error("invalid_mesh", "Invalid bounded static GPU packet", null)
                return@setMethodCallHandler
            }
            // Flutter codec has already decoded Float32List into FloatArray.
            // Transfer ownership to the GL thread, never mutate the arrays.
            surface.queueEvent {
                renderer.update(vertices, background)
            }
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

private class StkGpuTriangleRenderer : GLSurfaceView.Renderer {
    private val vertexSource = """
        attribute vec3 aPosition;
        attribute vec4 aColor;
        varying vec4 vColor;
        void main() {
            gl_Position = vec4(aPosition, 1.0);
            vColor = aColor;
        }
    """.trimIndent()
    private val fragmentSource = """
        precision mediump float;
        varying vec4 vColor;
        void main() { gl_FragColor = vColor; }
    """.trimIndent()
    private var program = 0
    private var positionAttribute = -1
    private var colorAttribute = -1
    private var mesh: java.nio.FloatBuffer? = null
    private var count = 0
    private var bg = floatArrayOf(0.07f, 0.09f, 0.12f, 1f)

    fun update(vertices: FloatArray, background: FloatArray) {
        val data = ByteBuffer.allocateDirect(vertices.size * 4)
            .order(ByteOrder.nativeOrder()).asFloatBuffer()
        data.put(vertices)
        data.position(0)
        mesh = data
        count = vertices.size / 7
        bg = background
    }

    private fun compile(type: Int, source: String): Int {
        val shader = GLES20.glCreateShader(type)
        GLES20.glShaderSource(shader, source)
        GLES20.glCompileShader(shader)
        val ok = IntArray(1)
        GLES20.glGetShaderiv(shader, GLES20.GL_COMPILE_STATUS, ok, 0)
        if (ok[0] != GLES20.GL_TRUE) {
            val message = GLES20.glGetShaderInfoLog(shader)
            GLES20.glDeleteShader(shader)
            throw IllegalStateException("GLES shader compile failed: $message")
        }
        return shader
    }

    override fun onSurfaceCreated(gl: GL10?, config: EGLConfig?) {
        val vertex = compile(GLES20.GL_VERTEX_SHADER, vertexSource)
        val fragment = compile(GLES20.GL_FRAGMENT_SHADER, fragmentSource)
        program = GLES20.glCreateProgram()
        GLES20.glAttachShader(program, vertex)
        GLES20.glAttachShader(program, fragment)
        GLES20.glLinkProgram(program)
        GLES20.glDeleteShader(vertex)
        GLES20.glDeleteShader(fragment)
        val linked = IntArray(1)
        GLES20.glGetProgramiv(program, GLES20.GL_LINK_STATUS, linked, 0)
        if (linked[0] != GLES20.GL_TRUE) {
            throw IllegalStateException(GLES20.glGetProgramInfoLog(program))
        }
        positionAttribute = GLES20.glGetAttribLocation(program, "aPosition")
        colorAttribute = GLES20.glGetAttribLocation(program, "aColor")
        GLES20.glDisable(GLES20.GL_CULL_FACE)
        GLES20.glEnable(GLES20.GL_DEPTH_TEST)
        GLES20.glDepthFunc(GLES20.GL_LESS)
    }

    override fun onSurfaceChanged(gl: GL10?, width: Int, height: Int) {
        GLES20.glViewport(0, 0, width, height)
    }

    override fun onDrawFrame(gl: GL10?) {
        GLES20.glClearColor(bg[0], bg[1], bg[2], bg[3])
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT or GLES20.GL_DEPTH_BUFFER_BIT)
        val vertices = mesh ?: return
        if (program == 0 || count == 0) return
        GLES20.glUseProgram(program)
        // Seven floats/vertex: three projected clip-space xyz + four RGBA.
        vertices.position(0)
        GLES20.glVertexAttribPointer(
            positionAttribute, 3, GLES20.GL_FLOAT, false, 28, vertices,
        )
        vertices.position(3)
        GLES20.glVertexAttribPointer(
            colorAttribute, 4, GLES20.GL_FLOAT, false, 28, vertices,
        )
        GLES20.glEnableVertexAttribArray(positionAttribute)
        GLES20.glEnableVertexAttribArray(colorAttribute)
        GLES20.glDrawArrays(GLES20.GL_TRIANGLES, 0, count)
        GLES20.glDisableVertexAttribArray(positionAttribute)
        GLES20.glDisableVertexAttribArray(colorAttribute)
        vertices.position(0)
    }
}
