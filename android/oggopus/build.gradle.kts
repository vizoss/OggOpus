plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
    id("maven-publish")
}

android {
    namespace = "com.thk.oggopus"
    compileSdk = 34
    // r28 supplies a 16 KB-aligned libc++_shared.so as well as aligned native outputs.
    ndkVersion = "28.0.12674087"
    useLibrary("android.test.runner")
    useLibrary("android.test.base")

    defaultConfig {
        minSdk = 21
        testInstrumentationRunner = "android.test.InstrumentationTestRunner"
        targetSdk = 34
        consumerProguardFiles("consumer-rules.pro")
        externalNativeBuild {
            cmake { arguments += "-DANDROID_STL=c++_shared" }
        }
    }
    buildTypes { release { isMinifyEnabled = false } }
    externalNativeBuild { cmake { path = file("src/main/cpp/CMakeLists.txt") } }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    kotlinOptions { jvmTarget = "11" }
    publishing { singleVariant("release") { withSourcesJar() } }
}


afterEvaluate {
    publishing {
        publications {
            create<MavenPublication>("release") {
                from(components["release"])
                groupId = "io.github.vizoss.oggopus"
                artifactId = "oggopus"
                version = (findProperty("VERSION_NAME") as String?) ?: "1.0.0-SNAPSHOT"
            }
        }
        repositories {
            maven {
                name = "StaticMaven"
                url = uri(findProperty("staticMavenDir") ?: layout.buildDirectory.dir("maven-repository").get().asFile)
            }
        }
    }
}
