# Unity Ads Proguard Rules
-keep class com.unity3d.ads.** { *; }
-keep interface com.unity3d.ads.** { *; }
-keep class com.unity3d.services.** { *; }
-keep interface com.unity3d.services.** { *; }

# Huawei HMS Proguard Rules (often bundled with ad networks)
-dontwarn com.huawei.hms.**
-dontwarn com.huawei.hianalytics.**
-keep class com.huawei.hms.** { *; }
-keep interface com.huawei.hms.** { *; }

# Conscrypt/OkHttp/Square Rules
-dontwarn org.conscrypt.**
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**
-dontwarn org.codehaus.mojo.animal_sniffer.**
