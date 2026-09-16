# GroMore publishes its own consumer rules in the SDK AAR. Keep adapters that
# are added by a host application; they are discovered by the mediation SDK.
-keep class com.bytedance.msdk.adapter.** { *; }
-keep class com.bytedance.sdk.openadsdk.mediation.** { *; }
