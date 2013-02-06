//
//  Created by David Carasso on 7/9/12.
//  Copyright (c) 2012 Splunk. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol SPLoggerWriter <NSObject>

- (id) init: (NSString *) url 
  authToken: (NSString *) authToken 
  projectID: (NSString *) project_id;

- (BOOL) flushEvents: (NSMutableArray *)eventQueue;

// dealloc should close it

@end
