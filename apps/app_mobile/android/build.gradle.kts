// Some Flutter plugins (notably video_thumbnail 0.5.6) still declare
// jcenter() inside their own Android buildscript classpath. JCenter can no
// longer resolve the AGP 4.1 transitive libraries (ASM/Kotlin/Guava).
// Seed every subproject's BUILDSCRIPT repositories before that script runs.
// settings.gradle.kts/pluginManagement and the ordinary repositories below
// do not govern legacy buildscript { dependencies { classpath(...) } } blocks.
allprojects {
    buildscript {
        repositories {
            google()
            mavenCentral()
        }
    }
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
