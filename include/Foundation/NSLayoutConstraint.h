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

#ifndef _FOUNDATION_NSLAYOUTCONSTRAINT_H_
#define _FOUNDATION_NSLAYOUTCONSTRAINT_H_

#import <Foundation/NSObject.h>
#import <Foundation/NSGeometry.h>

@class NSArray, NSDictionary, NSString, NSLayoutAnchor;

typedef float NSLayoutPriority;
static const NSLayoutPriority NSLayoutPriorityRequired = 1000;
static const NSLayoutPriority NSLayoutPriorityDefaultHigh = 750;
static const NSLayoutPriority NSLayoutPriorityDragThatCanResizeWindow = 510;
static const NSLayoutPriority NSLayoutPriorityWindowSizeStayPut = 500;
static const NSLayoutPriority NSLayoutPriorityDragThatCannotResizeWindow = 490;
static const NSLayoutPriority NSLayoutPriorityDefaultLow = 250;
static const NSLayoutPriority NSLayoutPriorityFittingSizeCompression = 50;

typedef NS_ENUM(NSInteger, NSLayoutConstraintOrientation) {
    NSLayoutConstraintOrientationHorizontal = 0,
    NSLayoutConstraintOrientationVertical = 1,
};

typedef NS_ENUM(NSInteger, NSLayoutRelation) {
    NSLayoutRelationLessThanOrEqual = -1,
    NSLayoutRelationEqual = 0,
    NSLayoutRelationGreaterThanOrEqual = 1,
};

typedef NS_ENUM(NSInteger, NSLayoutAttribute) {
    NSLayoutAttributeLeft = 1,
    NSLayoutAttributeRight,
    NSLayoutAttributeTop,
    NSLayoutAttributeBottom,
    NSLayoutAttributeLeading,
    NSLayoutAttributeTrailing,
    NSLayoutAttributeWidth,
    NSLayoutAttributeHeight,
    NSLayoutAttributeCenterX,
    NSLayoutAttributeCenterY,
    NSLayoutAttributeLastBaseline,
    NSLayoutAttributeBaseline = NSLayoutAttributeLastBaseline,
    NSLayoutAttributeFirstBaseline,
    NSLayoutAttributeNotAnAttribute = 0,
};

typedef NS_OPTIONS(NSUInteger, NSLayoutFormatOptions) {
    NSLayoutFormatAlignAllLeft = (1 << NSLayoutAttributeLeft),
    NSLayoutFormatAlignAllRight = (1 << NSLayoutAttributeRight),
    NSLayoutFormatAlignAllTop = (1 << NSLayoutAttributeTop),
    NSLayoutFormatAlignAllBottom = (1 << NSLayoutAttributeBottom),
    NSLayoutFormatAlignAllLeading = (1 << NSLayoutAttributeLeading),
    NSLayoutFormatAlignAllTrailing = (1 << NSLayoutAttributeTrailing),
    NSLayoutFormatAlignAllCenterX = (1 << NSLayoutAttributeCenterX),
    NSLayoutFormatAlignAllCenterY = (1 << NSLayoutAttributeCenterY),
    NSLayoutFormatAlignAllLastBaseline = (1 << NSLayoutAttributeLastBaseline),
    NSLayoutFormatAlignAllFirstBaseline = (1 << NSLayoutAttributeFirstBaseline),
    NSLayoutFormatAlignAllBaseline = NSLayoutFormatAlignAllLastBaseline,
    NSLayoutFormatAlignmentMask = 0xFFFF,
    NSLayoutFormatDirectionLeadingToTrailing = 0 << 16,
    NSLayoutFormatDirectionLeftToRight = 1 << 16,
    NSLayoutFormatDirectionRightToLeft = 2 << 16,
    NSLayoutFormatDirectionMask = 0x3 << 16,
};

// A linear relation between attributes of two items (views or layout guides):
// first.attribute <relation> second.attribute * multiplier + constant.
// Items aren't retained: the views own their constraints.
@interface NSLayoutConstraint : NSObject <NSCoding> {
    id _firstItem;
    id _secondItem;
    NSLayoutAttribute _firstAttribute;
    NSLayoutAttribute _secondAttribute;
    NSLayoutRelation _relation;
    CGFloat _multiplier;
    CGFloat _constant;
    NSLayoutPriority _priority;
    BOOL _shouldBeArchived;
    NSString *_identifier;
    // the view the constraint was added to, while it's active
    id _container;
}

+ (NSArray *) constraintsWithVisualFormat: (NSString *) format
                                  options: (NSLayoutFormatOptions) options
                                  metrics: (NSDictionary *) metrics
                                    views: (NSDictionary *) views;
+ (instancetype) constraintWithItem: (id) view1
                          attribute: (NSLayoutAttribute) attr1
                          relatedBy: (NSLayoutRelation) relation
                             toItem: (id) view2
                          attribute: (NSLayoutAttribute) attr2
                         multiplier: (CGFloat) multiplier
                           constant: (CGFloat) c;
+ (void) activateConstraints: (NSArray *) constraints;
+ (void) deactivateConstraints: (NSArray *) constraints;

- (NSLayoutPriority) priority;
- (void) setPriority: (NSLayoutPriority) priority;
- (BOOL) shouldBeArchived;
- (void) setShouldBeArchived: (BOOL) flag;
- (id) firstItem;
- (id) secondItem;
- (NSLayoutAttribute) firstAttribute;
- (NSLayoutAttribute) secondAttribute;
- (NSLayoutAnchor *) firstAnchor;
- (NSLayoutAnchor *) secondAnchor;
- (NSLayoutRelation) relation;
- (CGFloat) multiplier;
- (CGFloat) constant;
- (void) setConstant: (CGFloat) constant;
- (BOOL) isActive;
- (void) setActive: (BOOL) active;
- (NSString *) identifier;
- (void) setIdentifier: (NSString *) identifier;

@end

#endif
