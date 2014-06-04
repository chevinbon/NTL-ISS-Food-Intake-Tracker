// Copyright (c) 2013 TopCoder. All rights reserved.

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0

// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
//
//  AppDelegate.m
//  FoodIntakeTracker
//
//  Created by lofzcx 06/12/2013
//
//  Updated by pvmagacho on 05/07/2014
//  F2Finish - NASA iPad App Updates
//

#import "AppDelegate.h"
#import "LockServiceImpl.h"
#import "UserServiceImpl.h"
#import "FoodProductServiceImpl.h"
#import "SpeechRecognitionServiceImpl.h"
#import "FoodConsumptionRecordServiceImpl.h"
#import "SynchronizationServiceImpl.h"
#import "DataUpdateServiceImpl.h"
#import "DataHelper.h"
#import "DBHelper.h"
#import "Settings.h"
#import "Helper.h"
#import "LoggingHelper.h"

typedef NS_ENUM(NSInteger, SyncStatus) {
    SyncStatusNone,
    
    SyncStatusStarted,
    SyncStatusFinished,
    SyncStatusError
} NS_ENUM_AVAILABLE_IOS(7_0);

/**
 * the application delegate
 *
 * @author lofzcx
 * @version 1.0
 */
@implementation AppDelegate {
    /*! Indicates whether the data loading is done. */
    BOOL loadingFinished;
    /*! Synchronization status */
    SyncStatus status;
    /*! Dispatch queues */
    dispatch_queue_t dataSyncUpdateQ;
}

@synthesize tabBarViewController;
@synthesize mediaFiles;

- (TouchWindow *)window
{
    static TouchWindow *customWindow = nil;
    if (!customWindow) customWindow = [[TouchWindow alloc] init];
    
    CGFloat systemVersion = [[[UIDevice currentDevice] systemVersion] floatValue];
    if(systemVersion < 7) {
        customWindow.frame = [[UIScreen mainScreen] bounds];
    }
    else {
        CGRect bounds = [[UIScreen mainScreen] bounds];
        CGFloat diff = 20;
        customWindow.frame = CGRectMake(bounds.origin.x, bounds.origin.y + diff, bounds.size.width, bounds.size.height - diff);
        customWindow.bounds = CGRectMake(bounds.origin.x, bounds.origin.y, bounds.size.width, bounds.size.height - diff);
        customWindow.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    }
    
    return customWindow;
}

/**
 * following delegate methods is application delegate, overwrite to define action for application loaded, ended,
 * entering background, become active. For this assembly just leave these empty.
 *
 */

/*!
 * This method tells the delegate that the launch process is almost done and the app is almost ready to run.
 * @param application the delegating application object
 * @param launchOptions the launch options
 * @return NO if the application cannot handle the URL resource, otherwise return YES.
 The return value is ignored if the application is launched as a result of a remote notification.
 */
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
     status = SyncStatusNone;
     dataSyncUpdateQ = dispatch_queue_create("Data Sync Update", NULL);

    self.mediaFiles = [[NSUserDefaults standardUserDefaults] objectForKey:@"MediaFilesArray"];
    //http://stackoverflow.com/questions/17678881/how-to-change-status-bar-text-color-in-ios-7
    [application setStatusBarStyle:UIStatusBarStyleLightContent];
    
    // Load configurations and create services
    NSString *configBundle = [[NSBundle mainBundle] pathForResource:@"Configuration" ofType:@"plist"];
    if (configBundle) {
        self.configuration = [NSDictionary dictionaryWithContentsOfFile:configBundle];
        
        
        self.shouldAutoLogout = NO;
        loadingFinished = NO;
        
        
        
        self.lockService = [[LockServiceImpl alloc] initWithConfiguration:self.configuration];
        self.userService = [[UserServiceImpl alloc] initWithConfiguration:self.configuration
                                                              lockService:self.lockService];
        self.foodProductService = [[FoodProductServiceImpl alloc] init];
        self.speechRecognitionService =
        [[SpeechRecognitionServiceImpl alloc] initWithConfiguration:self.configuration];
        self.foodConsumptionRecordService =
        [[FoodConsumptionRecordServiceImpl alloc] initWithConfiguration:self.configuration];
        self.synchronizationService =
        [[SynchronizationServiceImpl alloc] initWithConfiguration:self.configuration];
        self.dataUpdateService =
        [[DataUpdateServiceImpl alloc] initWithConfiguration:self.configuration];
        self.additionalFilesDirectory = [self.configuration valueForKey:@"LocalFileSystemDirectory"];
        self.tesseractDataPath = [self.configuration valueForKey:@"TesseractDataPath"];
        self.helpData = [self.configuration objectForKey:@"HelpData"];
        self.summaryGenerationFrequency = [self.configuration objectForKey:@"SummaryGenerationFrequency"];
        
        [self performSelector:@selector(initialLoad) withObject:nil afterDelay:0.1];
        
        // Start timers
        self.heartbeatTimer =
        [NSTimer scheduledTimerWithTimeInterval:
         [[self.configuration valueForKey:@"HeartbeatInterval"] intValue]
                                         target:self
                                       selector:@selector(sendHeartbeat)
                                       userInfo:nil
                                        repeats:YES];
        /*self.summaryGenerationTimer =
        [NSTimer scheduledTimerWithTimeInterval:
         [[self.configuration valueForKey:@"SummaryGenerationInterval"] intValue]
                                         target:self
                                       selector:@selector(generateSummary)
                                       userInfo:nil
                                        repeats:NO];
        self.dataSyncUpdateTimer =
        [NSTimer scheduledTimerWithTimeInterval:
         [[self.configuration valueForKey:@"DataSyncUpdateInterval"] intValue]
                                         target:self
                                       selector:@selector(doSyncUpdate)
                                       userInfo:nil
                                        repeats:YES];*/
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(doSyncUpdate:)
                                                     name:@"DataSyncUpdateInterval" object:nil];        
        return YES;
    } else {
        return NO;
    }
    
    // Override point for customization after application launch.
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of
    // temporary interruptions (such as an incoming phone call or SMS message) or
    // when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates.
    // Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application
    // state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of
    // applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state;
    // here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive.
    // If the application was previously in the background, optionally refresh the user interface.
    if (status == SyncStatusError && !loadingFinished) {
        [self initialLoad];
    }
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate.
    // See also applicationDidEnterBackground:.
    dispatch_release(dataSyncUpdateQ);
}

+ (AppDelegate *) shareDelegate {
    return (AppDelegate *)[[UIApplication sharedApplication] delegate];
}
/*!
 * This method will check if lock can be acquired.
 * @param action the action requested
 * @param sender the sender
 * @return whether the action can be performed
 */
- (BOOL) canPerformAction:(SEL)action withSender:(id)sender {
    if (YES) {
        if (!self.loggedInUser) return YES;
        else return NO;
    } else {
        if (self.loggedInUser) {
            // The error object
            NSError *error;
            // Acquire lock
            [self.lockService acquireLock:self.loggedInUser error:&error];
            if (error) {
                return NO;
            } else {
                return YES;
            }
        } else {
            return NO;
        }
    }
}

/*!
 * This method will send heartbeat if the user is logged in.
 */
- (void) sendHeartbeat {
    if (self.loggedInUser) {
        dispatch_queue_t heartBeatQ = dispatch_queue_create("Send Heart Beat", NULL);
        dispatch_async(heartBeatQ, ^{
            @autoreleasepool {
                //We do not use lock anymore
                //[self.lockService sendLockHeartbeat:self.loggedInUser error:nil];
            }
        });
        dispatch_release(heartBeatQ);
    }
}

/*!
 * This method will generate food consumption summary.
 */
- (void) generateSummary:(NSDate *) date {
    dispatch_async(dataSyncUpdateQ, ^{
        @autoreleasepool {
            NSDate *now = [NSDate date];
            NSLog(@"Start summary at   : %@", now);
            
            NSError *error = nil;
            NSCalendar *calendar = [NSCalendar currentCalendar];
            [calendar setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"GMT"]];
            
            NSDate *startDate;
            NSDate *endDate;
            if ([self.summaryGenerationFrequency isEqualToString:@"Weekly"]) {
                // Start date should be first day of last week, end date should be last day of last week.
                NSDateComponents *components = [calendar components:NSYearCalendarUnit|
                                                NSMonthCalendarUnit|NSWeekdayCalendarUnit
                                                           fromDate:date];
                components.weekday = 1;
                components.hour = 0;
                components.minute = 0;
                components.second = 0;
                startDate = [calendar dateFromComponents:components];
                
                components.weekday = 7;
                components.hour = 23;
                components.minute = 59;
                components.second = 59;
                endDate = [calendar dateFromComponents:components];
            } else if ([self.summaryGenerationFrequency isEqualToString:@"Daily"]) {
                NSDateComponents *components = [calendar components:NSYearCalendarUnit|NSMonthCalendarUnit|
                                                NSDayCalendarUnit
                                                           fromDate:date];
                components.hour = 0;
                components.minute = 0;
                components.second = 0;
                startDate = [calendar dateFromComponents:components];
                
                components.hour = 23;
                components.minute = 59;
                components.second = 59;
                endDate = [calendar dateFromComponents:components];
            } else {
                // Monthly
                // Similarly, start date should be first day of last month, end date should be last day of last month
                NSDateComponents *components = [calendar components:NSYearCalendarUnit|
                                                NSMonthCalendarUnit
                                                           fromDate:date];
                components.day = 1;
                components.hour = 0;
                components.minute = 0;
                components.second = 0;
                startDate = [calendar dateFromComponents:components];
                
                NSRange days = [calendar rangeOfUnit:NSDayCalendarUnit
                                              inUnit:NSMonthCalendarUnit
                                             forDate:date];
                components.day = days.length;
                components.hour = 23;
                components.minute = 59;
                components.second = 59;
                endDate = [calendar dateFromComponents:components];
            }
            
            [self.foodConsumptionRecordService generateSummary:self.loggedInUser
                                                     startDate:startDate
                                                       endDate:endDate
                                                         error:&error];
            
            NSLog(@"Finished summary at: %@", now);
        }
    });
}

/*!
 * This method will generate a full food consumption summary.
 */
- (void) generateFullSummary {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"FullSummaryReady"]) {
        return;
    }
    
    dispatch_async(dataSyncUpdateQ, ^{
        @autoreleasepool {
            NSError *error = nil;
            NSArray *users = [self.userService filterUsers:@"" error:&error];
            
            for (User *user in users) {
                [self.foodConsumptionRecordService generateSummary:user
                                                         startDate:[NSDate dateWithTimeIntervalSince1970:0]
                                                           endDate:[NSDate date]
                                                             error:&error];
                if (error) {
                    [LoggingHelper logError:@"generateFullSummary" error:error];
                    return;
                }
            }
            
            [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"FullSummaryReady"];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
    });
}

/*!
 * This method will do data sync/update.
 */
- (void) doSyncUpdate:(NSNotification *) notif {
    // Skip the sync/update if the initial load is still in progress.
    if (loadingFinished) {
        dispatch_async(dataSyncUpdateQ, ^{
            @autoreleasepool {
                NSDate *now = [NSDate date];
                NSLog(@"Start sync at   : %@", now);
                NSError *error = nil;
                [self.dataUpdateService update:&error];
                if (!error) {
                    [self.synchronizationService synchronize:&error];
                }
                
                [[NSUserDefaults standardUserDefaults] setObject:self.mediaFiles forKey:@"MediaFilesArray"];
                [[NSUserDefaults standardUserDefaults] synchronize];
                
                NSLog(@"Finished sync at: %@", now);
            }
        });
        
        [self generateSummary:notif.object];
    }
}

#pragma mark - Test Code

// Check if the app is started for the first time. If so, do some initializations.
- (void) initialLoad {
    status = SyncStatusStarted;
    
    if (self.mediaFiles && [[NSUserDefaults standardUserDefaults] boolForKey:@"HasLaunchedOnce"]) {
        loadingFinished = YES;
        NSDictionary *loadingEndParam = @{@"success": [NSNumber numberWithBool:YES]};
        [[NSNotificationCenter defaultCenter] postNotificationName:InitialLoadingEndEvent
                                                            object:loadingEndParam];
        
        status = SyncStatusFinished;
        
        [self generateFullSummary];
        
        return;
    }
    
    if (!self.mediaFiles) {
        self.mediaFiles = [NSMutableArray array];
    }
    
    NSArray *searchPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *source = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"samba"];
    NSString *destination = [[searchPaths objectAtIndex:0] stringByAppendingPathComponent:@"samba"];
    
    NSError *error = nil;
    if ([[NSFileManager defaultManager] fileExistsAtPath:destination]) {
        [[NSFileManager defaultManager] removeItemAtPath:destination error:&error];
    }
    
    [[NSFileManager defaultManager] copyItemAtPath:source toPath:destination error:&error];
    if (error) {
        [LoggingHelper logError:@"initialLoad" error:error];
        
        status = SyncStatusError;
        
        NSDictionary *loadingEndParam = @{@"success": @NO};
        [[NSNotificationCenter defaultCenter] postNotificationName:InitialLoadingEndEvent
                                                            object:loadingEndParam];
        return;
    }
    
    loadingFinished = NO;
    __block BOOL syncSuccessful = YES;
    [[NSNotificationCenter defaultCenter] postNotificationName:InitialLoadingBeginEvent object:nil];
    
    dispatch_queue_t initialLoadQ = dispatch_queue_create("InitialLoad", NULL);
    dispatch_async(initialLoadQ, ^{
        @autoreleasepool {
            NSLog(@"Initial load at   : %@", [NSDate date]);
            
            NSError *error = nil;
            syncSuccessful = [self.dataUpdateService update:&error force:YES];
            [LoggingHelper logError:@"initialLoad" error:error];
            if (syncSuccessful) {
                syncSuccessful = [self.synchronizationService synchronize:&error];
                [LoggingHelper logError:@"initialLoad" error:error];
                
                if (syncSuccessful) {
                    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"HasLaunchedOnce"];
                    [[NSUserDefaults standardUserDefaults] synchronize];
                    
                    [self generateFullSummary];
                }
            }
            
            [[NSUserDefaults standardUserDefaults] setObject:self.mediaFiles forKey:@"MediaFilesArray"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                loadingFinished = syncSuccessful;
                NSDictionary *loadingEndParam = @{@"success": [NSNumber numberWithBool:syncSuccessful]};
                [[NSNotificationCenter defaultCenter] postNotificationName:InitialLoadingEndEvent
                                                                    object:loadingEndParam];

                status = syncSuccessful ? SyncStatusFinished : SyncStatusError;
            });
        }
    });
    dispatch_release(initialLoadQ);
}

@end
