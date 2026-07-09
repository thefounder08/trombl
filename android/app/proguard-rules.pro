# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Supabase / Ktor
-keep class io.github.jan.supabase.** { *; }
-dontwarn io.ktor.**
-keep class io.ktor.** { *; }

# Keep enums
-keepclassmembers enum * { *; }

# Flutter Play Store split/deferred components (not used but referenced by Flutter engine)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }
