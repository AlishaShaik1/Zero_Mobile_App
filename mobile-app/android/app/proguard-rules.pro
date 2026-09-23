# Flutter & llamadart ProGuard rules
# Keep Flutter engine classes
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep llamadart native bridge classes
-keep class com.neoul.llamadart.** { *; }
-keep class llama.** { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Don't warn about missing optional dependencies
-dontwarn javax.annotation.**
-dontwarn kotlin.reflect.**
-dontwarn org.conscrypt.**
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**

# Aggressive shrink: remove unused OkHttp/Retrofit internals (pulled by dio/http)
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }

# Shrink SQFlite — keep only what's used
-keep class com.tekartik.sqflite.** { *; }
-dontwarn com.tekartik.sqflite.**

# Strip Kotlin metadata that inflates APK
-keepattributes !RuntimeInvisibleAnnotations
-keepattributes !RuntimeInvisibleParameterAnnotations

# Remove Kotlin coroutines debug infrastructure in release
-assumenosideeffects class kotlinx.coroutines.internal.MainDispatcherLoader {
    public static boolean FAST_SERVICE_LOADER_ENABLED;
}

# Remove all logging in release build
-assumenosideeffects class android.util.Log {
    public static int v(...);
    public static int d(...);
    public static int i(...);
}
