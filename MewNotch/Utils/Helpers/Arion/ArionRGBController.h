//
//  ArionRGBController.h
//  MewNotch
//
//  Created by Codex on 25/02/26.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSErrorDomain const ArionRGBErrorDomain;

typedef NS_ERROR_ENUM(ArionRGBErrorDomain, ArionRGBErrorCode) {
    ArionRGBErrorCodeDeviceNotFound = 1,
    ArionRGBErrorCodeUserClientNotAvailable = 2,
    ArionRGBErrorCodeCommandFailed = 3,
};

@interface ArionRGBController : NSObject

+ (instancetype)sharedInstance;

- (BOOL)isArionAvailable;

- (BOOL)canOpenChannelWithError:(NSError * _Nullable * _Nullable)error;

- (BOOL)applyStaticColorWithRed:(uint8_t)red
                          green:(uint8_t)green
                           blue:(uint8_t)blue
                          error:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END
