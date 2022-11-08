//
//  NSString+URL.h
//  Submariner
//
//  Created by Jax Wu on 2022/11/8.
//  Copyright © 2022 Jax Wu. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSString (URL)

- (NSString *)stringByURLEncode;
+ (NSString *)queryStringFromParameters:(NSDictionary *)parameters;

@end

NS_ASSUME_NONNULL_END
