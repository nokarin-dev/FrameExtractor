import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.nokarin.frameextractor"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlin {
        compilerOptions {
            jvmTarget = JvmTarget.JVM_17
        }
    }

    defaultConfig {
        applicationId = "com.nokarin.frameextractor"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

androidComponents {
    onVariants { variant ->
        variant.outputs.forEach { output ->
            val abiCodes = mapOf(
                "arm64-v8a" to 1,
                "armeabi-v7a" to 2,
                "x86_64" to 3,
            )
            if (output is com.android.build.api.variant.impl.VariantOutputImpl) {
                val abi = output.filters.find {
                    it.filterType == com.android.build.api.variant.FilterConfiguration.FilterType.ABI
                }?.identifier
                if (abi != null) {
                    output.versionCode.set(
                        (flutter.versionCode * 10) + (abiCodes[abi] ?: 0)
                    )
                }
            }
        }
    }
}

dependencies {
    implementation("androidx.documentfile:documentfile:1.1.0")
}

flutter {
    source = "../.."
}