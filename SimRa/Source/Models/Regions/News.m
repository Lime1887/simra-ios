//
//  News.m
//  SimRa
//

#import "News.h"
#import "../../Utils/Helper/NSString+hashCode.h"
#import "API.h"

@interface News ()
@property (nonatomic) NSInteger newsId;
@end

@implementation News

- (instancetype)init {
    self = [super init];
    return self;
}

+ (News *)sharedNews {
    static News *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_sync(onceToken, ^ {
        sharedInstance = [[News alloc] init];
    });
    return sharedInstance;
}

- (void)refresh {
    // News refresh logic
}

- (void)process:(NSData *)data {
    // News process logic
}

- (void)save {
    // News save logic
}

@end
