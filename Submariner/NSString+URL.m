//
//  NSString+URL.m
//  Submariner
//
//  Created by Jax Wu on 2022/11/8.
//  Copyright © 2022 Jax Wu. All rights reserved.
//

#import "NSString+URL.h"

@interface SBQueryStringPair : NSObject

@property (readwrite, nonatomic, strong) id field;
@property (readwrite, nonatomic, strong) id value;

- (instancetype)initWithField:(id)field value:(id)value;

- (NSString *)URLEncodedStringValue;

@end

@implementation SBQueryStringPair

- (instancetype)initWithField:(id)field value:(id)value {
    self = [super init];
    if (!self) {
        return nil;
    }

    self.field = field;
    self.value = value;

    return self;
}

- (NSString *)URLEncodedStringValue {
    if (!self.value || [self.value isEqual:[NSNull null]]) {
        return [[self.field description] stringByURLEncode];
    } else {
        return [NSString stringWithFormat:@"%@=%@", [[self.field description] stringByURLEncode], [[self.value description] stringByURLEncode]];
    }
}

@end

@implementation NSString (URL)

- (NSString *)stringByURLEncode {
    static NSString * const kAFCharactersGeneralDelimitersToEncode = @":#[]@"; // does not include "?" or "/" due to RFC 3986 - Section 3.4
     static NSString * const kAFCharactersSubDelimitersToEncode = @"!$&'()*+,;=";

     NSMutableCharacterSet * allowedCharacterSet = [[NSCharacterSet URLQueryAllowedCharacterSet] mutableCopy];
     [allowedCharacterSet removeCharactersInString:[kAFCharactersGeneralDelimitersToEncode stringByAppendingString:kAFCharactersSubDelimitersToEncode]];

     static NSUInteger const batchSize = 50;

     NSUInteger index = 0;
     NSMutableString *escaped = @"".mutableCopy;

     while (index < self.length) {
         NSUInteger length = MIN(self.length - index, batchSize);
         NSRange range = NSMakeRange(index, length);

         // To avoid breaking up character sequences such as 👴🏻👮🏽
         range = [self rangeOfComposedCharacterSequencesForRange:range];

         NSString *substring = [self substringWithRange:range];
         NSString *encoded = [substring stringByAddingPercentEncodingWithAllowedCharacters:allowedCharacterSet];
         [escaped appendString:encoded];

         index += range.length;
     }

     return escaped;
}

+ (NSString *)queryStringFromParameters:(NSDictionary *)parameters {
    NSMutableArray *mutablePairs = [NSMutableArray array];
    for (SBQueryStringPair *pair in [self SBQueryStringPairsFromDictionary:parameters]) {
        [mutablePairs addObject:[pair URLEncodedStringValue]];
    }

    return [mutablePairs componentsJoinedByString:@"&"];
}

+ (NSArray <SBQueryStringPair *>*)SBQueryStringPairsFromDictionary:(NSDictionary *)dictionary {
    return [self SBQueryStringPairsFromKeyAndValue:nil value:dictionary];
}

+ (NSArray <SBQueryStringPair *>* )SBQueryStringPairsFromKeyAndValue:(NSString *)key value:(id)value {
    NSMutableArray *mutableQueryStringComponents = [NSMutableArray array];

    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"description" ascending:YES selector:@selector(compare:)];
    if ([value isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dictionary = value;
        // Sort dictionary keys to ensure consistent ordering in query string, which is important when deserializing potentially ambiguous sequences, such as an array of dictionaries
        for (id nestedKey in [dictionary.allKeys sortedArrayUsingDescriptors:@[ sortDescriptor ]]) {
            id nestedValue = dictionary[nestedKey];
            if (nestedValue) {
                [mutableQueryStringComponents addObjectsFromArray:[self SBQueryStringPairsFromKeyAndValue:key ? [NSString stringWithFormat:@"%@[%@]", key, nestedKey] : nestedKey value:nestedValue]];
            }
        }
    } else if ([value isKindOfClass:[NSArray class]]) {
        NSArray *array = value;
        for (id nestedValue in array) {
            [mutableQueryStringComponents addObjectsFromArray:[self SBQueryStringPairsFromKeyAndValue:[NSString stringWithFormat:@"%@[]", key] value:nestedValue]];
        }
    } else if ([value isKindOfClass:[NSSet class]]) {
        NSSet *set = value;
        for (id obj in [set sortedArrayUsingDescriptors:@[ sortDescriptor ]]) {
            [mutableQueryStringComponents addObjectsFromArray:[self SBQueryStringPairsFromKeyAndValue:key value:obj]];
        }
    } else {
        [mutableQueryStringComponents addObject:[[SBQueryStringPair alloc] initWithField:key value:value]];
    }

    return mutableQueryStringComponents;
}

@end
