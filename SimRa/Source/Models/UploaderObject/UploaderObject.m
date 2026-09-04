//
//  UploaderObject.m
//  SimRa
//
//  Created by Christoph Krey on 04.04.19.
//  Copyright © 2019-2021 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

#import "UploaderObject.h"
#import "../../Utils/Helper/NSString+hashCode.h"
#import "SimRa-Swift.h"
#import "../Regions/Regions.h"
#import "API.h"
#import <Security/Security.h>

@interface UploaderObject ()

@end

@implementation UploaderObject

- (instancetype)init {
    self = [super init];
    self.version = 1;
    return self;
}

- (NSURL *)csvFile {
    return nil; // must override
}

- (void)save {
    // must override
}

- (NSURLSession *)uploadSession {
    static NSURLSession *session = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        configuration.timeoutIntervalForRequest = 30.0;
        configuration.timeoutIntervalForResource = 300.0;

        if (@available(iOS 11.0, *)) {
            configuration.waitsForConnectivity = YES;
        }

        session = [NSURLSession sessionWithConfiguration:configuration
                                                delegate:self
                                           delegateQueue:nil];
    });
    return session;
}

- (NSURLComponents *)uploadURLComponentsWithName:(NSString *)name
                                        fileHash:(NSString *)fileHash
                                      filePasswd:(NSString *)filePasswd {
    NSString *baseURLString = [NSString stringWithFormat:@"%@/%@", API.APIPrefix, name];
    NSURLComponents *components = [NSURLComponents componentsWithString:baseURLString];
    if (!components) {
        return nil;
    }

    AppDelegate *ad = [AppDelegate sharedDelegate];
    NSMutableArray<NSURLQueryItem *> *queryItems = [[NSMutableArray alloc] init];
    [queryItems addObject:[NSURLQueryItem queryItemWithName:@"loc" value:ad.regions.currentRegion.identifier]];
    [queryItems addObject:[NSURLQueryItem queryItemWithName:@"clientHash" value:NSString.clientHash]];

    if (fileHash.length > 0 && filePasswd.length > 0) {
        [queryItems insertObject:[NSURLQueryItem queryItemWithName:@"fileHash" value:fileHash] atIndex:0];
        [queryItems insertObject:[NSURLQueryItem queryItemWithName:@"filePassword" value:filePasswd] atIndex:1];
    }

    components.queryItems = queryItems;
    return components;
}

- (void)uploadFile:(NSString *)name WithController:(id)controller error:(SEL)error completion:(SEL)completion {
    NSURL *csvFile = self.csvFile;

    NSData *data = [NSData dataWithContentsOfURL:csvFile];
    NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSLog(@"data:\n%@", string);

    AppDelegate *ad = [AppDelegate sharedDelegate];

    NSURLComponents *components;
    if (self.fileHash && self.filePasswd) {
        if ([self.fileHash  isEqual: @""] || [self.filePasswd  isEqual: @""]){
            NSArray *keyPass = [Utility getKeyPasswrdForRegion];
            if (keyPass.count >= 2) {
                self.fileHash = keyPass[0];
                self.filePasswd = keyPass[1];
            }
        }
        components = [self uploadURLComponentsWithName:name
                                              fileHash:self.fileHash
                                            filePasswd:self.filePasswd];
    } else {
        components = [self uploadURLComponentsWithName:name
                                              fileHash:nil
                                            filePasswd:nil];
    }

    if (!components.URL) {
        NSError *urlError = [NSError errorWithDomain:@"SimRa.Upload"
                                                code:-1
                                            userInfo:@{NSLocalizedDescriptionKey: @"Invalid upload URL"}];
        [controller performSelectorOnMainThread:error
                                      withObject:urlError
                                   waitUntilDone:NO];
        return;
    }

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:components.URL];
    request.HTTPMethod = (self.fileHash.length > 0 && self.filePasswd.length > 0) ? @"PUT" : @"POST";

    [request setValue:@"text/plain" forHTTPHeaderField: @"Content-Type"];
    [request setTimeoutInterval:30.0];
    NSLog(@"request:\n%@", request);

    NSURLSession *session = [self uploadSession];
    NSURLSessionUploadTask *dataTask =
    [
     session
     uploadTaskWithRequest:request
     fromFile:csvFile
     completionHandler:^(NSData *data,
                         NSURLResponse *response,
                         NSError *connectionError) {

         if (connectionError) {
             NSLog(@"connectionError %@", connectionError);
             [controller performSelectorOnMainThread:error
                                          withObject:connectionError
                                       waitUntilDone:NO];
         } else {
             NSLog(@"response %@ %@",
                   response,
                   [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);

             if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
                 NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                 if (httpResponse.statusCode >= 200 && httpResponse.statusCode <= 299) {
                     if ([request.HTTPMethod isEqualToString:@"POST"]) {
                         NSString *dataString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                         NSArray <NSString *> *components = [dataString componentsSeparatedByString:@","];
                         if (components.count == 2) {
                             self.fileHash = components[0];
                             self.filePasswd = components[1];
                             // store here keys and password
                             NSString *key = [NSString stringWithFormat:@"Profile_%ld",(long)ad.regions.regionId];
                             NSString *value = [NSString stringWithFormat:@"%@,%@",self.fileHash,self.filePasswd];
                             [Utility writeToKeyPrefsWithKey:key val:value];
                         }
                     }
                     self.version++;
                     self.uploaded = TRUE;
                     if ([self respondsToSelector:@selector(successfullyReUploaded)]) {
                         [self performSelector:@selector(successfullyReUploaded)];
                     }
                     self.edited = FALSE;
                     [self performSelectorOnMainThread:@selector(save)
                                            withObject:nil
                                         waitUntilDone:TRUE];
                 } else {
                     //
                 }
             } else {
                 //
             }

             NSDictionary *dict = @{@"response": response, @"data":data};
             [controller performSelectorOnMainThread:completion
                                          withObject:dict
                                       waitUntilDone:NO];
         }
     }];

    [dataTask resume];
}

- (void)URLSession:(NSURLSession *)session
      didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
        completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential))completionHandler {
    if (![challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
        return;
    }

    SecTrustRef trust = challenge.protectionSpace.serverTrust;
    if (!trust) {
        completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
        return;
    }

    NSString *certificatePath = [[NSBundle mainBundle] pathForResource:@"server" ofType:@"cer"];
    NSData *certificateData = certificatePath.length > 0 ? [NSData dataWithContentsOfFile:certificatePath] : nil;
    if (certificateData) {
        SecCertificateRef certificate = SecCertificateCreateWithData(NULL, (__bridge CFDataRef)certificateData);
        if (certificate) {
            NSArray *certificates = @[(__bridge id)certificate];
            SecTrustSetAnchorCertificates(trust, (__bridge CFArrayRef)certificates);
            SecTrustSetAnchorCertificatesOnly(trust, YES);
            CFRelease(certificate);
        }
    }

    BOOL trustIsValid = NO;
    if (@available(iOS 13.0, *)) {
        trustIsValid = SecTrustEvaluateWithError(trust, NULL);
    } else {
        SecTrustResultType result;
        OSStatus status = SecTrustEvaluate(trust, &result);
        trustIsValid = (status == errSecSuccess &&
                        (result == kSecTrustResultProceed || result == kSecTrustResultUnspecified));
    }

    if (trustIsValid) {
        completionHandler(NSURLSessionAuthChallengeUseCredential,
                          [NSURLCredential credentialForTrust:trust]);
    } else {
        completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, nil);
    }
}

@end
