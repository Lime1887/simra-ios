#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface RecordingShortcutBridge : NSObject

+ (BOOL)startRecording;
+ (BOOL)stopRecording;

@end

NS_ASSUME_NONNULL_END