# MultiDex keep rules
-keep class androidx.multidex.MultiDexApplication { *; }
-keep class com.google.android.gms.** { *; }
-keep class com.google.firebase.** { *; }

# Keep Google Sign-In classes
-keep class com.google.android.gms.auth.api.signin.** { *; }
-keep class com.google.android.gms.common.api.** { *; }

# Keep reflection-based calls
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}