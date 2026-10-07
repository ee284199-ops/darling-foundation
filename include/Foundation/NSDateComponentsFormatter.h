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

#import <Foundation/NSFormatter.h>
#import <Foundation/NSCalendar.h>
#import <Foundation/NSDate.h>

@class NSDateComponents;

typedef NS_ENUM(NSInteger, NSDateComponentsFormatterUnitsStyle) {
    NSDateComponentsFormatterUnitsStylePositional = 0,
    NSDateComponentsFormatterUnitsStyleAbbreviated,
    NSDateComponentsFormatterUnitsStyleShort,
    NSDateComponentsFormatterUnitsStyleFull,
    NSDateComponentsFormatterUnitsStyleSpellOut,
    NSDateComponentsFormatterUnitsStyleBrief,
};

typedef NS_OPTIONS(NSUInteger, NSDateComponentsFormatterZeroFormattingBehavior) {
    NSDateComponentsFormatterZeroFormattingBehaviorNone = 0,
    NSDateComponentsFormatterZeroFormattingBehaviorDefault = 1 << 0,
    NSDateComponentsFormatterZeroFormattingBehaviorDropLeading = 1 << 1,
    NSDateComponentsFormatterZeroFormattingBehaviorDropMiddle = 1 << 2,
    NSDateComponentsFormatterZeroFormattingBehaviorDropTrailing = 1 << 3,
    NSDateComponentsFormatterZeroFormattingBehaviorDropAll =
            NSDateComponentsFormatterZeroFormattingBehaviorDropLeading |
            NSDateComponentsFormatterZeroFormattingBehaviorDropMiddle |
            NSDateComponentsFormatterZeroFormattingBehaviorDropTrailing,
    NSDateComponentsFormatterZeroFormattingBehaviorPad = 1 << 16,
};

@interface NSDateComponentsFormatter : NSFormatter {
    NSDateComponentsFormatterUnitsStyle _unitsStyle;
    NSCalendarUnit _allowedUnits;
    NSDateComponentsFormatterZeroFormattingBehavior _zeroFormattingBehavior;
    NSCalendar *_calendar;
    NSDate *_referenceDate;
    BOOL _allowsFractionalUnits;
    NSInteger _maximumUnitCount;
    BOOL _collapsesLargestUnit;
    BOOL _includesApproximationPhrase;
    BOOL _includesTimeRemainingPhrase;
    NSFormattingContext _formattingContext;
}

+ (NSString *)localizedStringFromDateComponents:(NSDateComponents *)components
                                      unitsStyle:(NSDateComponentsFormatterUnitsStyle)unitsStyle;

- (NSString *)stringForObjectValue:(id)obj;
- (NSString *)stringFromDateComponents:(NSDateComponents *)components;
- (NSString *)stringFromDate:(NSDate *)startDate toDate:(NSDate *)endDate;
- (NSString *)stringFromTimeInterval:(NSTimeInterval)ti;

@property NSDateComponentsFormatterUnitsStyle unitsStyle;
@property NSCalendarUnit allowedUnits;
@property NSDateComponentsFormatterZeroFormattingBehavior zeroFormattingBehavior;
@property (copy) NSCalendar *calendar;
@property (copy) NSDate *referenceDate;
@property BOOL allowsFractionalUnits;
@property NSInteger maximumUnitCount;
@property BOOL collapsesLargestUnit;
@property BOOL includesApproximationPhrase;
@property BOOL includesTimeRemainingPhrase;
@property NSFormattingContext formattingContext;

@end
