//
//  DCViewController.h
//  helloworld
//
//  Created by David Carasso on 7/12/12.
//  Copyright (c) 2012 Splunk. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DCViewController : UIViewController <UITextFieldDelegate>
@property (weak, nonatomic) IBOutlet UITextField *textField;
@property (weak, nonatomic) IBOutlet UILabel *label;

- (IBAction)changeGreeting:(id)sender;

@property (copy, nonatomic) NSString *userName;

@end
