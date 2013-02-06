//
//  DCViewController.m
//  helloworld
//
//  Created by David Carasso on 7/12/12.
//  Copyright (c) 2012 Splunk. All rights reserved.
//

#import "DCViewController.h"
#import "SPLogger.h"

@interface DCViewController ()

@end

@implementation DCViewController
@synthesize textField;
@synthesize label;
@synthesize userName = _userName;

//static id logger = nil;

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.

# warning YOU NEED TO CHANGE THE AUTHTOKEN AND PROJECTID TO YOUR OWN VALUES.  THE BELOW VALUES ARE INVALID AND FOR DEMONSTATION PURPOSES
    [SPLogger                init:@"storm" 
                        authToken:@"IL8yx-JNKyak5oyUBuGX0vCfyAU9TsU7svfwnzqVTHw5gfRYsmb00l4UUNkIk13g9aWZ_tJUBIM="
                        projectID:@"4ce5c2e8bfb221e0b65b22314b0c248a"
           uploadIntervalInEvents:2 
             uploadIntervalInSecs:5 
              shouldLogSystemData:YES 
            shouldLogSystemEvents:NO 
           shouldLogSynchronously:YES];

    [SPLogger track: @"LOADED VIEW"];

}

- (void)viewDidUnload
{
    [SPLogger track: @"UNLOADED VIEW"];
    [self setTextField:nil];
    [self setLabel:nil];
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
    } else {
        return YES;
    }
}

- (IBAction)changeGreeting:(id)sender {
    self.userName = self.textField.text;
    NSString *nameString = self.userName;
    if ([nameString length] == 0) {
        nameString = @"Hello World";
    }
    NSString *greeting = [[NSString alloc] initWithFormat:@"Hello, %@!", nameString];
    self.label.text = greeting;

    [SPLogger track: [[NSString alloc] initWithFormat: @"USER %@ PUSHED BUTTON", nameString]];
}


- (BOOL) textFieldShouldReturn:(UITextField *)theTextField {
    if (theTextField == self.textField) {
        [theTextField resignFirstResponder];
        [SPLogger track: @"USER HIT RETURN BUTTON"];

    }
    return YES;
}

@end
