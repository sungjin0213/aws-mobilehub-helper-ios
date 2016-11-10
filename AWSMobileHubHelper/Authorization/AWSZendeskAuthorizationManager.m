//
//  AWSZendeskAuthorizationManager.m
//
// Copyright 2016 Amazon.com, Inc. or its affiliates (Amazon). All Rights Reserved.
//
// Code generated by AWS Mobile Hub. Amazon gives unlimited permission to
// copy, distribute and modify it.
//

#import "AWSZendeskAuthorizationManager.h"
#import <AWSCore/AWSCore.h>

static NSString *const AWSZendeskAuthorizationManagerAuthorizeURLFormatString = @"https://%@.zendesk.com/oauth/authorizations/new";
static NSString *const AWSZendeskAuthorizationManagerLogoutURLFormatString = @"https://%@.zendesk.com/access/logout";

static NSString *const AWSZendeskAuthorizationManagerTokenTypeKey = @"token_type";
static NSString *const AWSZendeskAuthorizationManagerAccessTokenKey = @"access_token";

@interface AWSAuthorizationManager()

- (void)completeLoginWithResult:(id)result
                          error:(NSError *)error;

@end

@interface AWSZendeskAuthorizationManager()

@property (strong, nonatomic) NSString *authorizeURLString;
@property (strong, nonatomic) NSString *logoutURLString;
@property (strong, nonatomic) NSString *clientID;
@property (strong, nonatomic) NSString *subdomain;
@property (strong, nonatomic) NSString *redirectURI;
@property (strong, nonatomic) NSString *scope;

@property (strong, nonatomic) NSDictionary *valuesFromResponse;

@end

@implementation AWSZendeskAuthorizationManager

+ (instancetype)sharedInstance {
    static AWSZendeskAuthorizationManager *_sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[AWSZendeskAuthorizationManager alloc] init];
    });
    
    return _sharedInstance;
}

- (instancetype)init {
    if (self = [super init]) {
        NSDictionary *config = [[[AWSInfo defaultAWSInfo].rootInfoDictionary objectForKey:@"SaaS"] objectForKey:@"Zendesk"];
        _authorizeURLString = [NSString stringWithFormat:AWSZendeskAuthorizationManagerAuthorizeURLFormatString, [config objectForKey:@"Subdomain"]];
        [self configureWithClientID:[config objectForKey:@"ClientID"]
                        redirectURI:[config objectForKey:@"RedirectURI"]
                          subdomain:[config objectForKey:@"Subdomain"]];
        _scope = @"";
        
        return self;
    }
    return nil;
}

- (void)configureWithClientID:(NSString *)clientID
                  redirectURI:(NSString *)redirectURI
                    subdomain:(NSString *)subdomain {
    self.clientID = clientID ?: @"";
    self.redirectURI = redirectURI ?: @"";
    self.authorizeURLString = [NSString stringWithFormat:AWSZendeskAuthorizationManagerAuthorizeURLFormatString, subdomain];
    self.logoutURLString = [NSString stringWithFormat:AWSZendeskAuthorizationManagerLogoutURLFormatString, subdomain];
    self.subdomain = subdomain ?: @"";
}

- (void)setScope:(NSString *)scope {
    self.scope = scope;
}

- (NSString *)getTokenType {
    return [self.valuesFromResponse objectForKey:AWSZendeskAuthorizationManagerTokenTypeKey];
}

- (NSString *)getSubdomain {
    return self.subdomain;
}

- (NSURL *)generateAuthURL {
    if ([self.scope length] == 0) {
        [self completeLoginWithResult:nil error:[NSError errorWithDomain:AWSAuthorizationManagerErrorDomain
                                                                    code:AWSAuthorizationErrorMissingRequiredParameter
                                                                userInfo:@{@"message": @"Missing parameter: scope"}]];
    }
    NSDictionary *params = @{
                             @"response_type" : @"token",
                             @"client_id" : self.clientID,
                             @"redirect_uri" : [self.redirectURI stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLHostAllowedCharacterSet]],
                             @"scope" : [self.scope stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLHostAllowedCharacterSet]]
                             };
    
    NSString *urlString = [NSString stringWithFormat:@"%@?%@", self.authorizeURLString, [AWSAuthorizationManager constructURIWithParameters:params]];
    return [NSURL URLWithString:urlString];
}

- (BOOL)isAcceptedURL:(NSURL *)url {
    return [[url absoluteString] hasPrefix:self.redirectURI];
}

- (NSString *)findAccessCode:(NSURL *)url {
    NSString *prefix = [NSString stringWithFormat:@"%@#", self.redirectURI];
    NSString *formString = [[url absoluteString] stringByReplacingOccurrencesOfString:prefix withString:@""];
    self.valuesFromResponse = [AWSAuthorizationManager constructParametersWithURI:formString];
    return [self.valuesFromResponse objectForKey:AWSZendeskAuthorizationManagerAccessTokenKey];
}

- (NSURL *)generateLogoutURL {
    return [NSURL URLWithString:self.logoutURLString];
}

@end