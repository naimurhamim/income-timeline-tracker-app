# Preserve flutter_local_notifications scheduled alarm models, receivers, and TypeTokens in release R8 builds.
-keep class com.dexterous.** { *; }
-keepclassmembers class com.dexterous.** { *; }
-keep enum com.dexterous.** { *; }

# Preserve Gson deserialization metadata & anonymous TypeToken subclasses for NotificationDetails JSON extras.
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod
-keep class com.google.gson.** { *; }
-keepclassmembers class com.google.gson.** { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
