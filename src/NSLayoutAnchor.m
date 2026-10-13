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

#import <Foundation/NSLayoutAnchor.h>

@interface NSLayoutAnchor ()
- (NSLayoutConstraint *) _constraintTo: (NSLayoutAnchor *) anchor relation: (NSLayoutRelation) relation
                            multiplier: (CGFloat) multiplier constant: (CGFloat) c;
@end

@implementation NSLayoutAnchor

static Class NSLayoutAnchorClassForAttribute(NSLayoutAttribute attribute) {
    switch (attribute) {
    case NSLayoutAttributeLeft:
    case NSLayoutAttributeRight:
    case NSLayoutAttributeLeading:
    case NSLayoutAttributeTrailing:
    case NSLayoutAttributeCenterX:
        return [NSLayoutXAxisAnchor class];
    case NSLayoutAttributeWidth:
    case NSLayoutAttributeHeight:
        return [NSLayoutDimension class];
    default:
        return [NSLayoutYAxisAnchor class];
    }
}

+ (instancetype) _anchorWithItem: (id) item attribute: (NSLayoutAttribute) attribute {
    Class cls = (self == [NSLayoutAnchor class]) ? NSLayoutAnchorClassForAttribute(attribute) : self;
    NSLayoutAnchor *anchor = [[[cls alloc] init] autorelease];

    anchor->_item = item;
    anchor->_attribute = attribute;
    return anchor;
}

- (id) copyWithZone: (NSZone *) zone {
    return [self retain];
}

- (BOOL) isEqual: (id) other {
    if (![other isKindOfClass: [NSLayoutAnchor class]])
        return NO;
    return ((NSLayoutAnchor *) other)->_item == _item && ((NSLayoutAnchor *) other)->_attribute == _attribute;
}

- (NSUInteger) hash {
    return (NSUInteger) _item ^ (NSUInteger) _attribute;
}

- (id) item {
    return _item;
}

- (NSLayoutAttribute) _attribute {
    return _attribute;
}

- (NSString *) name {
    static NSString *const names[] = {
        @"notAnAttribute", @"left", @"right", @"top", @"bottom", @"leading", @"trailing",
        @"width", @"height", @"centerX", @"centerY", @"lastBaseline", @"firstBaseline",
    };
    if (_attribute >= 0 && _attribute <= NSLayoutAttributeFirstBaseline)
        return names[_attribute];
    return @"unknown";
}

- (NSString *) description {
    return [NSString stringWithFormat: @"<%@:%p %@.%@>", [self class], self, [_item class], [self name]];
}

- (BOOL) hasAmbiguousLayout {
    return NO;
}

- (NSArray *) constraintsAffectingLayout {
    return [NSArray array];
}

- (NSLayoutConstraint *) _constraintTo: (NSLayoutAnchor *) anchor relation: (NSLayoutRelation) relation
                            multiplier: (CGFloat) multiplier constant: (CGFloat) c
{
    return [NSLayoutConstraint constraintWithItem: _item attribute: _attribute relatedBy: relation
                                           toItem: anchor ? anchor->_item : nil
                                        attribute: anchor ? anchor->_attribute : NSLayoutAttributeNotAnAttribute
                                       multiplier: multiplier constant: c];
}

- (NSLayoutConstraint *) constraintEqualToAnchor: (NSLayoutAnchor *) anchor {
    return [self _constraintTo: anchor relation: NSLayoutRelationEqual multiplier: 1 constant: 0];
}

- (NSLayoutConstraint *) constraintGreaterThanOrEqualToAnchor: (NSLayoutAnchor *) anchor {
    return [self _constraintTo: anchor relation: NSLayoutRelationGreaterThanOrEqual multiplier: 1 constant: 0];
}

- (NSLayoutConstraint *) constraintLessThanOrEqualToAnchor: (NSLayoutAnchor *) anchor {
    return [self _constraintTo: anchor relation: NSLayoutRelationLessThanOrEqual multiplier: 1 constant: 0];
}

- (NSLayoutConstraint *) constraintEqualToAnchor: (NSLayoutAnchor *) anchor constant: (CGFloat) c {
    return [self _constraintTo: anchor relation: NSLayoutRelationEqual multiplier: 1 constant: c];
}

- (NSLayoutConstraint *) constraintGreaterThanOrEqualToAnchor: (NSLayoutAnchor *) anchor constant: (CGFloat) c {
    return [self _constraintTo: anchor relation: NSLayoutRelationGreaterThanOrEqual multiplier: 1 constant: c];
}

- (NSLayoutConstraint *) constraintLessThanOrEqualToAnchor: (NSLayoutAnchor *) anchor constant: (CGFloat) c {
    return [self _constraintTo: anchor relation: NSLayoutRelationLessThanOrEqual multiplier: 1 constant: c];
}

@end

// The distance between two anchors, as a dimension. Constraints on it can't be expressed with
// a single NSLayoutConstraint, so this only remembers the anchors.
@interface NSLayoutOffsetDimension : NSLayoutDimension {
@public
    NSLayoutAnchor *_from;
    NSLayoutAnchor *_to;
}
@end

@implementation NSLayoutOffsetDimension
- (void) dealloc {
    [_from release];
    [_to release];
    [super dealloc];
}
@end

static NSLayoutDimension *NSLayoutOffsetBetween(NSLayoutAnchor *from, NSLayoutAnchor *to) {
    NSLayoutOffsetDimension *dimension = [NSLayoutOffsetDimension _anchorWithItem: [from item]
                                                                         attribute: NSLayoutAttributeWidth];
    dimension->_from = [from retain];
    dimension->_to = [to retain];
    return dimension;
}

@implementation NSLayoutXAxisAnchor

- (NSLayoutDimension *) anchorWithOffsetToAnchor: (NSLayoutXAxisAnchor *) otherAnchor {
    return NSLayoutOffsetBetween(self, otherAnchor);
}

// the system spacing between sibling views is 8 points
- (NSLayoutConstraint *) constraintEqualToSystemSpacingAfterAnchor: (NSLayoutXAxisAnchor *) anchor multiplier: (CGFloat) multiplier {
    return [self _constraintTo: anchor relation: NSLayoutRelationEqual multiplier: 1 constant: 8 * multiplier];
}

- (NSLayoutConstraint *) constraintGreaterThanOrEqualToSystemSpacingAfterAnchor: (NSLayoutXAxisAnchor *) anchor multiplier: (CGFloat) multiplier {
    return [self _constraintTo: anchor relation: NSLayoutRelationGreaterThanOrEqual multiplier: 1 constant: 8 * multiplier];
}

- (NSLayoutConstraint *) constraintLessThanOrEqualToSystemSpacingAfterAnchor: (NSLayoutXAxisAnchor *) anchor multiplier: (CGFloat) multiplier {
    return [self _constraintTo: anchor relation: NSLayoutRelationLessThanOrEqual multiplier: 1 constant: 8 * multiplier];
}

@end

@implementation NSLayoutYAxisAnchor

- (NSLayoutDimension *) anchorWithOffsetToAnchor: (NSLayoutYAxisAnchor *) otherAnchor {
    return NSLayoutOffsetBetween(self, otherAnchor);
}

- (NSLayoutConstraint *) constraintEqualToSystemSpacingBelowAnchor: (NSLayoutYAxisAnchor *) anchor multiplier: (CGFloat) multiplier {
    return [self _constraintTo: anchor relation: NSLayoutRelationEqual multiplier: 1 constant: 8 * multiplier];
}

- (NSLayoutConstraint *) constraintGreaterThanOrEqualToSystemSpacingBelowAnchor: (NSLayoutYAxisAnchor *) anchor multiplier: (CGFloat) multiplier {
    return [self _constraintTo: anchor relation: NSLayoutRelationGreaterThanOrEqual multiplier: 1 constant: 8 * multiplier];
}

- (NSLayoutConstraint *) constraintLessThanOrEqualToSystemSpacingBelowAnchor: (NSLayoutYAxisAnchor *) anchor multiplier: (CGFloat) multiplier {
    return [self _constraintTo: anchor relation: NSLayoutRelationLessThanOrEqual multiplier: 1 constant: 8 * multiplier];
}

@end

@implementation NSLayoutDimension

- (NSLayoutConstraint *) constraintEqualToConstant: (CGFloat) c {
    return [self _constraintTo: nil relation: NSLayoutRelationEqual multiplier: 0 constant: c];
}

- (NSLayoutConstraint *) constraintGreaterThanOrEqualToConstant: (CGFloat) c {
    return [self _constraintTo: nil relation: NSLayoutRelationGreaterThanOrEqual multiplier: 0 constant: c];
}

- (NSLayoutConstraint *) constraintLessThanOrEqualToConstant: (CGFloat) c {
    return [self _constraintTo: nil relation: NSLayoutRelationLessThanOrEqual multiplier: 0 constant: c];
}

- (NSLayoutConstraint *) constraintEqualToAnchor: (NSLayoutDimension *) anchor multiplier: (CGFloat) m {
    return [self _constraintTo: anchor relation: NSLayoutRelationEqual multiplier: m constant: 0];
}

- (NSLayoutConstraint *) constraintGreaterThanOrEqualToAnchor: (NSLayoutDimension *) anchor multiplier: (CGFloat) m {
    return [self _constraintTo: anchor relation: NSLayoutRelationGreaterThanOrEqual multiplier: m constant: 0];
}

- (NSLayoutConstraint *) constraintLessThanOrEqualToAnchor: (NSLayoutDimension *) anchor multiplier: (CGFloat) m {
    return [self _constraintTo: anchor relation: NSLayoutRelationLessThanOrEqual multiplier: m constant: 0];
}

- (NSLayoutConstraint *) constraintEqualToAnchor: (NSLayoutDimension *) anchor multiplier: (CGFloat) m constant: (CGFloat) c {
    return [self _constraintTo: anchor relation: NSLayoutRelationEqual multiplier: m constant: c];
}

- (NSLayoutConstraint *) constraintGreaterThanOrEqualToAnchor: (NSLayoutDimension *) anchor multiplier: (CGFloat) m constant: (CGFloat) c {
    return [self _constraintTo: anchor relation: NSLayoutRelationGreaterThanOrEqual multiplier: m constant: c];
}

- (NSLayoutConstraint *) constraintLessThanOrEqualToAnchor: (NSLayoutDimension *) anchor multiplier: (CGFloat) m constant: (CGFloat) c {
    return [self _constraintTo: anchor relation: NSLayoutRelationLessThanOrEqual multiplier: m constant: c];
}

@end
