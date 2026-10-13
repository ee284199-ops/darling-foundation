/*
 This file is part of Darling.

 Copyright (C) 2025 Darling Developers

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

#import <Foundation/Foundation.h>
#import <Foundation/NSLayoutConstraint.h>

// An attribute of a view or layout guide that constraints can relate.
@interface NSLayoutAnchor : NSObject <NSCopying> {
    id _item;
    NSLayoutAttribute _attribute;
}

// for AppKit, which hands these out
+ (instancetype) _anchorWithItem: (id) item attribute: (NSLayoutAttribute) attribute;

- (id) item;
- (NSLayoutAttribute) _attribute;
- (NSString *) name;
- (BOOL) hasAmbiguousLayout;
- (NSArray *) constraintsAffectingLayout;

- (NSLayoutConstraint *) constraintEqualToAnchor: (NSLayoutAnchor *) anchor;
- (NSLayoutConstraint *) constraintGreaterThanOrEqualToAnchor: (NSLayoutAnchor *) anchor;
- (NSLayoutConstraint *) constraintLessThanOrEqualToAnchor: (NSLayoutAnchor *) anchor;
- (NSLayoutConstraint *) constraintEqualToAnchor: (NSLayoutAnchor *) anchor constant: (CGFloat) c;
- (NSLayoutConstraint *) constraintGreaterThanOrEqualToAnchor: (NSLayoutAnchor *) anchor constant: (CGFloat) c;
- (NSLayoutConstraint *) constraintLessThanOrEqualToAnchor: (NSLayoutAnchor *) anchor constant: (CGFloat) c;

@end

@class NSLayoutDimension;

@interface NSLayoutXAxisAnchor : NSLayoutAnchor
- (NSLayoutDimension *) anchorWithOffsetToAnchor: (NSLayoutXAxisAnchor *) otherAnchor;
- (NSLayoutConstraint *) constraintEqualToSystemSpacingAfterAnchor: (NSLayoutXAxisAnchor *) anchor multiplier: (CGFloat) multiplier;
- (NSLayoutConstraint *) constraintGreaterThanOrEqualToSystemSpacingAfterAnchor: (NSLayoutXAxisAnchor *) anchor multiplier: (CGFloat) multiplier;
- (NSLayoutConstraint *) constraintLessThanOrEqualToSystemSpacingAfterAnchor: (NSLayoutXAxisAnchor *) anchor multiplier: (CGFloat) multiplier;
@end

@interface NSLayoutYAxisAnchor : NSLayoutAnchor
- (NSLayoutDimension *) anchorWithOffsetToAnchor: (NSLayoutYAxisAnchor *) otherAnchor;
- (NSLayoutConstraint *) constraintEqualToSystemSpacingBelowAnchor: (NSLayoutYAxisAnchor *) anchor multiplier: (CGFloat) multiplier;
- (NSLayoutConstraint *) constraintGreaterThanOrEqualToSystemSpacingBelowAnchor: (NSLayoutYAxisAnchor *) anchor multiplier: (CGFloat) multiplier;
- (NSLayoutConstraint *) constraintLessThanOrEqualToSystemSpacingBelowAnchor: (NSLayoutYAxisAnchor *) anchor multiplier: (CGFloat) multiplier;
@end

@interface NSLayoutDimension : NSLayoutAnchor
- (NSLayoutConstraint *) constraintEqualToConstant: (CGFloat) c;
- (NSLayoutConstraint *) constraintGreaterThanOrEqualToConstant: (CGFloat) c;
- (NSLayoutConstraint *) constraintLessThanOrEqualToConstant: (CGFloat) c;
- (NSLayoutConstraint *) constraintEqualToAnchor: (NSLayoutDimension *) anchor multiplier: (CGFloat) m;
- (NSLayoutConstraint *) constraintGreaterThanOrEqualToAnchor: (NSLayoutDimension *) anchor multiplier: (CGFloat) m;
- (NSLayoutConstraint *) constraintLessThanOrEqualToAnchor: (NSLayoutDimension *) anchor multiplier: (CGFloat) m;
- (NSLayoutConstraint *) constraintEqualToAnchor: (NSLayoutDimension *) anchor multiplier: (CGFloat) m constant: (CGFloat) c;
- (NSLayoutConstraint *) constraintGreaterThanOrEqualToAnchor: (NSLayoutDimension *) anchor multiplier: (CGFloat) m constant: (CGFloat) c;
- (NSLayoutConstraint *) constraintLessThanOrEqualToAnchor: (NSLayoutDimension *) anchor multiplier: (CGFloat) m constant: (CGFloat) c;
@end
