//
//  AWSPushManager.m
//
// Copyright 2017 Amazon.com, Inc. or its affiliates (Amazon). All Rights Reserved.
//
// Code generated by AWS Mobile Hub. Amazon gives unlimited permission to
// copy, distribute and modify it.
//
#import "AWSPushManager.h"
#import <AWSSNS/AWSSNS.h>

NSString *const AWSPushManagerErrorDomain = @"com.amazonaws.PushManager.ErrorDomain";

NSString *const AWSPushManagerUserDefaultsIsEnabledKey = @"com.amazonaws.PushManager.IsEnabled";
NSString *const AWSPushManagerUserDefaultsEnabledTopicARNsKey = @"com.amazonaws.PushManager.EnabledTopicARNs";
NSString *const AWSPushManagerUserDefaultsDeviceTokenKey = @"com.amazonaws.PushManager.DeviceToken";
NSString *const AWSPushManagerUserDefaultsEndpointARNKey = @"com.amazonaws.PushManager.EndpointARN";
NSString *const AWSPushManagerUserDefaultsPlatformARNKey = @"com.amazonaws.PushManager.PlatformARN";


@interface AWSPushManager()

@property (nonatomic, strong) NSMutableArray *topics;
@property (nonatomic, strong) NSArray<NSString *> *topicARNs;
@property (nonatomic, strong) NSString *platformARN;
@property (nonatomic, strong) AWSPushManagerConfiguration *pushManagerConfiguration;
@property (nonatomic, strong) AWSSNS *sns;

@end

@interface AWSPushTopic()

@property (nonatomic, strong) NSString *subscriptionARN;
@property (nonatomic, strong) AWSPushManager *pushManager;

@end

@interface AWSSNS()

- (instancetype)initWithConfiguration:(AWSServiceConfiguration *)configuration;

@end

@implementation AWSPushManager

static AWSSynchronizedMutableDictionary *_serviceClients = nil;
static NSString *const AWSInfoPushManager = @"PushManager";
static NSString *const AWSPushApplicationARN = @"SNSPlatformApplicationARN";
static NSString *const AWSPushTopics = @"SNSConfiguredTopics";

+ (instancetype)defaultPushManager {
    static AWSPushManager *_defaultPushManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        AWSServiceConfiguration *serviceConfiguration = nil;
        AWSServiceInfo *serviceInfo = [[AWSInfo defaultAWSInfo] defaultServiceInfo:AWSInfoPushManager];
        if (serviceInfo) {
            serviceConfiguration = [[AWSServiceConfiguration alloc] initWithRegion:serviceInfo.region
                                                               credentialsProvider:serviceInfo.cognitoCredentialsProvider];
        }

        if (!serviceConfiguration) {
            serviceConfiguration = [AWSServiceManager defaultServiceManager].defaultServiceConfiguration;
        }

        NSString *snsPlatformARN = [serviceInfo.infoDictionary objectForKey:AWSPushApplicationARN];
        NSArray<NSString *> *topicARNs = [serviceInfo.infoDictionary objectForKey:AWSPushTopics];

        if (!snsPlatformARN || !serviceConfiguration) {
            @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                           reason:@"The Push Manager specific configuration is set incorrectly in the `Info.plist` file. You need to configure `Info.plist` before using this method."
                                         userInfo:nil];
        }

        AWSPushManagerConfiguration *pushManagerConfiguration = [[AWSPushManagerConfiguration alloc] initWithPlatformARN:snsPlatformARN
                                                                                                               topicARNs:topicARNs
                                                                                                    serviceConfiguration:serviceConfiguration];
        _defaultPushManager = [[AWSPushManager alloc] initWithConfiguration:pushManagerConfiguration];
    });

    return _defaultPushManager;
}

+ (void)registerPushManagerWithConfiguration:(AWSPushManagerConfiguration *)pushManagerConfiguration
                                      forKey:(nonnull NSString *)key {
    if ([key isEqualToString:AWSInfoDefault]) {
        @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                       reason:@"The key used for registering this instance is a reserved key. Please use some other key to register the instance."
                                     userInfo:nil];
    }
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _serviceClients = [AWSSynchronizedMutableDictionary new];
    });
    
    [_serviceClients setObject:[[AWSPushManager alloc] initWithConfiguration:pushManagerConfiguration]
                        forKey:key];
}

+ (instancetype)PushManagerForKey:(NSString *)key {
    AWSPushManager *serviceClient = [_serviceClients objectForKey:key];
    if (serviceClient) {
        return serviceClient;
    }
    
    AWSServiceInfo *serviceInfo = [[AWSInfo defaultAWSInfo] serviceInfo:AWSInfoPushManager
                                                                 forKey:key];
    if (serviceInfo) {
        AWSServiceConfiguration *serviceConfiguration = [[AWSServiceConfiguration alloc] initWithRegion:serviceInfo.region
                                                                                    credentialsProvider:serviceInfo.cognitoCredentialsProvider];
        
        NSString *snsPlatformARN = [serviceInfo.infoDictionary objectForKey:AWSPushApplicationARN];
        NSArray<NSString *> *topicARNs = [serviceInfo.infoDictionary objectForKey:AWSPushTopics];
        
        if (!snsPlatformARN || !serviceConfiguration) {
            @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                           reason:@"The Push Manager specific configuration is set incorrectly in the `Info.plist` file. You need to configure `Info.plist` before using this method."
                                         userInfo:nil];
        }
        
        AWSPushManagerConfiguration *pushManagerConfiguration = [[AWSPushManagerConfiguration alloc] initWithPlatformARN:snsPlatformARN
                                                                                                               topicARNs:topicARNs
                                                                                                    serviceConfiguration:serviceConfiguration];
        
        [AWSPushManager registerPushManagerWithConfiguration:pushManagerConfiguration
                                                      forKey:key];
    }
    return [_serviceClients objectForKey:key];
}

+ (void)removePushManagerForKey:(NSString *)key {
    [_serviceClients removeObjectForKey:key];
}

- (instancetype)initWithConfiguration:(AWSPushManagerConfiguration *)configuration {
    if (self = [super init]) {
        _sns = [[AWSSNS alloc] initWithConfiguration:configuration.serviceConfiguration];
        _pushManagerConfiguration = configuration;
        
        NSString *previousPlatformAppArn = [[NSUserDefaults standardUserDefaults] stringForKey: AWSPushManagerUserDefaultsPlatformARNKey];
        
        if (previousPlatformAppArn
            && ![previousPlatformAppArn isEqualToString:_pushManagerConfiguration.platformARN]) {
            AWSLogDebug(@"Application ran previously with this ARN: [%@].  New ARN: [%@]", previousPlatformAppArn, _pushManagerConfiguration.platformARN);
            [self setDeviceToken:nil];
            [self setEndpointARN:nil];
            [self setEnabled:NO];
            [self setPlatformARN:nil];
            
            [self registerForPushNotifications];
        }
    }
    return self;
}

- (void)registerTopicARNs:(NSArray *)topicARNs {
    NSMutableArray *topics = [NSMutableArray new];
    for (NSString *topicARN in topicARNs) {
        // Allocating and initializing the topic object does not automatically subscribe the device to the topic.
        // See the subscribe method for details on subscribing.
        AWSPushTopic *topic = [[AWSPushTopic alloc] initWithTopicARN:topicARN
                                                         pushManager:self];
        [topics addObject:topic];
    }
    self.topics = topics;
}

- (AWSPushTopic *)topicForTopicARN:(NSString *)topicARN {
    NSUInteger index = [self.topics indexOfObjectPassingTest:^BOOL(AWSPushTopic *obj, NSUInteger idx, BOOL *stop) {
        BOOL didPass = [obj.topicARN isEqualToString:topicARN];
        if (didPass) {
            *stop = didPass;
        }
        return didPass;
    }];
    return self.topics[index];
}

#pragma mark - Properties

- (BOOL)isEnabled {
    return [[NSUserDefaults standardUserDefaults] boolForKey:AWSPushManagerUserDefaultsIsEnabledKey];
}

- (void)setEnabled:(BOOL)enabled {
    [[NSUserDefaults standardUserDefaults] setBool:enabled
                                            forKey:AWSPushManagerUserDefaultsIsEnabledKey];
}

- (NSString *)deviceToken {
    return [[NSUserDefaults standardUserDefaults] stringForKey:AWSPushManagerUserDefaultsDeviceTokenKey];
}

- (void)setDeviceToken:(NSString *)deviceToken {
    [[NSUserDefaults standardUserDefaults] setObject:deviceToken
                                              forKey:AWSPushManagerUserDefaultsDeviceTokenKey];
}

- (NSString *)endpointARN {
    return [[NSUserDefaults standardUserDefaults] stringForKey:AWSPushManagerUserDefaultsEndpointARNKey];
}

- (void)setEndpointARN:(NSString *)endpointARN {
    [[NSUserDefaults standardUserDefaults] setObject:endpointARN
                                              forKey:AWSPushManagerUserDefaultsEndpointARNKey];
}

- (NSString *)platformARN {
    return [[NSUserDefaults standardUserDefaults] stringForKey:AWSPushManagerUserDefaultsPlatformARNKey];
}

- (NSArray<NSString *> *)topicARNs {
    return self.pushManagerConfiguration.topicARNs;
}

- (void)setPlatformARN:(NSString *)platformARN {
    [[NSUserDefaults standardUserDefaults] setObject:platformARN forKey:AWSPushManagerUserDefaultsPlatformARNKey];
}

#pragma mark - User action methods

- (void)registerForPushNotifications {
    UIApplication *application = [UIApplication sharedApplication];
    UIUserNotificationType types = UIUserNotificationTypeBadge | UIUserNotificationTypeSound | UIUserNotificationTypeAlert;
    UIUserNotificationSettings *notificationSettings = [UIUserNotificationSettings settingsForTypes:types
                                                                                         categories:nil];
    [application registerUserNotificationSettings:notificationSettings];
    [application registerForRemoteNotifications];
}

- (void)disablePushNotifications {
    AWSSNSSetEndpointAttributesInput *setEndpointAttributesInput = [AWSSNSSetEndpointAttributesInput new];
    setEndpointAttributesInput.endpointArn = self.endpointARN;
    setEndpointAttributesInput.attributes = @{@"Enabled": @"false"};
    
    __weak AWSPushManager *weakSelf = self;
    [[self.sns setEndpointAttributes:setEndpointAttributesInput] continueWithBlock:^id(AWSTask *task) {
        if (task.error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSError *error = task.error;
                [weakSelf.delegate pushManager:weakSelf
                     didFailToDisableWithError:error];
            });
        }
        if (task.result) {
            weakSelf.enabled = NO;
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf.delegate pushManagerDidDisable:weakSelf];
            });
        }
        return nil;
    }];
}

#pragma mark - Application Delegate interceptors

- (BOOL)interceptApplication:(UIApplication *)application
didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    if (self.isEnabled) {
        [self registerForPushNotifications];
    }
    return YES;
}

- (void)interceptApplication:(UIApplication *)application
didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    NSString *deviceTokenString = [AWSPushManager stringFromDeviceToken:deviceToken];
    AWSLogInfo(@"The device token: %@", deviceTokenString);
    
    __weak AWSPushManager *weakSelf = self;
    
    if (!deviceTokenString) {
        AWSLogError(@"The device token is invalid.");
        NSError *error = [NSError errorWithDomain:AWSPushManagerErrorDomain
                                             code:AWSPushManagerErrorTypeInvalidDeviceToken
                                         userInfo:nil];
        [self.delegate pushManager:self didFailToRegisterWithError:error];
        return;
    }
    
    self.deviceToken = deviceTokenString;
    
    AWSSNS *sns = self.sns;
    AWSTask *task = [AWSTask taskWithResult:nil];
    
    //if (endpoint arn not stored)
    if (!self.endpointARN) {
        // # first time registration
        task = [task continueWithSuccessBlock:^id(AWSTask *task) {
            AWSSNSCreatePlatformEndpointInput *createPlatformEndpointInput = [AWSSNSCreatePlatformEndpointInput new];
            createPlatformEndpointInput.token = deviceTokenString;
            createPlatformEndpointInput.platformApplicationArn = self.pushManagerConfiguration.platformARN;
            weakSelf.platformARN = self.pushManagerConfiguration.platformARN;
            // call CreatePlatformEndpoint
            return [[sns createPlatformEndpoint:createPlatformEndpointInput] continueWithSuccessBlock:^id(AWSTask *task) {
                AWSSNSCreateEndpointResponse *createEndPointResponse = task.result;
                NSString *endpointARN = createEndPointResponse.endpointArn;
                AWSLogInfo(@"endpointARN: %@", endpointARN);
                
                // store returned endpoint arn
                weakSelf.endpointARN = endpointARN;
                
                return nil;
            }];
        }];
    }
    
    [[[task continueWithSuccessBlock:^id(AWSTask *task) {
        // call GetEndpointAttributes on the endpoint arn
        AWSSNSGetEndpointAttributesInput *getEndpointAttributesInput = [AWSSNSGetEndpointAttributesInput new];
        getEndpointAttributesInput.endpointArn = weakSelf.endpointARN;
        return [sns getEndpointAttributes:getEndpointAttributesInput];
    }] continueWithBlock:^id(AWSTask *task) {
        if (task.error) {
            // if (getting attributes encountered NotFound exception)
            if ([task.error.domain isEqualToString:AWSSNSErrorDomain]
                && task.error.code == AWSSNSErrorNotFound) {
                // #endpoint was deleted
                // call CreatePlatformEndpoint
                AWSSNSCreatePlatformEndpointInput *createPlatformEndpointInput = [AWSSNSCreatePlatformEndpointInput new];
                createPlatformEndpointInput.token = deviceTokenString;
                createPlatformEndpointInput.platformApplicationArn = self.pushManagerConfiguration.platformARN;
                weakSelf.platformARN = self.pushManagerConfiguration.platformARN;
                return [[sns createPlatformEndpoint:createPlatformEndpointInput] continueWithSuccessBlock:^id(AWSTask *task) {
                    AWSSNSCreateEndpointResponse *createEndPointResponse = task.result;
                    NSString *endpointARN = createEndPointResponse.endpointArn;
                    AWSLogInfo(@"endpointARN: %@", endpointARN);
                    
                    // store returned endpoint arn
                    weakSelf.endpointARN = endpointARN;
                    
                    return nil;
                }];
            }
        }
        
        if (task.result) {
            AWSSNSGetEndpointAttributesResponse *getEndpointAttributesResponse = task.result;
            // if (token in endpoint does not match latest) or (GetEndpointAttributes shows endpoint as disabled)
            if (![getEndpointAttributesResponse.attributes[@"Token"] isEqualToString:deviceTokenString]
                || [getEndpointAttributesResponse.attributes[@"Enabled"] isEqualToString:@"false"]) {
                // call SetEndpointAttributes to set the latest token and enable the endpoint
                NSMutableDictionary *attributes = [getEndpointAttributesResponse.attributes mutableCopy];
                attributes[@"Token"] = deviceTokenString;
                attributes[@"Enabled"] = @"true";
                
                AWSSNSSetEndpointAttributesInput *setEndpointAttributesInput = [AWSSNSSetEndpointAttributesInput new];
                setEndpointAttributesInput.endpointArn = weakSelf.endpointARN;
                setEndpointAttributesInput.attributes = attributes;
                
                return [sns setEndpointAttributes:setEndpointAttributesInput];
            }
        }
        
        return nil;
    }] continueWithBlock:^id(AWSTask *task) {
        if (task.error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf.delegate pushManager:weakSelf
                    didFailToRegisterWithError:task.error];
            });
        } else {
            weakSelf.enabled = YES;
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf.delegate pushManagerDidRegister:weakSelf];
            });
        }
        return nil;
    }];
}

- (void)interceptApplication:(UIApplication *)application
didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    self.enabled = NO;
    [self.delegate pushManager:self
    didFailToRegisterWithError:error];
}

- (void)interceptApplication:(UIApplication *)application
didReceiveRemoteNotification:(NSDictionary *)userInfo {
    [self.delegate pushManager:self
    didReceivePushNotification:userInfo];
}

+ (NSString *)stringFromDeviceToken:(NSData *)deviceToken {
    NSUInteger length = deviceToken.length;
    if (length == 0) {
        return nil;
    }
    const unsigned char *buffer = deviceToken.bytes;
    NSMutableString *hexString  = [NSMutableString stringWithCapacity:(length * 2)];
    for (int i = 0; i < length; ++i) {
        [hexString appendFormat:@"%02x", buffer[i]];
    }
    return [hexString copy];
}

@end

NSString *const AWSPushTopicDictionarySubscriptionARNKey = @"subscriptionARN";
NSString *const AWSPushTopicDictionaryTopicARNKey = @"topicARN";

@implementation AWSPushTopic

- (instancetype)initWithTopicARN:(NSString *)topicARN
                     pushManager:(AWSPushManager *)pushManager {
    if (self = [super init]) {
        _topicARN = topicARN;
        _pushManager = pushManager;
        
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        NSDictionary *topicDictionary = [userDefaults dictionaryForKey:topicARN];
        if (topicDictionary) {
            _subscriptionARN = topicDictionary[AWSPushTopicDictionarySubscriptionARNKey];
        } else {
            [userDefaults setObject:@{AWSPushTopicDictionaryTopicARNKey: topicARN} forKey:topicARN];
        }
    }
    return self;
}

#pragma mark - Properties

- (NSString *)topicName {
    return [[self.topicARN componentsSeparatedByString:@":"] lastObject];
}

- (BOOL)isSubscribed {
    return _subscriptionARN ? YES : NO;
}

- (void)setSubscriptionARN:(NSString *)subscriptionARN {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
    NSMutableDictionary *topicDictionary = [[userDefaults dictionaryForKey:self.topicARN] mutableCopy];
    [topicDictionary setValue:subscriptionARN forKey:AWSPushTopicDictionarySubscriptionARNKey];
    
    [userDefaults setObject:topicDictionary forKey:self.topicARN];
    
    _subscriptionARN = subscriptionARN;
}

#pragma mark - User action methods

- (void)subscribe {
    AWSSNSSubscribeInput *subscribeInput = [AWSSNSSubscribeInput new];
    subscribeInput.topicArn = self.topicARN;
    subscribeInput.protocols = @"application";
    subscribeInput.endpoint = self.pushManager.endpointARN;
    
    AWSSNS *sns = self.pushManager.sns;
    __weak AWSPushTopic *weakSelf = self;
    [[sns subscribe:subscribeInput] continueWithBlock:^id(AWSTask *task) {
        if (task.result) {
            AWSSNSSubscribeResponse *subscribeResponse = task.result;
            self.subscriptionARN = subscribeResponse.subscriptionArn;
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.pushManager.delegate topicDidSubscribe:weakSelf];
            });
        }
        if (task.error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.pushManager.delegate topic:weakSelf
                     didFailToSubscribeWithError:task.error];
            });
        }
        return nil;
    }];
}

- (void)unsubscribe {
    AWSSNSUnsubscribeInput *unsubscribeInput = [AWSSNSUnsubscribeInput new];
    unsubscribeInput.subscriptionArn = self.subscriptionARN;
    
    AWSSNS *sns = self.pushManager.sns;
    __weak AWSPushTopic *weakSelf = self;
    [[sns unsubscribe:unsubscribeInput] continueWithBlock:^id(AWSTask *task) {
        if (!task.error) {
            self.subscriptionARN = nil;
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.pushManager.delegate topicDidUnsubscribe:weakSelf];
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.pushManager.delegate topic:weakSelf
                   didFailToUnsubscribeWithError:task.error];
            });
        }
        return nil;
    }];
}

@end

@implementation AWSPushManagerConfiguration

- (instancetype)initWithPlatformARN:(NSString *)snsPlatformARN
                          topicARNs:(NSArray<NSString *> *)topicARNs
               serviceConfiguration:(nullable AWSServiceConfiguration *)serviceConfiguration {
    if (self = [super init]) {
        _platformARN = snsPlatformARN;
        _topicARNs = topicARNs;
        _serviceConfiguration = serviceConfiguration;
    }
    return self;
}

- (instancetype)initWithPlatformARN:(NSString *)snsPlatformARN {
    return [[AWSPushManagerConfiguration alloc] initWithPlatformARN:snsPlatformARN
                                                          topicARNs:nil
                                               serviceConfiguration:nil];
}

@end
