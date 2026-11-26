plugins {
    id("com.android.application")
}

// Storefront endpoint, fixed at build time:
//   ./gradlew assembleRelease -PSHOP_API_URL=http://192.168.1.20:8787/api
// or the SHOP_API_URL environment variable. Default: mock.shop.
val shopApiUrl: String = (findProperty("SHOP_API_URL") as String?)
    ?.takeIf { it.isNotBlank() }
    ?: System.getenv("SHOP_API_URL")?.takeIf { it.isNotBlank() }
    ?: "https://apparel-large-catalog.mock.shop/api"

android {
    namespace = "dev.whiskerrs.shopbench.catalyst"
    compileSdk = 35

    defaultConfig {
        applicationId = "dev.whiskerrs.shopbench.catalyst"
        minSdk = 24
        targetSdk = 35
        versionCode = 1
        versionName = "1.0.0"
        buildConfigField("String", "SHOP_API_URL", "\"" + shopApiUrl.replace("\"", "\\\"") + "\"")
    }

    buildFeatures {
        buildConfig = true
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            // Debug signing is enough for the benchmark APK.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    androidResources {
        // Keep www/ (the bundled web app) as-is, including files starting with "_".
        ignoreAssetsPattern = "!.svn:!.git:!.ds_store:!*.scc:!CVS:!thumbs.db:!picasa.ini:!*~"
    }
}
