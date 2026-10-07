/*
 This file is part of Darling.

 Copyright (C) 2019 Lubos Dolezel

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Darling is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with Darling.  If not, see <http://www.gnu.org/licenses/>.
*/

#import <Foundation/NSDateComponentsFormatter.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSNumberFormatter.h>
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>
#include <math.h>
#include <string.h>

// English names; the formatter doesn't localize yet.
enum { kUnitYear, kUnitMonth, kUnitWeek, kUnitDay, kUnitHour, kUnitMinute, kUnitSecond, kUnitCount };

static const struct {
    NSCalendarUnit unit;
    double seconds; // average length
    const char *full, *fullPlural;
    const char *shortName, *shortPlural;
    const char *abbreviated;
    const char *brief, *briefPlural;
} units[kUnitCount] = {
    { NSCalendarUnitYear, 365.2425 * 86400, "year", "years", "yr", "yrs", "y", "yr", "yrs" },
    { NSCalendarUnitMonth, 365.2425 * 86400 / 12, "month", "months", "mth", "mths", "mo", "mth", "mths" },
    { NSCalendarUnitWeekOfMonth, 7 * 86400, "week", "weeks", "wk", "wks", "w", "wk", "wks" },
    { NSCalendarUnitDay, 86400, "day", "days", "day", "days", "d", "day", "days" },
    { NSCalendarUnitHour, 3600, "hour", "hours", "hr", "hr", "h", "hr", "hr" },
    { NSCalendarUnitMinute, 60, "minute", "minutes", "min", "min", "m", "min", "min" },
    { NSCalendarUnitSecond, 1, "second", "seconds", "sec", "sec", "s", "sec", "sec" },
};

@implementation NSDateComponentsFormatter

@synthesize unitsStyle = _unitsStyle;
@synthesize allowedUnits = _allowedUnits;
@synthesize zeroFormattingBehavior = _zeroFormattingBehavior;
@synthesize allowsFractionalUnits = _allowsFractionalUnits;
@synthesize maximumUnitCount = _maximumUnitCount;
@synthesize collapsesLargestUnit = _collapsesLargestUnit;
@synthesize includesApproximationPhrase = _includesApproximationPhrase;
@synthesize includesTimeRemainingPhrase = _includesTimeRemainingPhrase;
@synthesize formattingContext = _formattingContext;

+ (NSString *)localizedStringFromDateComponents:(NSDateComponents *)components
                                      unitsStyle:(NSDateComponentsFormatterUnitsStyle)unitsStyle
{
    NSDateComponentsFormatter *formatter = [[NSDateComponentsFormatter alloc] init];
    NSString *result;

    [formatter setUnitsStyle:unitsStyle];
    result = [formatter stringFromDateComponents:components];
    [formatter release];
    return result;
}

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _unitsStyle = NSDateComponentsFormatterUnitsStylePositional;
        _zeroFormattingBehavior = NSDateComponentsFormatterZeroFormattingBehaviorDefault;
    }
    return self;
}

- (void)dealloc
{
    [_calendar release];
    [_referenceDate release];
    [super dealloc];
}

- (id)copyWithZone:(NSZone *)zone
{
    NSDateComponentsFormatter *copy = [[[self class] allocWithZone:zone] init];

    copy->_unitsStyle = _unitsStyle;
    copy->_allowedUnits = _allowedUnits;
    copy->_zeroFormattingBehavior = _zeroFormattingBehavior;
    copy->_calendar = [_calendar copy];
    copy->_referenceDate = [_referenceDate copy];
    copy->_allowsFractionalUnits = _allowsFractionalUnits;
    copy->_maximumUnitCount = _maximumUnitCount;
    copy->_collapsesLargestUnit = _collapsesLargestUnit;
    copy->_includesApproximationPhrase = _includesApproximationPhrase;
    copy->_includesTimeRemainingPhrase = _includesTimeRemainingPhrase;
    copy->_formattingContext = _formattingContext;
    return copy;
}

- (NSCalendar *)calendar
{
    return _calendar != nil ? _calendar : [NSCalendar currentCalendar];
}

- (void)setCalendar:(NSCalendar *)calendar
{
    if (calendar != _calendar)
    {
        [_calendar release];
        _calendar = [calendar copy];
    }
}

- (NSDate *)referenceDate
{
    return _referenceDate;
}

- (void)setReferenceDate:(NSDate *)referenceDate
{
    if (referenceDate != _referenceDate)
    {
        [_referenceDate release];
        _referenceDate = [referenceDate copy];
    }
}

static NSString *spelledNumber(long value)
{
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    NSString *result;

    [formatter setNumberStyle:NSNumberFormatterSpellOutStyle];
    result = [formatter stringFromNumber:[NSNumber numberWithLong:value]];
    [formatter release];
    return result != nil ? result : [NSString stringWithFormat:@"%ld", value];
}

- (NSString *)_stringForSeconds:(double)total
{
    NSCalendarUnit allowed = _allowedUnits;
    BOOL positional = _unitsStyle == NSDateComponentsFormatterUnitsStylePositional;
    BOOL negative = total < 0;
    double values[kUnitCount];
    BOOL used[kUnitCount];
    int first = -1, last = -1, i;
    double remaining;

    if (isnan(total) || isinf(total))
        return nil;
    if (negative)
        total = -total;

    if (allowed == 0)
    {
        allowed = NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay |
                  NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond;
        if (!positional)
            allowed |= NSCalendarUnitWeekOfMonth;
    }

    for (i = 0; i < kUnitCount; i++)
    {
        used[i] = (allowed & units[i].unit) != 0;
        if (used[i])
        {
            if (first < 0)
                first = i;
            last = i;
        }
        values[i] = 0;
    }
    if (first < 0)
        return nil;

    // whole units from the largest down, the smallest one rounded (or fractional)
    remaining = total;
    for (i = first; i <= last; i++)
    {
        if (!used[i])
            continue;
        if (i == last)
            values[i] = _allowsFractionalUnits ? remaining / units[i].seconds
                                                : floor(remaining / units[i].seconds + 0.5);
        else
        {
            values[i] = floor(remaining / units[i].seconds);
            remaining -= values[i] * units[i].seconds;
        }
    }
    // rounding up may fill the smaller units (59.6 s -> 60 s -> 1 min)
    for (i = last; i > first; i--)
    {
        int bigger = i - 1;

        while (bigger >= first && !used[bigger])
            bigger--;
        if (bigger < first || !used[i])
            continue;
        double perBigger = floor(units[bigger].seconds / units[i].seconds + 0.5);
        if (perBigger > 0 && values[i] >= perBigger &&
            fabs(units[bigger].seconds - perBigger * units[i].seconds) < 1)
        {
            values[bigger] += floor(values[i] / perBigger);
            values[i] = fmod(values[i], perBigger);
        }
    }

    // the units that show
    int shown[kUnitCount];
    int shownCount = 0;
    NSDateComponentsFormatterZeroFormattingBehavior zeros = _zeroFormattingBehavior;
    int firstNonZero = -1, lastNonZero = -1;

    for (i = first; i <= last; i++)
    {
        if (used[i] && values[i] != 0)
        {
            if (firstNonZero < 0)
                firstNonZero = i;
            lastNonZero = i;
        }
    }

    if (zeros == NSDateComponentsFormatterZeroFormattingBehaviorDefault)
        zeros = positional ? NSDateComponentsFormatterZeroFormattingBehaviorDropLeading
                           : NSDateComponentsFormatterZeroFormattingBehaviorDropAll;

    for (i = first; i <= last; i++)
    {
        if (!used[i])
            continue;
        if (values[i] == 0 && firstNonZero >= 0)
        {
            if (i < firstNonZero && (zeros & NSDateComponentsFormatterZeroFormattingBehaviorDropLeading))
                continue;
            if (i > lastNonZero && (zeros & NSDateComponentsFormatterZeroFormattingBehaviorDropTrailing))
                continue;
            if (i > firstNonZero && i < lastNonZero && (zeros & NSDateComponentsFormatterZeroFormattingBehaviorDropMiddle))
                continue;
        }
        else if (values[i] == 0 && firstNonZero < 0 && i != last && !positional)
        {
            // nothing but zeros: show only the smallest unit
            continue;
        }
        shown[shownCount++] = i;
    }
    if (positional && firstNonZero < 0)
    {
        // "0:00" rather than a lone zero
        shownCount = 0;
        if (last >= kUnitMinute && used[kUnitMinute] && last != kUnitMinute)
            shown[shownCount++] = kUnitMinute;
        shown[shownCount++] = last;
    }
    if (shownCount == 0)
        shown[shownCount++] = last;

    // "1 min 15 sec" becomes "75 sec"
    if (_collapsesLargestUnit && shownCount > 1 && values[shown[0]] == 1)
    {
        double perNext = units[shown[0]].seconds / units[shown[1]].seconds;

        values[shown[1]] += floor(perNext + 0.5);
        values[shown[0]] = 0;
        memmove(shown, shown + 1, sizeof(int) * (shownCount - 1));
        shownCount--;
    }

    if (_maximumUnitCount > 0 && shownCount > _maximumUnitCount)
        shownCount = (int) _maximumUnitCount;

    NSMutableString *result = [NSMutableString string];

    if (negative)
        [result appendString:@"-"];

    for (i = 0; i < shownCount; i++)
    {
        int unit = shown[i];
        double value = values[unit];
        BOOL one = value == 1;
        NSString *number = _allowsFractionalUnits && value != floor(value)
                                   ? [NSString stringWithFormat:@"%g", value]
                                   : [NSString stringWithFormat:@"%.0f", value];

        switch (_unitsStyle)
        {
        case NSDateComponentsFormatterUnitsStylePositional:
            if (i > 0)
                [result appendString:@":"];
            if (i > 0 || (_zeroFormattingBehavior & NSDateComponentsFormatterZeroFormattingBehaviorPad))
                [result appendFormat:@"%02.0f", value];
            else
                [result appendString:number];
            break;
        case NSDateComponentsFormatterUnitsStyleAbbreviated:
            if (i > 0)
                [result appendString:@" "];
            [result appendFormat:@"%@%s", number, units[unit].abbreviated];
            break;
        case NSDateComponentsFormatterUnitsStyleBrief:
            if (i > 0)
                [result appendString:@" "];
            [result appendFormat:@"%@%s", number, one ? units[unit].brief : units[unit].briefPlural];
            break;
        case NSDateComponentsFormatterUnitsStyleShort:
            if (i > 0)
                [result appendString:@", "];
            [result appendFormat:@"%@ %s", number, one ? units[unit].shortName : units[unit].shortPlural];
            break;
        case NSDateComponentsFormatterUnitsStyleSpellOut:
            if (i > 0)
                [result appendString:@", "];
            [result appendFormat:@"%@ %s", spelledNumber((long) value), one ? units[unit].full : units[unit].fullPlural];
            break;
        case NSDateComponentsFormatterUnitsStyleFull:
        default:
            if (i > 0)
                [result appendString:@", "];
            [result appendFormat:@"%@ %s", number, one ? units[unit].full : units[unit].fullPlural];
            break;
        }
    }

    if (_includesApproximationPhrase)
        [result insertString:@"About " atIndex:0];
    if (_includesTimeRemainingPhrase)
        [result appendString:@" remaining"];

    return result;
}

- (NSString *)stringFromTimeInterval:(NSTimeInterval)ti
{
    return [self _stringForSeconds:ti];
}

- (NSString *)stringFromDate:(NSDate *)startDate toDate:(NSDate *)endDate
{
    if (startDate == nil || endDate == nil)
        return nil;
    return [self _stringForSeconds:[endDate timeIntervalSinceDate:startDate]];
}

- (NSString *)stringFromDateComponents:(NSDateComponents *)components
{
    double total = 0;
    NSInteger value;

    if (components == nil)
        return nil;

#define ADD(getter, seconds) \
    value = [components getter]; \
    if (value != NSDateComponentUndefined) \
        total += (double) value * (seconds);

    ADD(year, units[kUnitYear].seconds)
    ADD(month, units[kUnitMonth].seconds)
    ADD(weekOfMonth, units[kUnitWeek].seconds)
    ADD(day, units[kUnitDay].seconds)
    ADD(hour, 3600)
    ADD(minute, 60)
    ADD(second, 1)
#undef ADD

    return [self _stringForSeconds:total];
}

- (NSString *)stringForObjectValue:(id)obj
{
    if ([obj isKindOfClass:[NSNumber class]])
        return [self stringFromTimeInterval:[obj doubleValue]];
    if ([obj isKindOfClass:[NSDateComponents class]])
        return [self stringFromDateComponents:obj];
    return nil;
}

- (BOOL)getObjectValue:(out id *)obj forString:(NSString *)string errorDescription:(out NSString **)error
{
    // Like Apple's, this formatter doesn't parse.
    if (error != NULL)
        *error = @"NSDateComponentsFormatter does not support parsing";
    return NO;
}

@end
