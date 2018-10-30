//
//  EVTEventStateProvider.m
//  Apple Events
//
//  Created by Guilherme Rambo on 05/09/16.
//  Copyright © 2016 Guilherme Rambo. All rights reserved.
//

#import "EVTEventStateProvider.h"

#import "EVTEnvironment.h"

@interface EVTEventStateProvider ()

@property (nonatomic, strong) EVTEnvironment *environment;
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, assign) EVTEventState state;
@property (nonatomic, copy) NSURL *url;

@end

@implementation EVTEventStateProvider

- (instancetype)initWithEnvironment:(EVTEnvironment *)environment
{
    self = [super init];
    
    _state = EVTEventStateUnknown;
    _environment = environment;
    _session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]];
    
    [self __startMonitoring];
    
    return self;
}

- (void)__fetchStateWithCompletionHandler:(void (^)(NSString *, NSString *))completionHandler
{
    NSURLSessionDataTask *task = [self.session dataTaskWithURL:self.environment.stateURL completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            NSLog(@"Event state check error: %@", error);
            return;
        }
        if (!data) {
            NSLog(@"Event state check returned empty data");
            return;
        }
        
        NSError *jsonError;
        NSDictionary *stateDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        if (jsonError) {
            NSLog(@"Error parsing json from state %@", jsonError);
            return;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler(stateDict[@"state"], stateDict[@"url"]);
        });
    }];
    [task resume];
}

- (void)__startMonitoring
{
    self.timer = [NSTimer scheduledTimerWithTimeInterval:self.environment.stateCheckInterval target:self selector:@selector(__stateCheck:) userInfo:nil repeats:YES];
    [self.timer fire];
}

- (void)__stateCheck:(NSTimer *)sender
{
    __weak typeof(self) weakSelf = self;

    [self __fetchStateWithCompletionHandler:^(NSString *stateName, NSString *url) {
        #ifdef DEBUG
            NSLog(@"STATE = %@", stateName);
        #endif
        [self willChangeValueForKey:@"state"];
        if ([stateName isEqualToString:@"PRE"]) {
            weakSelf.state = EVTEventStatePre;
        } else if ([stateName isEqualToString:@"LIVE"]) {
            weakSelf.url = [NSURL URLWithString:url];
            weakSelf.state = EVTEventStateLive;
        } else if ([stateName isEqualToString:@"INTERIM"]) {
            weakSelf.state = EVTEventStateInterim;
        } else if ([stateName isEqualToString:@"POST"]) {
            weakSelf.state = EVTEventStatePost;
        } else {
            NSLog(@"Unknown event state: %@", stateName);
        }
        
        [self didChangeValueForKey:@"state"];
    }];
}

@end
