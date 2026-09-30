#import <Foundation/Foundation.h>

typedef void (^SnoozeCallback)(void);

@interface AlarmKitBridge : NSObject
+ (void)setSnoozeCallback:(SnoozeCallback)callback;
+ (void)requestAuthorization;
+ (void)scheduleWeeklyJSON:(NSString *)json;
+ (void)cancelAlarm:(NSString *)alarmId;
+ (void)stopAlarm:(NSString *)alarmId;
+ (void)startTimer:(NSString *)timerId title:(NSString *)title seconds:(NSInteger)seconds;
+ (void)cancelTimer:(NSString *)timerId;
+ (void)finishTimer:(NSString *)timerId;
+ (NSString *)takeCancelledTimer;
+ (NSString *)snoozeLogJSON;
+ (NSString *)activeAlarmsJSON;
+ (NSString *)settingsLanguage;
+ (void)startObserving;
@end
