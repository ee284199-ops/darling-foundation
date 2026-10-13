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

#import <Foundation/NSLayoutConstraint.h>
#import <Foundation/NSLayoutAnchor.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSException.h>
#import <Foundation/NSKeyedArchiver.h>
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>
#include <ctype.h>
#include <stdlib.h>
#include <string.h>

#warning TODO: $ld$hide$os 10.4 through 10.7, also METACLASS

// What constraints need from their items, which AppKit implements (views and layout guides)
@interface NSObject (NSLayoutConstraintItem)
- (id) superview;
- (id) owningView;
- (void) addConstraint: (NSLayoutConstraint *) constraint;
- (void) removeConstraint: (NSLayoutConstraint *) constraint;
- (void) _layoutConstraintDidChange: (NSLayoutConstraint *) constraint;
@end

// the view an item belongs to: the view itself, or a layout guide's owning view
static id NSLayoutViewForItem(id item) {
    if (item == nil)
        return nil;
    if ([item respondsToSelector: @selector(owningView)])
        return [item owningView];
    if ([item respondsToSelector: @selector(superview)])
        return item;
    return nil;
}

// the closest view both items are in: where the constraint goes when activated
static id NSLayoutContainerForItems(id first, id second) {
    id a = NSLayoutViewForItem(first);
    id b = NSLayoutViewForItem(second);

    if (b == nil)
        return a;
    if (a == nil)
        return b;
    for (id v = a; v != nil; v = [v superview])
        for (id w = b; w != nil; w = [w superview])
            if (v == w)
                return v;
    return nil;
}

@implementation NSLayoutConstraint

+ (instancetype) constraintWithItem: (id) view1
                          attribute: (NSLayoutAttribute) attr1
                          relatedBy: (NSLayoutRelation) relation
                             toItem: (id) view2
                          attribute: (NSLayoutAttribute) attr2
                         multiplier: (CGFloat) multiplier
                           constant: (CGFloat) c
{
    if (view1 == nil || attr1 == NSLayoutAttributeNotAnAttribute)
        [NSException raise: NSInvalidArgumentException
                    format: @"NSLayoutConstraint needs a first item and attribute"];
    if ((view2 == nil) != (attr2 == NSLayoutAttributeNotAnAttribute))
        [NSException raise: NSInvalidArgumentException
                    format: @"NSLayoutConstraint: a second item needs an attribute and the other way around"];

    NSLayoutConstraint *constraint = [[[self alloc] init] autorelease];
    constraint->_firstItem = view1;
    constraint->_firstAttribute = attr1;
    constraint->_relation = relation;
    constraint->_secondItem = view2;
    constraint->_secondAttribute = attr2;
    constraint->_multiplier = multiplier;
    constraint->_constant = c;
    return constraint;
}

- (instancetype) init {
    if ((self = [super init]) != nil) {
        _multiplier = 1.0;
        _priority = NSLayoutPriorityRequired;
        _shouldBeArchived = NO;
    }
    return self;
}

- (instancetype) initWithCoder: (NSCoder *) coder {
    if ((self = [self init]) == nil)
        return nil;
    if (![coder allowsKeyedCoding])
        return self;

    _firstItem = [coder decodeObjectForKey: @"NSFirstItem"];
    _firstAttribute = [coder containsValueForKey: @"NSFirstAttributeV2"]
                    ? [coder decodeIntegerForKey: @"NSFirstAttributeV2"]
                    : [coder decodeIntegerForKey: @"NSFirstAttribute"];
    _secondItem = [coder decodeObjectForKey: @"NSSecondItem"];
    _secondAttribute = [coder containsValueForKey: @"NSSecondAttributeV2"]
                     ? [coder decodeIntegerForKey: @"NSSecondAttributeV2"]
                     : [coder decodeIntegerForKey: @"NSSecondAttribute"];
    _relation = [coder decodeIntegerForKey: @"NSRelation"];
    if ([coder containsValueForKey: @"NSMultiplier"])
        _multiplier = [coder decodeDoubleForKey: @"NSMultiplier"];
    _constant = [coder containsValueForKey: @"NSConstantV2"]
              ? [coder decodeDoubleForKey: @"NSConstantV2"]
              : [coder decodeDoubleForKey: @"NSConstant"];
    if ([coder containsValueForKey: @"NSPriority"])
        _priority = [coder decodeFloatForKey: @"NSPriority"];
    _shouldBeArchived = [coder decodeBoolForKey: @"NSShouldBeArchived"];
    _identifier = [[coder decodeObjectForKey: @"NSLayoutIdentifier"] copy];
    return self;
}

- (void) encodeWithCoder: (NSCoder *) coder {
    if (![coder allowsKeyedCoding])
        return;
    [coder encodeConditionalObject: _firstItem forKey: @"NSFirstItem"];
    [coder encodeInteger: _firstAttribute forKey: @"NSFirstAttribute"];
    [coder encodeConditionalObject: _secondItem forKey: @"NSSecondItem"];
    [coder encodeInteger: _secondAttribute forKey: @"NSSecondAttribute"];
    [coder encodeInteger: _relation forKey: @"NSRelation"];
    [coder encodeDouble: _multiplier forKey: @"NSMultiplier"];
    [coder encodeDouble: _constant forKey: @"NSConstant"];
    [coder encodeFloat: _priority forKey: @"NSPriority"];
    [coder encodeBool: _shouldBeArchived forKey: @"NSShouldBeArchived"];
    if (_identifier != nil)
        [coder encodeObject: _identifier forKey: @"NSLayoutIdentifier"];
}

- (void) dealloc {
    [_identifier release];
    [super dealloc];
}

- (NSString *) description {
    return [NSString stringWithFormat: @"<%@:%p %@.%ld %@ %@.%ld * %g + %g @%g>", [self class], self,
            [_firstItem class], (long) _firstAttribute,
            _relation == NSLayoutRelationEqual ? @"==" : (_relation < 0 ? @"<=" : @">="),
            [_secondItem class], (long) _secondAttribute, _multiplier, _constant, _priority];
}

// ---------------------------------------------------------------- properties

- (id) firstItem {
    return _firstItem;
}

- (id) secondItem {
    return _secondItem;
}

- (NSLayoutAttribute) firstAttribute {
    return _firstAttribute;
}

- (NSLayoutAttribute) secondAttribute {
    return _secondAttribute;
}

- (NSLayoutAnchor *) firstAnchor {
    return [NSLayoutAnchor _anchorWithItem: _firstItem attribute: _firstAttribute];
}

- (NSLayoutAnchor *) secondAnchor {
    if (_secondItem == nil)
        return nil;
    return [NSLayoutAnchor _anchorWithItem: _secondItem attribute: _secondAttribute];
}

- (NSLayoutRelation) relation {
    return _relation;
}

- (CGFloat) multiplier {
    return _multiplier;
}

- (CGFloat) constant {
    return _constant;
}

- (void) _changed {
    if ([_container respondsToSelector: @selector(_layoutConstraintDidChange:)])
        [_container _layoutConstraintDidChange: self];
}

- (void) setConstant: (CGFloat) constant {
    if (_constant == constant)
        return;
    _constant = constant;
    [self _changed];
}

- (NSLayoutPriority) priority {
    return _priority;
}

- (void) setPriority: (NSLayoutPriority) priority {
    _priority = priority;
    [self _changed];
}

- (BOOL) shouldBeArchived {
    return _shouldBeArchived;
}

- (void) setShouldBeArchived: (BOOL) flag {
    _shouldBeArchived = flag;
}

- (NSString *) identifier {
    return _identifier;
}

- (void) setIdentifier: (NSString *) identifier {
    identifier = [identifier copy];
    [_identifier release];
    _identifier = identifier;
}

// ---------------------------------------------------------------- activation

// AppKit's views call these when they take the constraint in or let it go
- (id) _container {
    return _container;
}

- (void) _setContainer: (id) container {
    _container = container;
}

- (BOOL) isActive {
    return _container != nil;
}

- (void) setActive: (BOOL) active {
    if (active == (_container != nil))
        return;

    if (active) {
        id container = NSLayoutContainerForItems(_firstItem, _secondItem);
        if (container == nil) {
            NSLog(@"Unable to activate %@: its items have no common ancestor", self);
            return;
        }
        [container addConstraint: self];
    } else {
        [_container removeConstraint: self];
    }
}

+ (void) activateConstraints: (NSArray *) constraints {
    for (NSLayoutConstraint *constraint in constraints)
        [constraint setActive: YES];
}

+ (void) deactivateConstraints: (NSArray *) constraints {
    for (NSLayoutConstraint *constraint in constraints)
        [constraint setActive: NO];
}

// ---------------------------------------------------------------- visual format language

typedef struct {
    NSString *format;
    const char *s;
    size_t i, n;
} NSVFLScanner;

static void vflFail(NSVFLScanner *scanner, NSString *why) {
    [NSException raise: NSInvalidArgumentException
                format: @"Unable to parse constraint format: %@ (at %lu in \"%@\")", why,
                        (unsigned long) scanner->i, scanner->format];
}

static void vflSkipSpace(NSVFLScanner *scanner) {
    while (scanner->i < scanner->n && isspace((unsigned char) scanner->s[scanner->i]))
        scanner->i++;
}

static char vflPeek(NSVFLScanner *scanner) {
    vflSkipSpace(scanner);
    return scanner->i < scanner->n ? scanner->s[scanner->i] : 0;
}

static BOOL vflConsume(NSVFLScanner *scanner, const char *token) {
    size_t length = strlen(token);

    vflSkipSpace(scanner);
    if (scanner->i + length <= scanner->n && strncmp(scanner->s + scanner->i, token, length) == 0) {
        scanner->i += length;
        return YES;
    }
    return NO;
}

static NSString *vflIdentifier(NSVFLScanner *scanner) {
    size_t start;

    vflSkipSpace(scanner);
    start = scanner->i;
    while (scanner->i < scanner->n &&
           (isalnum((unsigned char) scanner->s[scanner->i]) || scanner->s[scanner->i] == '_'))
        scanner->i++;
    if (scanner->i == start)
        return nil;
    return [[[NSString alloc] initWithBytes: scanner->s + start length: scanner->i - start
                                   encoding: NSUTF8StringEncoding] autorelease];
}

// a number or a metric's name
static BOOL vflConstant(NSVFLScanner *scanner, NSDictionary *metrics, CGFloat *value) {
    vflSkipSpace(scanner);
    if (scanner->i < scanner->n && (isdigit((unsigned char) scanner->s[scanner->i]) ||
                                    scanner->s[scanner->i] == '.' || scanner->s[scanner->i] == '-')) {
        char *end;
        *value = strtod(scanner->s + scanner->i, &end);
        scanner->i = end - scanner->s;
        return YES;
    }

    size_t start = scanner->i;
    NSString *name = vflIdentifier(scanner);
    id metric = name ? [metrics objectForKey: name] : nil;
    if (metric != nil && [metric respondsToSelector: @selector(doubleValue)]) {
        *value = [metric doubleValue];
        return YES;
    }
    scanner->i = start;
    return NO;
}

typedef struct {
    NSLayoutRelation relation;
    CGFloat constant;
    id view;            // a view the predicate relates to, for view predicates
    NSLayoutPriority priority;
} NSVFLPredicate;

// "(>=20@750, <=b)" or a lone constant; returns how many predicates were read
static NSUInteger vflPredicates(NSVFLScanner *scanner, NSDictionary *metrics, NSDictionary *views,
                                BOOL allowViews, NSVFLPredicate *predicates, NSUInteger capacity)
{
    NSUInteger count = 0;
    BOOL parenthesized = vflConsume(scanner, "(");

    do {
        NSVFLPredicate predicate = { NSLayoutRelationEqual, 0, nil, NSLayoutPriorityRequired };

        if (vflConsume(scanner, "=="))
            predicate.relation = NSLayoutRelationEqual;
        else if (vflConsume(scanner, ">="))
            predicate.relation = NSLayoutRelationGreaterThanOrEqual;
        else if (vflConsume(scanner, "<="))
            predicate.relation = NSLayoutRelationLessThanOrEqual;

        if (!vflConstant(scanner, metrics, &predicate.constant)) {
            NSString *name = vflIdentifier(scanner);
            id view = name ? [views objectForKey: name] : nil;
            if (!allowViews || view == nil)
                vflFail(scanner, [NSString stringWithFormat: @"%@ is not a key in the views or metrics dictionary", name]);
            predicate.view = view;
        }

        if (vflConsume(scanner, "@")) {
            CGFloat priority;
            if (!vflConstant(scanner, metrics, &priority))
                vflFail(scanner, @"Expected a priority");
            predicate.priority = priority;
        }

        if (count < capacity)
            predicates[count++] = predicate;
    } while (parenthesized && vflConsume(scanner, ","));

    if (parenthesized && !vflConsume(scanner, ")"))
        vflFail(scanner, @"Expected ')'");
    return count;
}

#define NSVFL_MAX_PREDICATES 8

typedef struct {
    BOOL present;      // there was a '-'
    BOOL standard;     // just '-', the standard spacing
    NSUInteger count;
    NSVFLPredicate predicates[NSVFL_MAX_PREDICATES];
} NSVFLConnection;

static NSVFLConnection vflConnection(NSVFLScanner *scanner, NSDictionary *metrics) {
    NSVFLConnection connection;

    memset(&connection, 0, sizeof(connection));
    if (!vflConsume(scanner, "-"))
        return connection; // views right next to each other

    connection.present = YES;
    char next = vflPeek(scanner);
    if (next == '[' || next == '|') {
        connection.standard = YES;
        return connection;
    }

    connection.count = vflPredicates(scanner, metrics, nil, NO, connection.predicates, NSVFL_MAX_PREDICATES);
    if (!vflConsume(scanner, "-"))
        vflFail(scanner, @"Expected '-'");
    return connection;
}

static void vflAddSpacing(NSMutableArray *constraints, NSVFLConnection *connection, BOOL toSuperview,
                          id firstItem, NSLayoutAttribute firstAttribute,
                          id secondItem, NSLayoutAttribute secondAttribute)
{
    if (!connection->present || connection->standard || connection->count == 0) {
        CGFloat spacing = !connection->present ? 0 : (toSuperview ? 20 : 8);
        [constraints addObject: [NSLayoutConstraint constraintWithItem: firstItem attribute: firstAttribute
                                                             relatedBy: NSLayoutRelationEqual
                                                                toItem: secondItem attribute: secondAttribute
                                                            multiplier: 1 constant: spacing]];
        return;
    }

    for (NSUInteger i = 0; i < connection->count; i++) {
        NSVFLPredicate *predicate = &connection->predicates[i];
        NSLayoutConstraint *constraint = [NSLayoutConstraint constraintWithItem: firstItem attribute: firstAttribute
                                                                      relatedBy: predicate->relation
                                                                         toItem: secondItem attribute: secondAttribute
                                                                     multiplier: 1 constant: predicate->constant];
        [constraint setPriority: predicate->priority];
        [constraints addObject: constraint];
    }
}

+ (NSArray *) constraintsWithVisualFormat: (NSString *) format
                                  options: (NSLayoutFormatOptions) options
                                  metrics: (NSDictionary *) metrics
                                    views: (NSDictionary *) views
{
    NSMutableArray *constraints = [NSMutableArray array];
    NSMutableArray *formatViews = [NSMutableArray array];
    NSVFLScanner scanner = { format, [format UTF8String], 0, 0 };
    BOOL vertical = NO;
    NSLayoutAttribute leading, trailing, size;
    id previous = nil;
    BOOL leadingSuperview = NO;
    NSVFLConnection pending;

    scanner.n = strlen(scanner.s);
    if (vflConsume(&scanner, "V:"))
        vertical = YES;
    else
        vflConsume(&scanner, "H:");

    if (vertical) {
        leading = NSLayoutAttributeTop;
        trailing = NSLayoutAttributeBottom;
        size = NSLayoutAttributeHeight;
    } else if ((options & NSLayoutFormatDirectionMask) == NSLayoutFormatDirectionLeftToRight) {
        leading = NSLayoutAttributeLeft;
        trailing = NSLayoutAttributeRight;
        size = NSLayoutAttributeWidth;
    } else if ((options & NSLayoutFormatDirectionMask) == NSLayoutFormatDirectionRightToLeft) {
        leading = NSLayoutAttributeRight;
        trailing = NSLayoutAttributeLeft;
        size = NSLayoutAttributeWidth;
    } else {
        leading = NSLayoutAttributeLeading;
        trailing = NSLayoutAttributeTrailing;
        size = NSLayoutAttributeWidth;
    }

    memset(&pending, 0, sizeof(pending));
    if (vflConsume(&scanner, "|")) {
        leadingSuperview = YES;
        pending = vflConnection(&scanner, metrics);
    }

    while (vflConsume(&scanner, "[")) {
        NSString *name = vflIdentifier(&scanner);
        id view = name ? [views objectForKey: name] : nil;

        if (view == nil)
            vflFail(&scanner, [NSString stringWithFormat: @"%@ is not a key in the views dictionary", name]);

        // the view's own size
        if (vflPeek(&scanner) == '(') {
            NSVFLPredicate predicates[NSVFL_MAX_PREDICATES];
            NSUInteger count = vflPredicates(&scanner, metrics, views, YES, predicates, NSVFL_MAX_PREDICATES);

            for (NSUInteger i = 0; i < count; i++) {
                NSLayoutConstraint *constraint = [NSLayoutConstraint
                        constraintWithItem: view attribute: size relatedBy: predicates[i].relation
                                    toItem: predicates[i].view
                                 attribute: predicates[i].view ? size : NSLayoutAttributeNotAnAttribute
                                multiplier: 1 constant: predicates[i].view ? 0 : predicates[i].constant];
                [constraint setPriority: predicates[i].priority];
                [constraints addObject: constraint];
            }
        }
        if (!vflConsume(&scanner, "]"))
            vflFail(&scanner, @"Expected ']'");

        if (previous != nil) {
            vflAddSpacing(constraints, &pending, NO, view, leading, previous, trailing);
        } else if (leadingSuperview) {
            id superview = [view superview];
            if (superview == nil)
                vflFail(&scanner, @"Unable to interpret '|' character, because the related view doesn't have a superview");
            vflAddSpacing(constraints, &pending, YES, view, leading, superview, leading);
        }

        [formatViews addObject: view];
        previous = view;

        pending = vflConnection(&scanner, metrics);
        if (vflConsume(&scanner, "|")) {
            id superview = [view superview];
            if (superview == nil)
                vflFail(&scanner, @"Unable to interpret '|' character, because the related view doesn't have a superview");
            vflAddSpacing(constraints, &pending, YES, superview, trailing, view, trailing);
            memset(&pending, 0, sizeof(pending));
            break;
        }
    }

    vflSkipSpace(&scanner);
    if (scanner.i < scanner.n || [formatViews count] == 0)
        vflFail(&scanner, @"Expected a view");

    // line the views up across the stack
    NSUInteger alignment = options & NSLayoutFormatAlignmentMask;
    for (NSInteger attribute = NSLayoutAttributeLeft; attribute <= NSLayoutAttributeFirstBaseline; attribute++) {
        if (!(alignment & (1 << attribute)))
            continue;
        for (NSUInteger i = 1; i < [formatViews count]; i++)
            [constraints addObject: [NSLayoutConstraint constraintWithItem: [formatViews objectAtIndex: i]
                                                                 attribute: attribute
                                                                 relatedBy: NSLayoutRelationEqual
                                                                    toItem: [formatViews objectAtIndex: i - 1]
                                                                 attribute: attribute
                                                                multiplier: 1 constant: 0]];
    }

    return constraints;
}

@end
