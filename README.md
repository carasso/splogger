splogger
========

Splunk Mobile Logging API

The following notes related to the iOS (iPhone) version.


# Release notes #


# Logging data on handheld devices #

If you want to log events, such as track system or user behavior in
your iOS application, start by downloading the SPLogger API from
github. Currently the system logs to Splunk's cloud product, Storm
(www.splunkstorm.com). 

   ## TODO: instructions on downloading

The directory has two folders:

1) lib --  the source code for the SPLogger API
2) sample_app -- a small sample iPhone app that asks for a user's name
   and has a button that logs an event.


# Initializing SPLogger #

Before you do any logging to Splunk, you'll need to initialize the
SPLogger object.  This initialization can be done in applicationDidFinishLaunching:
of application:didFinishLaunchingWithOptions in your Application delegate.  In the
sample_app, we this in done in viewDidLoad() in DCViewController.m, with the 
following code:
 
    [SPLogger                init:@"storm" 
                        authToken:@"IL8Yx-JNKYak6oyTBuGX1vCfyAU7TsU6svfwnzQVTHw5gfRysmbV0l1UUNkIk33g9aWZ_tJUBIN="
                        projectID:@"4ce5c2e7bfb211e0b75b12313b9c248a"
           uploadIntervalInEvents:2 
             uploadIntervalInSecs:5 
              shouldLogSystemData:YES 
            shouldLogSystemEvents:NO 
           shouldLogSynchronously:YES];

The included authToken and projectID are invalid and you'll need to get your own proper values at splunkstorm.com.




# Logging Events #
After initializing the SPLogger object, you are ready to log events. To log simple strings, try examples such as:

    [SPLogger track: @"My Message"];
    [SPLogger track: [[NSString alloc] initWithFormat: @"USER %@ PUSHED BUTTON", nameString]];

If you want to add properties to the event or specify an alternative timestamp, try:

   + (void) track:(NSString*) event properties:(NSDictionary*) properties;
   + (void) track:(NSString*) event properties:(NSDictionary*) properties timestamp: (NSNumber*) timestamp ;


# Using Storm for Analytics

All your events are uploaded to splunkstorm.com on a regular interval,
depending on how your initialzed SPLogger.  In the above code, events
are uploaded every 5 seconds, which is rather aggressive but useful
for testing.

Your events in Splunk always have a few common properties: source,
sourcetype, and host.  

1) The "source" value will be the name of your application, and in the
   case of the sample_app will be "helloworld".

2) The "sourcetype" value will always be "splogger".

3) The "host" value will be the concatenated MAC addresses of the
   mobile device's networks (e.g., "3c:07:54:79:a6:e2,
   68:a8:6d:4a:08:72, 0a:a8:6d:4a:08:72")

The SPLogger initializer API has the option (set to YES above) to log
system data, and if YES, will add additional system properties to your
events, such as sys_machine="x86_64" sys_model="MacBookPro8,1".

This is not the place to learn Splunk Search Processing Language
(SPL), but the following example searches will give you a basic idea
of some of the power available with easy:

Show the top 10 users of my apps:  

     sourcetype=splogger | top 10 host

Show the top 5 hardware types:

     sourcetype=splogger | top 5 sys_machine, sys_model

Of the users on level 5 of my game, what is the rate of success or failure (assumes I logged with an property called 'success'):

     sourcetype=splogger level=5 | stats count by success:

Show a chart of usage by time, broken up by each of my apps:

     sourcetype=splogger | timechart count by source

How long do users typical use my apps, assuming a 5 minute pause means the user is done

     sourcetype=splogger | transaction host maxpause=5m | stats min(duration), max(duration), avg(duration)
