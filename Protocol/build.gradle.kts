plugins {
    kotlin("multiplatform") version "2.2.20"
    kotlin("plugin.serialization") version "2.2.20"
}

group = "com.micyou.ios"
version = "2.0.0-1"

repositories {
    mavenCentral()
    google()
}

kotlin {
    iosArm64 {
        binaries.framework {
            baseName = "MicYouProtocol"
            isStatic = true
        }
    }

    sourceSets {
        val commonMain by getting {
            dependencies {
                implementation("org.jetbrains.kotlinx:kotlinx-serialization-protobuf:1.8.1")
            }
        }
    }
}
