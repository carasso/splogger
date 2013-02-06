
#import "SPLoggerWriter.h"

@interface SPLoggerStorm : NSObject <SPLoggerWriter>

@property(nonatomic, retain) NSString *url;
@property(nonatomic, retain) NSString *projectID;
@property(nonatomic, retain) NSString *authToken;

- (id) init: (NSString *) url authToken: (NSString *) authToken projectID: (NSString *) project_id;
- (BOOL) flushEvents: (NSMutableArray *)eventQueue;

@end

