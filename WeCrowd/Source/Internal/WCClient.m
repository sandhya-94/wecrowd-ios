//
//  WCClient.m
//  WeCrowd
//
//  Created by Zach Vega-Perkins on 6/19/15.
//  Copyright (c) 2015 WePay. All rights reserved.
//

#import "WCClient.h"
#import "WCModelProcessor.h"
#import "WCConstants.h"
#import "WCCampaignDonationModel.h"
#import "WCUserModel.h"
#import "WCError.h"

@class WCCampaignBaseModel;

#pragma mark - Constants

// Requests
static NSInteger const kTimeoutInterval = 5;
static NSInteger const kStatusCodeSuccess = 200;

static NSString* const kHTTPRequestPost = @"POST";
static NSString* const kHTTPRequestGet  = @"GET";

// API
static NSString* const kAPIURLString = @"https://wecrowd-dot-partner-demos.appspot.com/api";

#pragma mark - Implementation

@implementation WCClient

#pragma mark - External Methods

+ (void) loginWithUsername:(NSString *) username
                  password:(NSString *) password
           completionBlock:(void (^)(NSDictionary *userInfo, NSError *)) completionBlock
{
    [self makePostRequestToEndPoint:[self apiURLWithEndpoint:kAPIEndpointLogin]
                             values:@{ kAPIEmailKey : username, kAPIPasswordKey : password }
                        accessToken:nil
                       successBlock:^(NSDictionary *returnData)
    {
        // Check the status of the return data
        if ([returnData objectForKey:kAPIParameterErrorCode])
        {
            NSError *APIError;

            APIError = [WCError APIErrorWithDescription:@"API error for login."
                                         serverMessage:[returnData objectForKey:kAPIParameterErrorMessage]
                                              codeData:returnData];

            completionBlock(nil, APIError);
            NSLog(@"Error: API: %@.", [returnData objectForKey:kAPIParameterErrorMessage]);
        }
        else
        {
           // No error code, so hand off the data
           completionBlock(returnData, nil);
        }
    }
                       // This bit looks confusing, but errorHandler is the final argument of the post request.
                       errorHandler:^(NSError *error)
    {
        // This means there was either a connection error or a parse error
        completionBlock(nil, error);
    }];
}

+ (void) donateWithDonation:(WCCampaignDonationModel *) donation
            completionBlock:(void (^)(NSString *checkoutID, NSError *)) completionBlock
{
    NSNumber *amount, *campaignID;
    
    amount = [NSNumber numberWithInteger:[donation.amount integerValue]];
    campaignID = [NSNumber numberWithInteger:[donation.campaignID integerValue]];
    
    NSDictionary *values = @{ kAPIDonationIDKey              : campaignID,
                              kAPIDonationCreditCardTokenKey : donation.creditCardID,
                              kAPIDonationAmountKey          : amount };
    
     [self makePostRequestToEndPoint:[self apiURLWithEndpoint:kAPIEndpointDonate]
                              values:values
                         accessToken:nil
                        successBlock:^(id returnData)
    {
        // Check for an API error
        if ([returnData objectForKey:kAPIParameterErrorCode])
        {
            NSError *APIError;
            
            APIError = [WCError APIErrorWithDescription:@"API error for donation."
                                          serverMessage:[returnData objectForKey:kAPIParameterErrorMessage]
                                               codeData:returnData];
            
            completionBlock(nil, APIError);
            NSLog(@"Error: API: %@.", [returnData objectForKey:kAPIParameterErrorMessage]);
        }
        else
        {
            // No error code, so hand off the data
            NSNumber *checkoutIDNum = [returnData objectForKey:@"checkout_id"];
            
            completionBlock([checkoutIDNum stringValue], nil);
        }
    }
                        errorHandler:^(NSError *error)
    {
        // This means there was either a connection error or a parse error
        completionBlock(nil, error);
        NSLog(@"Error: Client: Unable to complete donation.");
    }];
}

+ (void) fetchAllCampaigns:(WCArrayReturnBlock) completionBlock
{
    [self makeGetRequestToEndpoint:[self apiURLWithEndpoint:kAPIEndpointCampaigns]
                       accessToken:nil
                      successBlock:^(NSArray *returnData)
    {
        completionBlock([WCModelProcessor createProcessedArrayForCampaigns:returnData], nil);
    }
                      errorHandler:^(NSError *error)
    {
        completionBlock(nil, error);
    }];
}

+ (void) fetchAllCampaignsForUser:(NSString *) userID
                        withToken:(NSString *) token
                  completionBlock:(WCArrayReturnBlock) completionBlock
{
    [self makePostRequestToEndPoint:[self apiURLWithEndpoint:kAPIEndpointUsers]
                             values:@{ kAPIUserIDKey : userID, kAPIUserTokenKey : token }
                        accessToken:nil
                       successBlock:^(NSArray *returnData)
    {
        NSLog(@"Success: Client: Fetched campaigns for user.");
        completionBlock([WCModelProcessor createProcessedArrayForCampaigns:returnData], nil);
    }
                       errorHandler:^(NSError *error)
    {
        NSLog(@"Error: Client: failed to fetch user campaigns.");
        completionBlock(nil, error);
    }];
}

+ (void) fetchFeaturedCampaigns:(WCArrayReturnBlock) completionBlock
{
    [self makeGetRequestToEndpoint:[self apiURLWithEndpoint:kAPIEndpointFeaturedCampaigns]
                       accessToken:nil
                      successBlock:^(id returnData)
    {
        NSLog(@"Success: Client: Fetched featured campaigns.");
        completionBlock([WCModelProcessor createProcessedArrayForCampaigns:returnData], nil);
    }
                      errorHandler:^(NSError *error)
    {
        completionBlock(nil, error);
    }];
}

+ (void) fetchCampaignWithID:(NSString *) campaignID
             completionBlock:(WCCampaignDetailReturnBlock) completionBlock
{
    // Get the full URL Endpoint
    NSMutableString *URLString = [kAPIEndpointCampaigns mutableCopy];
    [URLString appendString:[NSString stringWithFormat:@"/%@", campaignID]];
    
    [self makeGetRequestToEndpoint:[self apiURLWithEndpoint:URLString]
                       accessToken:nil
                      successBlock:^(id returnData)
    {
        NSLog(@"Success: Client: Fetched campaign.");
      
        [WCModelProcessor createCampaignDetailFromDictionary:returnData
                                                  completion:^(WCCampaignDetailModel *model, NSError *error)
      
        {
            completionBlock(model, error);
        }];
    }
                      errorHandler:^(NSError *error)
    {
        NSLog(@"Error: Client: Unable to fetch campaign.");
        completionBlock(nil, error);
    }];
}

#pragma mark - Endpoint Requests

+ (void) makePostRequestToEndPoint:(NSURL *) endpoint
                            values:(NSDictionary *) params
                       accessToken:(NSString *) accessToken
                      successBlock:(void (^)(id returnData)) successHandler
                      errorHandler:(void (^)(NSError * error)) errorHandler
{
    [self makeRequestToEndPoint:endpoint
                         method:kHTTPRequestPost
                         values:params
                    accessToken:accessToken
                   successBlock:successHandler
                   errorHandler:errorHandler];
}

+ (void) makeGetRequestToEndpoint:(NSURL *) endpoint
                      accessToken:(NSString *) accessToken
                     successBlock:(void (^)(id returnData)) successHandler
                     errorHandler:(void (^)(NSError *)) errorHandler
{
    [self makeRequestToEndPoint:endpoint
                         method:kHTTPRequestGet
                         values:nil
                    accessToken:accessToken
                   successBlock:successHandler
                   errorHandler:errorHandler];
}

// TODO: change this so that there is only one result block that includes an error parameter.
+ (void) makeRequestToEndPoint:(NSURL *) endpoint
                        method:(NSString *) method
                        values:(NSDictionary *) params
                   accessToken:(NSString *) accessToken
                  successBlock:(void (^)(id returnData)) successHandler
                  errorHandler:(void (^)(NSError * error)) errorHandler
{
    NSMutableURLRequest *returnRequest;
    
    returnRequest = [WCClient createRequestWithURL:endpoint
                                            method:method
                                          bodyData:params
                                       accessToken:accessToken];
    
    // Send the request asynchronously and process the response
    [NSURLConnection sendAsynchronousRequest:returnRequest
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response,
                                               NSData *data,
                                               NSError *connectionError)
     {
         // Process the server's response
         if (connectionError)
         {
             NSLog(@"ConnectionError: Client: %@.", [connectionError localizedDescription]);
         }
         else
         {
             id requestObject;
             requestObject = [WCClient objectFromResponse:response
                                                 withData:data];
             
             if (requestObject)
             {
                 successHandler(requestObject);
             }
         }
     }];
}

#pragma mark - Helpers

+ (NSMutableURLRequest *) createRequestWithURL:(NSURL *) URL
                                        method:(NSString *) method
                                      bodyData:(id) bodyData
                                   accessToken:(NSString *) accessToken
{
    NSError *parseError = nil;
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL
                                                           cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                       timeoutInterval:kTimeoutInterval];
    // Configure the  request
    [request setHTTPMethod:method];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"utf-8" forHTTPHeaderField:@"charset"];
    
    // Set the access token if it exists
    if (accessToken)
    {
        [request setValue:[NSString stringWithFormat:@"bearer %@", accessToken]
       forHTTPHeaderField:@"Authorization"];
    }
    
    // Set the body data if there is any
    if (bodyData)
    {
        [request setHTTPBody:[NSJSONSerialization dataWithJSONObject:bodyData
                                                             options:kNilOptions
                                                               error:&parseError]];
        
        NSAssert(!parseError, @"WCClient: Unable to process body data with error: %@", [parseError localizedDescription]);
    }

    return request;
}

+ (NSURL *) apiURLWithEndpoint:(NSString *) endpoint
{
    return [NSURL URLWithString:[kAPIURLString stringByAppendingString:endpoint]];
}

#pragma mark - Data Processing

+ (id) objectFromResponse:(NSURLResponse *) response
                 withData:(NSData *) data
{
    NSError *extractionError;
    NSInteger statusCode;
    id extractedData;
    
    // Build a structure from the raw data
    statusCode = [(NSHTTPURLResponse *) response statusCode];
    
    if (statusCode == kStatusCodeSuccess)
    {
        // Try to extract JSON data first
        extractedData = [NSJSONSerialization JSONObjectWithData:data
                                                        options:kNilOptions
                                                          error:&extractionError];
        if (!extractedData)
        {
            // If JSON extraction fails, try to extract binary data
            // For now, only image case is handled
            extractedData = [UIImage imageWithData:data];
        }
    }
    else
    {
        NSString *description;
        
        description = [NSString stringWithFormat:@"Client: Error %zd: Client: Unable to process request %@.", statusCode, response.URL.path];
        NSLog(@"%@", description);
        
        extractedData = nil;
    }
    
    return extractedData;
}

#pragma mark - Asset Fetching

+ (void) fetchImageWithURLString:(NSString *) URLString
                 completionBlock:(void (^)(UIImage *image, NSError *error)) completionBlock
{
    [self makeGetRequestToEndpoint:[NSURL URLWithString:URLString]
                       accessToken:nil
                      successBlock:^(id returnData)
    {
        completionBlock(returnData, nil);
    }
    errorHandler:^(NSError *error)
    {
        completionBlock(nil, error);
    }];
}

@end
