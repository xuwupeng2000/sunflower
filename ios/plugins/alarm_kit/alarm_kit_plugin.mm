#include "alarm_kit_plugin.h"

#include "core/config/engine.h"
#include "core/io/json.h"
#include "core/object/class_db.h"
#include "core/variant/dictionary.h"

#include "AlarmKitBridge.h"

class AlarmKitPlugin : public Object {
	GDCLASS(AlarmKitPlugin, Object);

protected:
	static void _bind_methods() {
		ClassDB::bind_method(D_METHOD("request_authorization"), &AlarmKitPlugin::request_authorization);
		ClassDB::bind_method(D_METHOD("schedule_weekly", "alarm"), &AlarmKitPlugin::schedule_weekly);
		ClassDB::bind_method(D_METHOD("cancel", "alarm_id"), &AlarmKitPlugin::cancel);
		ClassDB::bind_method(D_METHOD("stop", "alarm_id"), &AlarmKitPlugin::stop);
		ClassDB::bind_method(D_METHOD("snooze_log_json"), &AlarmKitPlugin::snooze_log_json);
		ClassDB::bind_method(D_METHOD("active_alarms_json"), &AlarmKitPlugin::active_alarms_json);
		ClassDB::bind_method(D_METHOD("settings_language"), &AlarmKitPlugin::settings_language);
		ClassDB::bind_method(D_METHOD("start_timer", "timer_id", "title", "seconds"), &AlarmKitPlugin::start_timer);
		ClassDB::bind_method(D_METHOD("cancel_timer", "timer_id"), &AlarmKitPlugin::cancel_timer);
		ClassDB::bind_method(D_METHOD("finish_timer", "timer_id"), &AlarmKitPlugin::finish_timer);
		ClassDB::bind_method(D_METHOD("take_cancelled_timer"), &AlarmKitPlugin::take_cancelled_timer);
		ADD_SIGNAL(MethodInfo("snoozes_changed"));
	}

public:
	void request_authorization() {
		[AlarmKitBridge requestAuthorization];
	}

	void schedule_weekly(const Dictionary &alarm) {
		String json = JSON::stringify(alarm);
		[AlarmKitBridge scheduleWeeklyJSON:[NSString stringWithUTF8String:json.utf8().get_data()]];
	}

	void cancel(const String &alarm_id) {
		[AlarmKitBridge cancelAlarm:[NSString stringWithUTF8String:alarm_id.utf8().get_data()]];
	}

	void stop(const String &alarm_id) {
		[AlarmKitBridge stopAlarm:[NSString stringWithUTF8String:alarm_id.utf8().get_data()]];
	}

	String snooze_log_json() {
		NSString *json = [AlarmKitBridge snoozeLogJSON];
		return String::utf8([json UTF8String]);
	}

	String active_alarms_json() {
		NSString *json = [AlarmKitBridge activeAlarmsJSON];
		return String::utf8([json UTF8String]);
	}

	String settings_language() {
		NSString *code = [AlarmKitBridge settingsLanguage];
		return String::utf8([code UTF8String]);
	}

	void start_timer(const String &timer_id, const String &title, int seconds) {
		[AlarmKitBridge startTimer:[NSString stringWithUTF8String:timer_id.utf8().get_data()]
							 title:[NSString stringWithUTF8String:title.utf8().get_data()]
						   seconds:seconds];
	}

	void cancel_timer(const String &timer_id) {
		[AlarmKitBridge cancelTimer:[NSString stringWithUTF8String:timer_id.utf8().get_data()]];
	}

	void finish_timer(const String &timer_id) {
		[AlarmKitBridge finishTimer:[NSString stringWithUTF8String:timer_id.utf8().get_data()]];
	}

	String take_cancelled_timer() {
		NSString *timer_id = [AlarmKitBridge takeCancelledTimer];
		return String::utf8([timer_id UTF8String]);
	}

	void emit_snoozes_changed() {
		emit_signal("snoozes_changed");
	}
};

static AlarmKitPlugin *plugin_instance = nullptr;

void alarm_kit_init() {
	plugin_instance = memnew(AlarmKitPlugin);
	Engine::get_singleton()->add_singleton(Engine::Singleton("AlarmKit", plugin_instance));
	[AlarmKitBridge setSnoozeCallback:^{
		if (plugin_instance != nullptr) {
			plugin_instance->emit_snoozes_changed();
		}
	}];
	[AlarmKitBridge startObserving];
}

void alarm_kit_deinit() {
	[AlarmKitBridge setSnoozeCallback:nil];
	if (plugin_instance != nullptr) {
		Engine::get_singleton()->remove_singleton("AlarmKit");
		memdelete(plugin_instance);
		plugin_instance = nullptr;
	}
}
