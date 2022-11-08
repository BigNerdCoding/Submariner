//
//  NSURL+Parameters.m
//  Sub
//
//  Created by Rafaël Warnault on 23/05/11.
//
//  Copyright (c) 2011-2014, Rafaël Warnault
//  All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//  * Redistributions of source code must retain the above copyright notice, this
//  list of conditions and the following disclaimer.
//
//  * Redistributions in binary form must reproduce the above copyright notice,
//  this list of conditions and the following disclaimer in the documentation
//  and/or other materials provided with the distribution.
//
//  * Neither the name of the Read-Write.fr nor the names of its
//  contributors may be used to endorse or promote products derived from
//  this software without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
//  DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
//  FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
//  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
//  SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
//  CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
//  OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
//  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#import "NSURL+Parameters.h"
#import "NSString+URL.h"

@implementation NSURL (Parameters)

+ (NSURL *)temporaryFileURL {
    NSURL *tempDir = [[NSFileManager defaultManager] temporaryDirectory];
    NSString *randomName = [[NSUUID UUID] UUIDString];
    return [tempDir URLByAppendingPathComponent: randomName];
}

+ (id)URLWithString:(NSString *)string command:(NSString *)command parameters:(NSDictionary *)parameters {
    string = [[NSURL URLWithString:command relativeToURL:[NSURL URLWithString:string]] absoluteString];;
    NSURL *url = [NSURL URLWithString:[string stringByAddingPercentEncodingWithAllowedCharacters: [NSCharacterSet URLQueryAllowedCharacterSet]]];
    
    if (parameters != nil) {
        NSString *queryString = [NSString queryStringFromParameters:parameters];
        
        if ([queryString length] > 0) {
            url = [NSURL URLWithString:[[url absoluteString] stringByAppendingFormat:url.query ? @"&%@" : @"?%@", queryString]];
        }
    }
        
    return url;
}

- (NSNumber *)keychainProtocol {
    if ([self.scheme isEqualToString: @"https"]) {
        return [NSNumber numberWithUnsignedInt: kSecProtocolTypeHTTPS];
    }
    return [NSNumber numberWithUnsignedInt: kSecProtocolTypeHTTP];
}

- (NSNumber *)portWithHTTPFallback {
    if([self port] != nil) {
        return [self port];
    }
    return [NSNumber numberWithInteger: [self.scheme isEqualToString: @"https"] ? 443 : 80];
}

@end
