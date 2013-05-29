//
//  SPLLogger.m
//  mobile
//
//  Created by David Carasso on 7/9/12.
//  Copyright (c) 2012 Splunk. All rights reserved.
//

#import <stdio.h>
#import "SPLogger.h"
#import "SPLoggerEvent.h"
#import "SPLoggerStorm.h"
#import <CoreFoundation/CoreFoundation.h>
#include <sys/types.h>
#include <sys/sysctl.h>
#include <arpa/inet.h>
#include <net/if.h>
#include <netinet/in.h>
#include <ifaddrs.h>
#include <net/if_dl.h>
#import <UIKit/UIKit.h> 

#if ! defined(IFT_ETHER)
#define IFT_ETHER 0x6/* Ethernet CSMACD. Ethernet I or II */
#endif

// keep at most 100k events.  things will only get this 
// large if we can't connect for a long time.
// keep only the N most recent events.
#define MAX_EVENTS_TO_RETAIN 100000
#define DEFAULT_MAX_EVENTS_BEFORE_FLUSH 100
#define DEFAULT_MAX_SECS_BEFORE_FLUSH    30
static const BOOL DEFAULT_SHOULD_LOG_SYSTEM_DATA      = NO;
static const BOOL DEFAULT_SHOULD_LOG_SYSTEM_EVENTS    = NO;
static const BOOL DEFAULT_SHOULD_LOG_SYNCHRONOUSLY    = NO;

const NSString * SYS_APP_NAME_PROP        = @"sys_appname";
const NSString * SYS_NETWORKS_PROP        = @"sys_networks";
const NSString * SYS_USER_ID_PROP         = @"sys_user_id";
const NSString * SYS_MACHINE_PROP         = @"sys_machine";
const NSString * SYS_MODEL_PROP           = @"sys_model";
const NSString * SYS_DISK_SPACE_PROP      = @"sys_total_disk_space";
const NSString * SYS_FREE_DISK_SPACE_PROP = @"sys_free_disk_space";


@implementation SPLogger

@synthesize writer;
@synthesize eventQueue;
@synthesize metaProperties;
@synthesize authToken;
@synthesize projectID;
@synthesize uploadIntervalInEvents;
@synthesize uploadIntervalInSecs;
@synthesize logSysData;
@synthesize logSysEvents;
@synthesize logSynchronously;

//----------------------------------------
//--------- SINGLETON CODE ---------------

+ (SPLogger *) instance
{
    // Persistent instance.
    static SPLogger *_singleton = nil;
    if (_singleton != nil)
        return _singleton;
    // thread safe.
    @synchronized([SPLogger class]) {
        if (_singleton == nil)
            //allocates an instance if one doesn't exist.  this must be initialized to use. 
            _singleton = [SPLogger alloc]; 
        return _singleton;
    }
}

+ (id) init: (NSString *) thisURL
  authToken: (NSString *) thisAuthToken
  projectID: (NSString *) thisProjectID
uploadIntervalInEvents: (NSUInteger) maxEvents  
uploadIntervalInSecs:   (NSUInteger ) maxSecs
shouldLogSystemData:        (BOOL) logSys
shouldLogSystemEvents:      (BOOL) logEvents
shouldLogSynchronously:     (BOOL) synchronous 
{
    return [[SPLogger instance] init: thisURL   
                           authToken: thisAuthToken
                           projectID: thisProjectID
              uploadIntervalInEvents: maxEvents
                uploadIntervalInSecs: maxSecs
                 shouldLogSystemData: logSys
               shouldLogSystemEvents: logEvents
              shouldLogSynchronously: synchronous];
}


+ (id) initWithDefaults: (NSString *) thisURL 
              authToken: (NSString *) myAuthToken 
              projectID: (NSString *) thisProjectID 
{
    return [[SPLogger instance] init: thisURL   
                           authToken: myAuthToken
                           projectID: thisProjectID
              uploadIntervalInEvents: DEFAULT_MAX_EVENTS_BEFORE_FLUSH
                uploadIntervalInSecs: DEFAULT_MAX_SECS_BEFORE_FLUSH
                 shouldLogSystemData: DEFAULT_SHOULD_LOG_SYSTEM_DATA
               shouldLogSystemEvents: DEFAULT_SHOULD_LOG_SYSTEM_EVENTS
              shouldLogSynchronously: DEFAULT_SHOULD_LOG_SYNCHRONOUSLY];
}


// forward messages to writer
+ (void)track: (NSString*) event 
{
    [[SPLogger instance] track: event properties: nil timestamp: 0];
}

+ (void)track: (NSString*) event properties:(NSDictionary*) properties 
{
    [[SPLogger instance] track: event properties: properties timestamp: 0];
}

+ (void)track: (NSString*) event properties:(NSDictionary*) properties timestamp: (NSNumber*) timestamp 
{
    [[SPLogger instance] track:event properties:properties timestamp:timestamp];
}



//-----------------------------------------------------------------------
// INSTANCE METHODS
//-----------------------------------------------------------------------

- (id) init: (NSString *) thisURL
  authToken: (NSString *) thisAuthToken
  projectID: (NSString *) thisProjectID
uploadIntervalInEvents: (NSUInteger) maxEvents  
uploadIntervalInSecs:   (NSUInteger ) maxSecs
shouldLogSystemData:        (BOOL) logSys
shouldLogSystemEvents:      (BOOL) logEvents
shouldLogSynchronously:     (BOOL) synchronous 
{
    if (!(self = [super init]))
        return nil;
    
#warning dev: need to make proper use of urls
    
    if ([thisURL rangeOfString:@"storm"].location == NSNotFound)
        self.writer = [[SPLoggerStorm alloc] init: thisURL authToken:thisAuthToken projectID:thisProjectID];
    else // use storm url
        self.writer = [[SPLoggerStorm alloc] init: nil     authToken:thisAuthToken  projectID:thisProjectID];
    
    eventQueue = [[NSMutableArray alloc] init];
    metaProperties = [[NSMutableDictionary alloc] init];
    
    self.projectID        = thisProjectID;
    self.authToken        = thisAuthToken;
    self.uploadIntervalInEvents = maxEvents;
    self.uploadIntervalInSecs = maxSecs;
    self.logSysData       = logSys;
    self.logSysEvents     = logEvents;
    self.logSynchronously = synchronous;
    
    [SPLogger addSystemData: metaProperties];
    //[metaProperties setObject: [SPLogger appname]     forKey:SYS_APP_NAME_PROP];
    //[metaProperties setObject: [SPLogger networkInfo] forKey:SYS_NETWORKS_PROP];
    [self start];
    
    return self;
}

// forward messages to writer
- (void)track:(NSString*) event properties:(NSDictionary*) properties timestamp: (NSNumber*) timestamp 
{
    if (!writer) {
        [NSException raise:@"No log writer found" format:@"The logger must be properly initialized before making other calls."];
    }
    
    // make mutable copy to add values
    NSMutableDictionary *props = [properties mutableCopy];
    // if we're logging system info, add it to props
    if (self.logSysData) { 
        if (!props)
            props = [metaProperties mutableCopy];
        else 
            [props addEntriesFromDictionary:metaProperties];
    }
    // if no timestamp passed in, set timestamp to current time
    if (timestamp == 0) {
        NSTimeInterval secondsSinceUnixEpoch = [[NSDate date]timeIntervalSince1970];
        timestamp = [NSNumber numberWithDouble: secondsSinceUnixEpoch];
    }
    
    SPLoggerEvent *splEvent = [[SPLoggerEvent alloc] init:event properties: props timestamp: timestamp];
    // output for debugging
    NSLog(@"%@", splEvent);
    
    @synchronized(self.eventQueue) {
        [[self eventQueue] addObject:splEvent];
        // we keep at most N events.  if we have too many in memory or on disk, it means
        // we haven't been able to connect for a long time.  keep only the N most recent events.
        if (self.eventQueue.count > MAX_EVENTS_TO_RETAIN) {
            int countToDelete = self.eventQueue.count - MAX_EVENTS_TO_RETAIN;
            if (self.logSysEvents) {
                NSString *event = [NSString stringWithFormat:
                                  @"SYSTEM_NOTICE: Unable to flush events for too long.  Deleting oldest %d events.", 
                                  countToDelete];
                SPLoggerEvent *splEvent = [[SPLoggerEvent alloc] init:event properties: nil timestamp: timestamp];
                [[self eventQueue] addObject:splEvent];
            }
            [self.eventQueue removeObjectsInRange:NSMakeRange(0, countToDelete)];
        }
    }
}

// setup NSTimer to call flushEvents() every N seconds

- (void)setUploadIntervalInSecs:(NSUInteger) newMaxSecs {
    uploadIntervalInSecs = newMaxSecs;
    if (timer) {
        [timer invalidate];
        timer = nil;
    }
    [self flushEvents];
    
    timer = [NSTimer scheduledTimerWithTimeInterval:uploadIntervalInSecs target:self  selector:@selector(flushEvents) userInfo:nil repeats:YES];
    // prevents the ui from making the timer be laggy.
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
}



- (void)start {
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000		
    if ([[UIDevice currentDevice] respondsToSelector:@selector(isMultitaskingSupported)] && &UIBackgroundTaskInvalid) {
        
        //taskId = UIBackgroundTaskInvalid;
        if (&UIApplicationDidEnterBackgroundNotification) {
            [notificationCenter addObserver:self selector:@selector(enteringBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
        }
        if (&UIApplicationWillEnterForegroundNotification) {
            [notificationCenter addObserver:self selector:@selector(enteringForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
        }
    }
#endif
    [notificationCenter addObserver:self selector:@selector(enteringDeath:) name:UIApplicationWillTerminateNotification object:nil];
    
    [self loadEvents];
    [self setUploadIntervalInSecs:uploadIntervalInSecs];
}


/////////////////////////////////

- (void)enteringBackground:(NSNotificationCenter*) notification 
{
    [self saveEvents];
}

- (void)enteringForeground:(NSNotificationCenter*) notification 
{
    [self loadEvents];
    [self flushEvents];
}

- (void)enteringDeath:(NSNotification*) notification 
{
    [self saveEvents];
}

- (NSString*)eventFilePath  
{
    NSString *filename = [NSString stringWithFormat:@"SPLoggerSavedEvents_%@.plist", [SPLogger appname]];
    return [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:filename];
}

- (void) saveEvents 
{
    if (![NSKeyedArchiver archiveRootObject:[self eventQueue] toFile:[self eventFilePath]]) 
        NSLog(@"Unable to save event data!");
}

- (void)loadEvents 
{
    self.eventQueue = [NSKeyedUnarchiver unarchiveObjectWithFile:[self eventFilePath]];
    if (!self.eventQueue) {
        self.eventQueue = [NSMutableArray array];
        NSLog(@"Unable to load event data.");
    }
}

- (void)flushEvents 
{    
    @synchronized(self.eventQueue) {
        if (eventQueue.count == 0)
            return;
#warning TODO: consider making a new eventQueue object so track() does not have to wait for this flush            
        [writer flushEvents: eventQueue];
    }
}

- (void)stop 
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [timer invalidate];
    timer = nil;
    [self saveEvents];
}

- (void) dealloc 
{
    [self stop]; 
    self.authToken = nil;
    self.writer  = nil;
}


// STATIC UTILITY FUNCTIONS

+ (NSString*) appname
{
    // calc value once
    static NSString *name = nil;
    if (!name) {
        name = [[[NSBundle mainBundle] infoDictionary] objectForKey:(id)kCFBundleNameKey];
        // if CFBundleName is missing, use the bundle file name
        if (name == nil) 
            name = [[[NSBundle mainBundle] bundlePath] lastPathComponent];
    }
    return name;
}

+ (NSString*) networkInfo
{
    NSMutableDictionary *networks = [NSMutableDictionary dictionary];
    struct ifaddrs * addrs;
    if (getifaddrs(&addrs) == 0) {
        const struct ifaddrs *cursor = addrs;
        while (cursor != NULL) {
            if ( (cursor->ifa_addr->sa_family == AF_LINK) && (((const struct sockaddr_dl *)cursor->ifa_addr)->sdl_type == IFT_ETHER) ) {
                const struct sockaddr_dl *dlAddr = (const struct sockaddr_dl *)cursor->ifa_addr;
                const uint8_t *base = (const uint8_t *) &dlAddr->sdl_data[dlAddr->sdl_nlen];
                NSString *theKey = [NSString stringWithUTF8String:cursor->ifa_name];
                NSString *theValue = [NSString stringWithFormat:@"%02x:%02x:%02x:%02x:%02x:%02x", base[0], base[1], base[2], base[3], base[4], base[5]];
                [networks setObject:theValue forKey:theKey];
            }
            cursor = cursor->ifa_next;
        }
        freeifaddrs(addrs);
    }
    
    NSArray *keys = [networks allKeys];
    keys = [keys  sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    
    NSMutableString *string = [NSMutableString new];	
    for (NSString *key in keys) {
        if ([string length] > 0)
            [string appendString:@", "];
        [string appendString:[networks objectForKey:key]];
    }
    return string;
}


+ (void) addSystemData:(NSMutableDictionary *)props
{
    // get machine info
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char *answer = malloc(size);
    sysctlbyname("hw.machine", answer, &size, NULL, 0);
    NSString *tmpval = [NSString stringWithCString:answer encoding: NSUTF8StringEncoding];
    [props setObject:tmpval forKey:SYS_MACHINE_PROP];
    free(answer);
    
    // get model info
    sysctlbyname("hw.model", NULL, &size, NULL, 0);
    answer = malloc(size);
    sysctlbyname("hw.model", answer, &size, NULL, 0);
    tmpval = [NSString stringWithCString:answer encoding: NSUTF8StringEncoding];
    [props setObject:tmpval forKey:SYS_MODEL_PROP];
    free(answer);
    
    // TOO BORING USUALLY
    if (NO) {
        // total and free disk space
        NSDictionary *fattributes = [[NSFileManager defaultManager] attributesOfFileSystemForPath:NSHomeDirectory() error:nil];
        tmpval = [NSString stringWithFormat:@"%d", [fattributes objectForKey:NSFileSystemSize]];
        [props setObject: tmpval forKey:SYS_DISK_SPACE_PROP];
        tmpval =  [NSString stringWithFormat:@"%d", [fattributes objectForKey:NSFileSystemFreeSize]]; 
        [props setObject: tmpval forKey:SYS_FREE_DISK_SPACE_PROP];
    }
    // DISALLOWED BY APPLE
    // get serial number
    //    io_registry_entry_t rootEntry = IORegistryEntryFromPath( kIOMasterPortDefault, "IOService:/" );
    //                                    IOServiceMatching("IOPlatformExpertDevice"));
    //    CFTypeRef serialAsCFString = IORegistryEntryCreateCFProperty( rootEntry,CFSTR(kIOPlatformSerialNumberKey), kCFAllocatorDefault, 0);
    //    IOObjectRelease(rootEntry);
    //    tmpval = (NULL != serialAsCFString) ? [[NSString alloc] initWithFormat:@"%@", serialAsCFString] : @"Unknown";
    //        
    //    [props setObject: tmpval forKey:@"sys_serial_number"]; 
}




@end
