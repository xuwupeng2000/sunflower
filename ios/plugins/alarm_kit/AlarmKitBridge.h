#import <Foundation/Foundation.h>

typedef void (^SnoozeCallback)(void);

@interface AlarmKitBridge : NSObject
+ (void)setSnoozeCallback:(SnoozeCallback)callback;
+ (void)requestAuthorization;
+ (void)scheduleWeeklyJSON:(NSString *)json;
+ (void)cancelAlarm:(NSString *)alarmId;
+ (NSString *)snoozeLogJSON;
+ (void)startObserving;
@end
