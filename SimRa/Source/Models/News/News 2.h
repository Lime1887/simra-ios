//
//  News.h
//  SimRa
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface News : NSObject

@property (strong, nonatomic) NSMutableArray <NSDictionary *> *newsItems;
@property (nonatomic) NSInteger lastSeenNewsId;

@end

NS_ASSUME_NONNULL_END
