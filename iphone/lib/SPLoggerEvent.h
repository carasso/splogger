
#import <Foundation/Foundation.h>

@interface SPLoggerEvent : NSObject 

@property(nonatomic, retain) NSString *event;
@property(nonatomic, retain) NSMutableDictionary *props;
@property(nonatomic, retain) NSNumber *timestamp;

- (id)init:(NSString*)event properties: (NSMutableDictionary *)props timestamp: (NSNumber*)timestamp;
- (NSString *)description;
@end
