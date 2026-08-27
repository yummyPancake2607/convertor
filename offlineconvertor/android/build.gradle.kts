allprojects {
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
// Several Flutter plugins still pin an older compileSdk than their own androidx
// dependencies now require, which fails the AAR metadata check. Raising every
// plugin module to the app's compileSdk fixes that without touching plugin
// sources. compileSdk only controls which APIs are available at compile time;
// minSdk and targetSdk are untouched, so runtime behaviour is unaffected.
subprojects {
    afterEvaluate {
        extensions.findByName("android")?.let { android ->
            val ext = android as com.android.build.gradle.BaseExtension
            if (ext.compileSdkVersion?.removePrefix("android-")?.toIntOrNull()
                    ?.let { it < 36 } == true
            ) {
                ext.compileSdkVersion(36)
            }
            // Some plugins also predate the namespace requirement.
            if (ext.namespace == null) {
                ext.namespace = project.group.toString()
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}


tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
