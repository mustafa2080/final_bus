# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-dontwarn io.flutter.embedding.**
# Firebase / Google Play Services
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# App's own FCM service / classes (referenced by manifest, keep names intact)
-keep class com.kidsbus.mybus.** { *; }

# Kotlin metadata / coroutines
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod
-dontwarn kotlinx.coroutines.**

# Play Core (deferred components) — avoids R8 missing_rules crash on some Flutter setups
-dontwarn com.google.android.play.core.**
