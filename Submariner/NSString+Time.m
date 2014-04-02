//
//  NSString+Time.m
//  Play
//
//  Created by Rafaël Warnault on 14/02/11.
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

#import "NSString+Time.h"


@implementation NSString (Time)

+ (NSString *)stringWithTime:(double)time {
	
	if(time == 0)
		return @"0:00";
	
	NSMutableString *_string = [NSMutableString stringWithCapacity:2];
	int minutes = 0;
	int seconds = 0;
	BOOL isNegative = NO;
	
	if(time < 0) {
		
		isNegative = YES;
		time = fabs(time);
		
		minutes = time / 60;
		seconds = (int)time % 60;
		
	} else {
		
		minutes = time / 60;
		seconds = (int)time % 60;
		
	}
	
	NSString *minutesString = [NSString stringWithFormat:@"%d", minutes];
	NSString *secondsString = [NSString stringWithFormat:@"%d", seconds];
	
	if([minutesString length] == 1)
		minutesString = [@"0" stringByAppendingString:minutesString];
	
	if([secondsString length] == 1)
		secondsString = [@"0" stringByAppendingString:secondsString];
	
	if(isNegative) {
		[_string appendFormat:@"-%@:%@", minutesString, secondsString];

	} else {
		[_string appendFormat:@"%@:%@", minutesString, secondsString];

	}
	
	return _string;
	
}

@end
