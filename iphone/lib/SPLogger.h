//
//  Created by David Carasso on 7/9/12.
//  Copyright (c) 2012 Splunk. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SPLoggerWriter.h"

@interface SPLogger : NSObject {
  NSTimer *timer;
}

@property(nonatomic, retain) id <SPLoggerWriter> writer;
@property(nonatomic, retain) NSMutableArray *eventQueue;
@property(nonatomic, retain) NSMutableDictionary *metaProperties;
@property(nonatomic, retain) NSString *authToken;
@property(nonatomic, retain) NSString *projectID;
@property(nonatomic, assign) NSUInteger uploadIntervalInEvents;
@property(nonatomic, assign) NSUInteger uploadIntervalInSecs;
@property(nonatomic, assign) BOOL logSysData;
@property(nonatomic, assign) BOOL logSysEvents;
@property(nonatomic, assign) BOOL logSynchronously;


// METHODS THAT OPERATE ON THE SINGLETON
+ (id) initWithDefaults: (NSString *) thisURL
              authToken: (NSString *) authToken
              projectID: (NSString *) projectID;

+ (id) init: (NSString *) thisURL
  authToken: (NSString *) authToken
  projectID: (NSString *) projectID
uploadIntervalInEvents: (NSUInteger) maxEvents  
uploadIntervalInSecs:   (NSUInteger ) maxSecs
shouldLogSystemData:    (BOOL) logSys
shouldLogSystemEvents:  (BOOL) logEvents
shouldLogSynchronously: (BOOL) synchronous;

+ (void) track:(NSString*) event;
+ (void) track:(NSString*) event properties:(NSDictionary*) properties;
+ (void) track:(NSString*) event properties:(NSDictionary*) properties timestamp: (NSNumber*) timestamp ;


// IF YOU NEED ACCESS DIRECTLY FOR THE SINGLETON TO PERFORM UNCOMMON FUNCTIONS BELOW 
+ (SPLogger *) instance;



// INSTANCE METHODS

- (id) init: (NSString *) thisURL
  authToken: (NSString *) authToken
  projectID: (NSString *) projectID
  uploadIntervalInEvents: (NSUInteger) maxEvents  
  uploadIntervalInSecs:   (NSUInteger ) maxSecs
  shouldLogSystemData:    (BOOL) logSys
  shouldLogSystemEvents:  (BOOL) logEvents
  shouldLogSynchronously: (BOOL) synchronous;

- (void) track:(NSString*) event properties:(NSDictionary*) properties timestamp: (NSNumber*) timestamp ;

- (void) enteringBackground:(NSNotificationCenter*) notification; 
- (void) enteringForeground:(NSNotificationCenter*) notification;
- (void) enteringDeath:(NSNotification*) notification;
- (void) saveEvents;
- (void) loadEvents;
- (void) flushEvents; 
- (void) start;
- (void) stop;

// UTILITY FUNCTIONS
+ (void) addSystemData:(NSMutableDictionary *)props;
+ (NSString*) appname;
+ (NSString*) networkInfo;

@end
