/*
 * XMLDateElement.m
 * GPS Stone Trip Recorder
 *
 * Created by François Lamboley on 7/29/09.
 * Copyright 2009 VSO-Software. All rights reserved.
 */

#import "XMLDateElement.h"



@implementation XMLDateElement

+ (id)dateElementWithElementName:(NSString *)en date:(NSDate *)d
{
	XMLDateElement *de = [XMLDateElement new];
	
	de.elementName = en;
	de.date = d;
	de->containsText = YES;
	
	return de;
}

- (BOOL)readInt:(NSUInteger *)result fromString:(NSString *)str posInStr:(NSUInteger *)curPos powerOfTen:(NSUInteger)i
{
	NSString *figure;
	NSUInteger curReadInt;
	
	(*result) = 0;
	for (; i!=0; i/=10) {
		figure = [buf substringWithRange:NSMakeRange((*curPos)++, 1)];
		if (!figure || ([figure characterAtIndex:0] < '0' && [figure characterAtIndex:0] > '9')) return NO;
		curReadInt = [figure intValue];
		(*result) += curReadInt*i;
	}
	
	return YES;
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string
{
	if (!buf) buf = string;
	else      buf = [buf stringByAppendingString:string];
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
	containsText = YES;
	
	/* Hard core parsing of the date */
	NSDateComponents *comps = [NSDateComponents new];
	
	BOOL errWhenDecoding = YES;
	
	BOOL neg = NO;
	NSUInteger curReadPos = 0;
	NSUInteger secs, mins, hours, day, month, year;
	NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
	
	if ([[buf substringWithRange:NSMakeRange(curReadPos, 1)] isEqualToString:@"-"]) {
		neg = YES;
		curReadPos++;
	}
	if (![self readInt:&year fromString:buf posInStr:&curReadPos powerOfTen:1000]) goto err;
	[comps setYear:neg? -year: year];
	if (![[buf substringWithRange:NSMakeRange(curReadPos++, 1)] isEqualToString:@"-"]) goto err;
	if (![self readInt:&month fromString:buf posInStr:&curReadPos powerOfTen:10]) goto err;
	if (month > 12) goto err;
	[comps setMonth:month];
	if (![[buf substringWithRange:NSMakeRange(curReadPos++, 1)] isEqualToString:@"-"]) goto err;
	if (![self readInt:&day fromString:buf posInStr:&curReadPos powerOfTen:10]) goto err;
	[comps setDay:day];
	if (![[buf substringWithRange:NSMakeRange(curReadPos++, 1)] isEqualToString:@"T"]) goto err;
	if (![self readInt:&hours fromString:buf posInStr:&curReadPos powerOfTen:10]) goto err;
	if (hours > 23) goto err;
	[comps setHour:hours];
	if (![[buf substringWithRange:NSMakeRange(curReadPos++, 1)] isEqualToString:@":"]) goto err;
	if (![self readInt:&mins fromString:buf posInStr:&curReadPos powerOfTen:10]) goto err;
	if (mins > 59) goto err;
	[comps setMinute:mins];
	if (![[buf substringWithRange:NSMakeRange(curReadPos++, 1)] isEqualToString:@":"]) goto err;
	if (![self readInt:&secs fromString:buf posInStr:&curReadPos powerOfTen:10]) goto err;
	if (secs > 59) goto err;
	[comps setSecond:secs];
	if ([buf length] > curReadPos) {
		/* Decoding time zone here */
		if ([[buf substringWithRange:NSMakeRange(curReadPos, 1)] isEqualToString:@"Z"]) {
			curReadPos++;
			[gregorian setTimeZone:[NSTimeZone timeZoneWithName:@"UTC"]];
			if ([buf length] > curReadPos) goto err;
		} else {
			if      ([[buf substringWithRange:NSMakeRange(curReadPos, 1)] isEqualToString:@"+"]) neg = NO;
			else if ([[buf substringWithRange:NSMakeRange(curReadPos, 1)] isEqualToString:@"-"]) neg = YES;
			else goto err;
			curReadPos++;
			if (![self readInt:&hours fromString:buf posInStr:&curReadPos powerOfTen:10]) goto err;
			if (![[buf substringWithRange:NSMakeRange(curReadPos++, 1)] isEqualToString:@":"]) goto err;
			if (![self readInt:&mins  fromString:buf posInStr:&curReadPos powerOfTen:10]) goto err;
			[gregorian setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:(neg? -1: 1)*(3600*hours + 60*mins)]];
			if ([buf length] > curReadPos) goto err;
		}
	}
	
	
	errWhenDecoding = NO;
err:
	if (!errWhenDecoding) self.date = [gregorian dateFromComponents:comps];
	else                  NSXMLLog(@"Cannot read date: %@", buf);
	
	[super parser:parser didEndElement:elementName namespaceURI:namespaceURI qualifiedName:qName];
}

- (NSData *)dataForStuffBetweenTags:(NSUInteger)indent
{
	NSDateFormatter *formater = [NSDateFormatter new];
	[formater setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss'Z'"];
	return [[formater stringFromDate:self.date] dataUsingEncoding:VSO_XML_ENCODING];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"%@ object; date value = \"%@\"", self.elementName, self.date];
}

@end



@implementation XMLYearElement

- (NSInteger)year
{
	NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
	return [calendar components:NSCalendarUnitYear fromDate:self.date].year;
}

@end
