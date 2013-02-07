#import "SPLoggerStorm.h"
#import "SPLogger.h"
#import "SPLoggerEvent.h"
#import <CoreFoundation/CoreFoundation.h>

@implementation SPLoggerStorm

@synthesize url;
@synthesize projectID;
@synthesize authToken;

- (id) init: (NSString *) inputURL authToken: (NSString *) thisAuthToken projectID: (NSString *) thisProjectID
{
    self.projectID = thisProjectID;
    self.authToken = thisAuthToken;
    
    NSString *baseURL = inputURL;
    if (baseURL == nil)
        baseURL = @"https://api.splunkstorm.com/1/inputs/http";
    
    NSString *source = [SPLogger appname];   // self.projectID;    // source=angrycats
    NSString *sourcetype = @"splogger";   // sourcetype=splogger
    NSString *host = [SPLogger networkInfo]; // host=<info about user's device>
    
    
    self.url = [NSString stringWithFormat:@"%@?index=%@&source=%@&sourcetype=%@&host=%@",
                baseURL,
                [self.projectID stringByAddingPercentEscapesUsingEncoding: NSASCIIStringEncoding],
                [source     stringByAddingPercentEscapesUsingEncoding: NSASCIIStringEncoding],
                [sourcetype stringByAddingPercentEscapesUsingEncoding: NSASCIIStringEncoding],
                [host       stringByAddingPercentEscapesUsingEncoding: NSASCIIStringEncoding]];
    return self;
}

// replace " with \", and \n with \\n.
+ (NSString *) escapeString: (NSString*) value
{
    return [[value stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""]
            stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
}

# warning dev: check for memory leak
// http://codeshaker.blogspot.com/2012/03/base64-encoding-of-strings.html
+ (NSString *)base64EncodedStringWithString:(NSString *)aString {
    CFHTTPMessageRef message = CFHTTPMessageCreateEmpty(kCFAllocatorDefault, TRUE);
    CFHTTPMessageAddAuthentication(message, NULL, (CFStringRef)@"  ", 
                                   (__bridge_retained CFStringRef)aString, (__bridge_retained CFStringRef)@"Basic", NO);
    CFStringRef authString = CFHTTPMessageCopyHeaderFieldValue(message, (CFStringRef)@"Authorization");
    NSString *result = [(__bridge_transfer  NSString *)authString substringFromIndex:10];
    CFRelease(message);
    //CFRelease(authString);
    return result;
}

- (BOOL) flushEvents: (NSMutableArray *)eventQueue
{
    // GENERATE AUTH STRING FOR HEADER
    // old way NSString *authStr = [NSString  stringWithFormat:@"%@:%@", self.authToken, @""]; // authtoken is username, password is empty
    NSString *authStr = [NSString  stringWithFormat:@"%@:%@", @"x", self.authToken]; // authtoken is password, username is empty
    NSString *authValue = [NSString stringWithFormat:@"Basic %@", [SPLoggerStorm base64EncodedStringWithString: authStr]];
    
    // SET UP REQUEST HEADER 
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL: [NSURL URLWithString: self.url]];
    [request setValue:authValue forHTTPHeaderField:@"Authorization"];
    // TODO: uncomment below line when data is actually gzipped.  currently not gzipped    
    //[request setValue:@"gzip"   forHTTPHeaderField:@"Content-Encoding"];
    //[request setValue:@"text/plain; charset=UTF-8" forHTTPHeaderField:@"Content-Encoding"]; //!!!???LOOKUP
    [request setHTTPMethod:@"POST"];
    
    // GENERATE MESSAGE BODY
    NSMutableString *allEventTexts = [[NSMutableString alloc] init];
    // for each event
#warning dev: consider only doing N events, not all!
    for(SPLoggerEvent* eventObj in eventQueue) {
        // append all events together with newlines.
        [allEventTexts appendFormat:@"%@\n", eventObj];
    }
    
    // SET BODY CONTENT
    [request setHTTPBody:[allEventTexts dataUsingEncoding:NSUTF8StringEncoding]];

    // MAKE SYNCHRONOUS REQUEST
    NSError               *error = nil;
    NSHTTPURLResponse  *response = nil; 
    //NSData* data = 
    [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    int statusCode = [response statusCode];

    BOOL success = statusCode < 300;
    
    NSString *msg = [error description];
    
    if (success) {
        NSLog(@"successfully sent %lu events. %@", (unsigned long)[eventQueue count], msg);
        [eventQueue removeObjectsInArray:eventQueue];
    } else
        NSLog(@"sending events to %@ failed.  Status code: %d -- %@", self.url, statusCode, response);
    return success;   
}

@end
