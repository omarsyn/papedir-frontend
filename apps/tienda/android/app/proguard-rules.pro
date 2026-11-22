# Reglas para la compilación de release (R8).
# flutter_stripe trae clases opcionales de "push provisioning" que no se usan.
-dontwarn com.stripe.android.pushProvisioning.**
-dontwarn com.reactnativestripesdk.pushprovisioning.**
-keep class com.stripe.android.** { *; }
