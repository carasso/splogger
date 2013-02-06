
#import "SPLoggerEvent.h"

@implementation SPLoggerEvent

@synthesize event;
@synthesize props;
@synthesize timestamp;


- (id)init:(NSString*)thisEvent properties: (NSMutableDictionary *)thisProps timestamp: (NSNumber*)thisTimestamp
{
    if ((self = [super init]))  {
        self.event = thisEvent;
        self.props = [[NSMutableDictionary alloc] initWithDictionary: thisProps copyItems:YES]; 
        self.timestamp = thisTimestamp;
    }
    return self;
}

- (NSString *)description
{
    NSMutableString *fieldValues = [[NSMutableString alloc] init];
    // for each property of event
    for(NSString *key in self.props) {
        NSString *value = [self.props objectForKey:key];
        NSString *escapedValue = [value stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
        // make a string of field1="value1" field2="value2" ....
        [fieldValues appendFormat:@" %@=\"%@\"", key, escapedValue];
    }
    // make event body of:  1234567890 this is my event body field1="value 1" field2="value 2" ...
    // also replace \n with \\n, to ensure that each event is single line for easy parsing.
    return [[NSString stringWithFormat:@"%@ %@%@", self.timestamp, self.event, fieldValues]
            stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
}

@end
