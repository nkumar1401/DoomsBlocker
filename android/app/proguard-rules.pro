# Flutter Engine and embedding keep rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# DoomsBlocker native application and bridge
-keep class com.doomsblocker.app.** { *; }
-keepclassmembers class com.doomsblocker.app.** { *; }

# Google Play Billing Client (In-App Purchases & Subscriptions)
-keep class com.android.billingclient.** { *; }
-keep class com.android.vending.billing.** { *; }

# Google Play Core In-App Updates
-keep class com.google.android.play.core.** { *; }

# Mobile Scanner & Google ML Kit Barcode Scanning
-keep class dev.steenbakker.mobile_scanner.** { *; }
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.vision.** { *; }
-keep class com.google.android.gms.tasks.** { *; }

# Flutter Plugins (Shared Preferences, etc.)
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep class io.flutter.plugins.packageinfo.** { *; }
-keep class io.flutter.plugins.urllauncher.** { *; }

# Standard Android Components
-keep public class * extends android.app.Activity
-keep public class * extends android.app.Application
-keep public class * extends android.app.Service
-keep public class * extends android.content.BroadcastReceiver
-keep public class * extends android.content.ContentProvider
-keep public class * extends android.accessibilityservice.AccessibilityService
-keep public class * extends android.preference.Preference

# Preserve annotations, signatures, and reflection attributes
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod,SourceFile,LineNumberTable
-dontwarn io.flutter.**
-dontwarn com.google.android.play.core.**
-dontwarn dev.steenbakker.mobile_scanner.**

