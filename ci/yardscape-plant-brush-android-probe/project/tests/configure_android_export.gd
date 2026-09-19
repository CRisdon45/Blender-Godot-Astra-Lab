@tool
extends SceneTree

func _initialize() -> void:
	call_deferred("_configure")

func _configure() -> void:
	var android_sdk := OS.get_environment("ANDROID_SDK_ROOT")
	var java_sdk := OS.get_environment("JAVA_HOME")
	if android_sdk.is_empty() or java_sdk.is_empty():
		push_error("ANDROID_SDK_ROOT and JAVA_HOME are required")
		quit(2)
		return
	var settings := EditorInterface.get_editor_settings()
	settings.set_setting("export/android/android_sdk_path", android_sdk)
	settings.set_setting("export/android/java_sdk_path", java_sdk)
	print("YARDSCAPE_ANDROID_EXPORT_SETTINGS=configured")
	quit()
