//
//  NSIndexSet.m
//  Foundation
//
//  Rewritten for the Darling project.
//
//  An NSIndexSet stores its indexes in a malloc'ed array of NSRange
//  structures kept sorted by location. The ranges are disjoint and never
//  adjacent: every mutation merges ranges that touch, so a set that is
//  built one index at a time collapses into the fewest possible ranges.
//  Lookups use binary search over the range array.
//
//  Only indexes below NSNotFound are stored, therefore the exclusive end
//  (location + length) of a stored range never exceeds NSNotFound and can
//  never overflow a NSUInteger.
//

#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#import <Foundation/NSIndexSet.h>
#import <Foundation/NSString.h>
#import <Foundation/NSException.h>
#import <Foundation/NSCoder.h>
#import <Foundation/NSData.h>

typedef void (^IndexSetEnumerateBlock)(NSUInteger idx, BOOL *stop);
typedef BOOL (^IndexSetPredicateBlock)(NSUInteger idx, BOOL *stop);
typedef void (^IndexSetRangeBlock)(NSRange range, BOOL *stop);

@interface NSIndexSet ()

- (NSUInteger)rangeCount;
- (void)_enumerateIndexesInRange:(NSRange)range options:(NSEnumerationOptions)options usingBlock:(IndexSetEnumerateBlock)block;
- (NSUInteger)_indexInRange:(NSRange)range options:(NSEnumerationOptions)options passingTest:(IndexSetPredicateBlock)predicate;
- (NSIndexSet *)_indexesInRange:(NSRange)range options:(NSEnumerationOptions)options passingTest:(IndexSetPredicateBlock)predicate;
- (void)_enumerateRangesInRange:(NSRange)range options:(NSEnumerationOptions)options usingBlock:(IndexSetRangeBlock)block;

@end

// Exclusive end of a stored range. Never overflows, see file comment.
static NSUInteger NSIndexSetRangeEnd(NSRange range)
{
    return range.location + range.length;
}

// Exclusive end of an arbitrary caller-supplied range, capped at NSNotFound.
static NSUInteger NSIndexSetRangeBound(NSRange range)
{
    if (range.location >= NSNotFound)
    {
        return NSNotFound;
    }
    if (range.length >= NSNotFound - range.location)
    {
        return NSNotFound;
    }
    return range.location + range.length;
}

static BOOL NSIndexSetRangeIsValid(NSRange range)
{
    return range.location <= NSNotFound && range.length <= NSNotFound - range.location;
}

static void NSIndexSetEnsureCapacity(NSIndexSet *self, NSUInteger needed)
{
    if (self->_capacity >= needed)
    {
        return;
    }

    NSUInteger newCapacity = self->_capacity > 0 ? self->_capacity : 4;
    while (newCapacity < needed)
    {
        if (newCapacity > ((NSUInteger)-1) / (2 * sizeof(NSRange)))
        {
            newCapacity = needed;
            break;
        }
        newCapacity *= 2;
    }

    NSRange *newRanges = (NSRange *)realloc(self->_ranges, newCapacity * sizeof(NSRange));
    if (newRanges == NULL)
    {
        [NSException raise:NSMallocException format:@"Unable to grow NSIndexSet range storage"];
    }
    self->_ranges = newRanges;
    self->_capacity = newCapacity;
}

// First slot whose exclusive end is >= value (self->_rangeCount if none).
static NSUInteger NSIndexSetFindRangeWithEndAtLeast(NSIndexSet *self, NSUInteger value)
{
    NSUInteger low = 0;
    NSUInteger high = self->_rangeCount;
    while (low < high)
    {
        NSUInteger mid = low + (high - low) / 2;
        if (NSIndexSetRangeEnd(self->_ranges[mid]) >= value)
        {
            high = mid;
        }
        else
        {
            low = mid + 1;
        }
    }
    return low;
}

// First slot whose exclusive end is > value (self->_rangeCount if none).
static NSUInteger NSIndexSetFindRangeWithEndGreaterThan(NSIndexSet *self, NSUInteger value)
{
    NSUInteger low = 0;
    NSUInteger high = self->_rangeCount;
    while (low < high)
    {
        NSUInteger mid = low + (high - low) / 2;
        if (NSIndexSetRangeEnd(self->_ranges[mid]) > value)
        {
            high = mid;
        }
        else
        {
            low = mid + 1;
        }
    }
    return low;
}

// First slot whose location is >= value (self->_rangeCount if none).
static NSUInteger NSIndexSetFindRangeWithLocationAtLeast(NSIndexSet *self, NSUInteger value)
{
    NSUInteger low = 0;
    NSUInteger high = self->_rangeCount;
    while (low < high)
    {
        NSUInteger mid = low + (high - low) / 2;
        if (self->_ranges[mid].location >= value)
        {
            high = mid;
        }
        else
        {
            low = mid + 1;
        }
    }
    return low;
}

// First slot whose location is > value (self->_rangeCount if none).
static NSUInteger NSIndexSetFindRangeWithLocationGreaterThan(NSIndexSet *self, NSUInteger value)
{
    NSUInteger low = 0;
    NSUInteger high = self->_rangeCount;
    while (low < high)
    {
        NSUInteger mid = low + (high - low) / 2;
        if (self->_ranges[mid].location > value)
        {
            high = mid;
        }
        else
        {
            low = mid + 1;
        }
    }
    return low;
}

static void NSIndexSetAddRange(NSIndexSet *self, NSRange range)
{
    if (range.length == 0)
    {
        return;
    }
    if (!NSIndexSetRangeIsValid(range))
    {
        [NSException raise:NSRangeException format:@"range {%lu, %lu} extends past NSNotFound",
            (unsigned long)range.location, (unsigned long)range.length];
    }

    NSUInteger start = range.location;
    NSUInteger end = range.location + range.length;

    NSUInteger first = NSIndexSetFindRangeWithEndAtLeast(self, start);
    NSUInteger last = NSIndexSetFindRangeWithLocationGreaterThan(self, end);

    if (first == last)
    {
        NSIndexSetEnsureCapacity(self, self->_rangeCount + 1);
        if (self->_rangeCount > first)
        {
            memmove(&self->_ranges[first + 1], &self->_ranges[first], (self->_rangeCount - first) * sizeof(NSRange));
        }
        self->_ranges[first] = NSMakeRange(start, end - start);
        self->_rangeCount++;
        self->_count += end - start;
        return;
    }

    NSUInteger covered = 0;
    for (NSUInteger i = first; i < last; i++)
    {
        covered += self->_ranges[i].length;
    }

    NSUInteger newStart = MIN(start, self->_ranges[first].location);
    NSUInteger newEnd = MAX(end, NSIndexSetRangeEnd(self->_ranges[last - 1]));
    self->_ranges[first] = NSMakeRange(newStart, newEnd - newStart);

    if (last - first > 1)
    {
        if (self->_rangeCount > last)
        {
            memmove(&self->_ranges[first + 1], &self->_ranges[last], (self->_rangeCount - last) * sizeof(NSRange));
        }
        self->_rangeCount -= last - first - 1;
    }
    self->_count += (newEnd - newStart) - covered;
}

static void NSIndexSetRemoveRange(NSIndexSet *self, NSRange range)
{
    if (range.length == 0)
    {
        return;
    }
    if (!NSIndexSetRangeIsValid(range))
    {
        [NSException raise:NSRangeException format:@"range {%lu, %lu} extends past NSNotFound",
            (unsigned long)range.location, (unsigned long)range.length];
    }
    if (self->_rangeCount == 0)
    {
        return;
    }

    NSUInteger start = range.location;
    NSUInteger end = range.location + range.length;

    NSUInteger first = NSIndexSetFindRangeWithEndGreaterThan(self, start);
    NSUInteger last = NSIndexSetFindRangeWithLocationAtLeast(self, end);
    if (first >= last)
    {
        return;
    }

    NSUInteger oldRangeCount = self->_rangeCount;
    // At most one range can be split in two.
    NSRange *result = (NSRange *)malloc((oldRangeCount + 1) * sizeof(NSRange));
    if (result == NULL)
    {
        [NSException raise:NSMallocException format:@"Unable to grow NSIndexSet range storage"];
    }

    NSUInteger count = 0;
    NSUInteger newCount = self->_count;

    for (NSUInteger i = 0; i < first; i++)
    {
        result[count++] = self->_ranges[i];
    }

    for (NSUInteger i = first; i < last; i++)
    {
        NSRange entry = self->_ranges[i];
        NSUInteger entryEnd = NSIndexSetRangeEnd(entry);
        NSUInteger overlapStart = MAX(entry.location, start);
        NSUInteger overlapEnd = MIN(entryEnd, end);

        if (start <= entry.location)
        {
            if (end >= entryEnd)
            {
                // The whole range was removed.
                newCount -= entry.length;
                continue;
            }
            // The head of the range was removed.
            newCount -= overlapEnd - entry.location;
            result[count++] = NSMakeRange(end, entryEnd - end);
        }
        else if (end >= entryEnd)
        {
            // The tail of the range was removed.
            newCount -= entryEnd - overlapStart;
            result[count++] = NSMakeRange(entry.location, overlapStart - entry.location);
        }
        else
        {
            // The middle of the range was removed: split it in two.
            newCount -= overlapEnd - overlapStart;
            result[count++] = NSMakeRange(entry.location, overlapStart - entry.location);
            result[count++] = NSMakeRange(end, entryEnd - end);
        }
    }

    for (NSUInteger i = last; i < oldRangeCount; i++)
    {
        result[count++] = self->_ranges[i];
    }

    free(self->_ranges);
    self->_ranges = result;
    self->_rangeCount = count;
    self->_capacity = oldRangeCount + 1;
    self->_count = newCount;
}

typedef struct {
    NSRange *ranges;
    NSUInteger count;
    NSUInteger capacity;
} NSIndexSetBuilder;

static void NSIndexSetBuilderAppend(NSIndexSetBuilder *builder, NSRange range)
{
    if (range.length == 0)
    {
        return;
    }

    if (builder->count > 0)
    {
        NSRange *last = &builder->ranges[builder->count - 1];
        if (NSIndexSetRangeEnd(*last) >= range.location)
        {
            NSUInteger end = MAX(NSIndexSetRangeEnd(*last), NSIndexSetRangeEnd(range));
            last->length = end - last->location;
            return;
        }
    }

    if (builder->count == builder->capacity)
    {
        NSUInteger newCapacity = builder->capacity > 0 ? builder->capacity * 2 : 8;
        NSRange *newRanges = (NSRange *)realloc(builder->ranges, newCapacity * sizeof(NSRange));
        if (newRanges == NULL)
        {
            [NSException raise:NSMallocException format:@"Unable to grow NSIndexSet range storage"];
        }
        builder->ranges = newRanges;
        builder->capacity = newCapacity;
    }
    builder->ranges[builder->count++] = range;
}

static void NSIndexSetAppendVarint(uint8_t *bytes, NSUInteger *offset, uint64_t value)
{
    do
    {
        uint8_t byte = (uint8_t)(value & 0x7F);
        value >>= 7;
        if (value != 0)
        {
            byte |= 0x80;
        }
        bytes[(*offset)++] = byte;
    } while (value != 0);
}

static BOOL NSIndexSetDecodeVarint(const uint8_t *bytes, NSUInteger length, NSUInteger *offset, uint64_t *outValue)
{
    uint64_t value = 0;
    unsigned shift = 0;
    NSUInteger position = *offset;

    while (position < length)
    {
        uint8_t byte = bytes[position++];
        if (shift > 63)
        {
            return NO;
        }
        value |= (uint64_t)(byte & 0x7F) << shift;
        if ((byte & 0x80) == 0)
        {
            *offset = position;
            *outValue = value;
            return YES;
        }
        shift += 7;
    }

    return NO;
}

@implementation NSIndexSet

+ (BOOL)supportsSecureCoding
{
    return YES;
}

+ (instancetype)indexSet
{
    return [[[self alloc] init] autorelease];
}

+ (instancetype)indexSetWithIndex:(NSUInteger)value
{
    return [[[self alloc] initWithIndex:value] autorelease];
}

+ (instancetype)indexSetWithIndexesInRange:(NSRange)range
{
    return [[[self alloc] initWithIndexesInRange:range] autorelease];
}

- (instancetype)init
{
    return [self initWithIndexesInRange:NSMakeRange(0, 0)];
}

- (instancetype)initWithIndex:(NSUInteger)value
{
    return [self initWithIndexesInRange:NSMakeRange(value, 1)];
}

- (instancetype)initWithIndexesInRange:(NSRange)range
{
    self = [super init];
    if (self != nil)
    {
        NSIndexSetAddRange(self, range);
    }
    return self;
}

- (instancetype)initWithIndexSet:(NSIndexSet *)indexSet
{
    self = [super init];
    if (self != nil && indexSet != nil && indexSet->_rangeCount > 0)
    {
        NSIndexSetEnsureCapacity(self, indexSet->_rangeCount);
        memcpy(self->_ranges, indexSet->_ranges, indexSet->_rangeCount * sizeof(NSRange));
        self->_rangeCount = indexSet->_rangeCount;
        self->_count = indexSet->_count;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self == nil)
    {
        return nil;
    }

    if ([coder allowsKeyedCoding])
    {
        int64_t rangeCount = 0;
        if ([coder containsValueForKey:@"NSRangeCount"])
        {
            rangeCount = [coder decodeInt64ForKey:@"NSRangeCount"];
        }

        if (rangeCount == 1)
        {
            int64_t location = 0;
            int64_t length = 0;
            if ([coder containsValueForKey:@"NSLocation"])
            {
                location = [coder decodeInt64ForKey:@"NSLocation"];
            }
            if ([coder containsValueForKey:@"NSLength"])
            {
                length = [coder decodeInt64ForKey:@"NSLength"];
            }
            if (location >= 0 && length >= 0 &&
                (uint64_t)location <= NSNotFound && (uint64_t)length <= NSNotFound &&
                (uint64_t)location + (uint64_t)length <= NSNotFound)
            {
                NSIndexSetAddRange(self, NSMakeRange((NSUInteger)location, (NSUInteger)length));
            }
        }
        else if (rangeCount > 1)
        {
            NSData *data = [coder decodeObjectForKey:@"NSRangeData"];
            if (data != nil)
            {
                const uint8_t *bytes = [data bytes];
                NSUInteger dataLength = [data length];
                NSUInteger offset = 0;

                for (int64_t i = 0; i < rangeCount; i++)
                {
                    uint64_t location = 0;
                    uint64_t length = 0;
                    if (!NSIndexSetDecodeVarint(bytes, dataLength, &offset, &location))
                    {
                        break;
                    }
                    if (!NSIndexSetDecodeVarint(bytes, dataLength, &offset, &length))
                    {
                        break;
                    }
                    if (location <= NSNotFound && length <= NSNotFound && location + length <= NSNotFound)
                    {
                        NSIndexSetAddRange(self, NSMakeRange((NSUInteger)location, (NSUInteger)length));
                    }
                }
            }
        }
    }
    else
    {
        NSUInteger rangeCount = 0;
        [coder decodeValueOfObjCType:@encode(NSUInteger) at:&rangeCount];
        for (NSUInteger i = 0; i < rangeCount; i++)
        {
            NSUInteger location = 0;
            NSUInteger length = 0;
            [coder decodeValueOfObjCType:@encode(NSUInteger) at:&location];
            [coder decodeValueOfObjCType:@encode(NSUInteger) at:&length];
            if (NSIndexSetRangeIsValid(NSMakeRange(location, length)))
            {
                NSIndexSetAddRange(self, NSMakeRange(location, length));
            }
        }
    }

    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    NSUInteger rangeCount = self->_rangeCount;

    if ([aCoder allowsKeyedCoding])
    {
        [aCoder encodeInt64:(int64_t)rangeCount forKey:@"NSRangeCount"];

        if (rangeCount == 1)
        {
            [aCoder encodeInt64:(int64_t)self->_ranges[0].location forKey:@"NSLocation"];
            [aCoder encodeInt64:(int64_t)self->_ranges[0].length forKey:@"NSLength"];
        }
        else if (rangeCount > 1)
        {
            // Each value needs at most 10 bytes.
            uint8_t *bytes = (uint8_t *)malloc(rangeCount * (2 * 10) + 1);
            if (bytes == NULL)
            {
                [NSException raise:NSMallocException format:@"Unable to encode NSIndexSet ranges"];
            }
            NSUInteger length = 0;
            for (NSUInteger i = 0; i < rangeCount; i++)
            {
                NSIndexSetAppendVarint(bytes, &length, (uint64_t)self->_ranges[i].location);
                NSIndexSetAppendVarint(bytes, &length, (uint64_t)self->_ranges[i].length);
            }
            NSData *data = [[NSData alloc] initWithBytes:bytes length:length];
            free(bytes);
            [aCoder encodeObject:data forKey:@"NSRangeData"];
            [data release];
        }
    }
    else
    {
        [aCoder encodeValueOfObjCType:@encode(NSUInteger) at:&rangeCount];
        for (NSUInteger i = 0; i < rangeCount; i++)
        {
            NSUInteger location = self->_ranges[i].location;
            NSUInteger length = self->_ranges[i].length;
            [aCoder encodeValueOfObjCType:@encode(NSUInteger) at:&location];
            [aCoder encodeValueOfObjCType:@encode(NSUInteger) at:&length];
        }
    }
}

- (BOOL)isEqual:(id)other
{
    if (other == self)
    {
        return YES;
    }
    if (other == nil || ![other isKindOfClass:[NSIndexSet class]])
    {
        return NO;
    }
    return [self isEqualToIndexSet:other];
}

- (BOOL)isEqualToIndexSet:(NSIndexSet *)indexSet
{
    if (indexSet == self)
    {
        return YES;
    }
    if (indexSet == nil || self->_rangeCount != indexSet->_rangeCount || self->_count != indexSet->_count)
    {
        return NO;
    }
    if (self->_rangeCount == 0)
    {
        return YES;
    }
    return memcmp(self->_ranges, indexSet->_ranges, self->_rangeCount * sizeof(NSRange)) == 0;
}

- (NSUInteger)hash
{
    return self->_count ^ [self firstIndex];
}

- (NSString *)description
{
    NSMutableString *indexes = [NSMutableString string];

    for (NSUInteger i = 0; i < self->_rangeCount; i++)
    {
        NSRange range = self->_ranges[i];
        if (i > 0)
        {
            [indexes appendString:@" "];
        }
        if (range.length == 1)
        {
            [indexes appendFormat:@"%lu", (unsigned long)range.location];
        }
        else
        {
            [indexes appendFormat:@"%lu-%lu", (unsigned long)range.location, (unsigned long)(NSMaxRange(range) - 1)];
        }
    }

    return [NSString stringWithFormat:@"<%@: %p>[number of indexes: %lu (in %lu ranges), indexes: (%@)]",
            NSStringFromClass([self class]), (void *)self,
            (unsigned long)self->_count, (unsigned long)self->_rangeCount, indexes];
}

- (id)copyWithZone:(NSZone *)zone
{
    if (![self isKindOfClass:[NSMutableIndexSet class]])
    {
        return [self retain];
    }
    return [[[NSIndexSet allocWithZone:zone] initWithIndexSet:self] autorelease];
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
    return [[[NSMutableIndexSet allocWithZone:zone] initWithIndexSet:self] autorelease];
}

- (void)dealloc
{
    free(self->_ranges);
    self->_ranges = NULL;
    [super dealloc];
}

- (NSUInteger)count
{
    return self->_count;
}

- (NSUInteger)rangeCount
{
    return self->_rangeCount;
}

- (NSUInteger)firstIndex
{
    if (self->_rangeCount == 0)
    {
        return NSNotFound;
    }
    return self->_ranges[0].location;
}

- (NSUInteger)lastIndex
{
    if (self->_rangeCount == 0)
    {
        return NSNotFound;
    }
    return NSIndexSetRangeEnd(self->_ranges[self->_rangeCount - 1]) - 1;
}

- (NSUInteger)indexGreaterThanIndex:(NSUInteger)value
{
    NSUInteger i = NSIndexSetFindRangeWithEndGreaterThan(self, value);
    if (i >= self->_rangeCount)
    {
        return NSNotFound;
    }

    NSRange entry = self->_ranges[i];
    if (entry.location > value)
    {
        return entry.location;
    }
    if (value + 1 < NSIndexSetRangeEnd(entry))
    {
        return value + 1;
    }
    // value was the last index of this range; the answer begins the next one.
    if (i + 1 < self->_rangeCount)
    {
        return self->_ranges[i + 1].location;
    }
    return NSNotFound;
}

- (NSUInteger)indexGreaterThanOrEqualToIndex:(NSUInteger)value
{
    NSUInteger i = NSIndexSetFindRangeWithEndGreaterThan(self, value);
    if (i >= self->_rangeCount)
    {
        return NSNotFound;
    }
    if (self->_ranges[i].location > value)
    {
        return self->_ranges[i].location;
    }
    return value;
}

- (NSUInteger)indexLessThanIndex:(NSUInteger)value
{
    if (value == 0)
    {
        return NSNotFound;
    }
    NSUInteger after = NSIndexSetFindRangeWithLocationAtLeast(self, value);
    if (after == 0)
    {
        return NSNotFound;
    }
    NSRange entry = self->_ranges[after - 1];
    if (value < NSIndexSetRangeEnd(entry))
    {
        return value - 1;
    }
    return NSIndexSetRangeEnd(entry) - 1;
}

- (NSUInteger)indexLessThanOrEqualToIndex:(NSUInteger)value
{
    NSUInteger after = NSIndexSetFindRangeWithLocationGreaterThan(self, value);
    if (after == 0)
    {
        return NSNotFound;
    }
    NSRange entry = self->_ranges[after - 1];
    if (value < NSIndexSetRangeEnd(entry))
    {
        return value;
    }
    return NSIndexSetRangeEnd(entry) - 1;
}

- (NSUInteger)getIndexes:(NSUInteger *)indexBuffer maxCount:(NSUInteger)bufferSize inIndexRange:(NSRangePointer)range
{
    NSUInteger clipStart = 0;
    NSUInteger clipEnd = NSNotFound;
    if (range != NULL)
    {
        clipStart = range->location;
        clipEnd = NSIndexSetRangeBound(*range);
    }

    NSUInteger copied = 0;
    // "exhausted" means every index of the set inside the range was consumed;
    // it turns false as soon as we meet an index that does not fit the buffer.
    BOOL exhausted = YES;

    if (clipStart < clipEnd && self->_rangeCount > 0)
    {
        NSUInteger i = NSIndexSetFindRangeWithEndGreaterThan(self, clipStart);
        for (; i < self->_rangeCount; i++)
        {
            NSRange entry = self->_ranges[i];
            if (entry.location >= clipEnd)
            {
                break;
            }
            NSUInteger start = MAX(entry.location, clipStart);
            NSUInteger end = MIN(NSIndexSetRangeEnd(entry), clipEnd);
            for (NSUInteger index = start; index < end; index++)
            {
                if (indexBuffer != NULL && copied < bufferSize)
                {
                    indexBuffer[copied++] = index;
                }
                else
                {
                    exhausted = NO;
                    break;
                }
            }
            if (!exhausted)
            {
                break;
            }
        }
    }

    if (range != NULL)
    {
        if (exhausted)
        {
            range->location = clipEnd;
            range->length = 0;
        }
        else
        {
            NSUInteger newLocation = copied > 0 ? indexBuffer[copied - 1] + 1 : clipStart;
            range->location = newLocation;
            range->length = newLocation <= clipEnd ? clipEnd - newLocation : 0;
        }
    }

    return copied;
}

- (NSUInteger)countOfIndexesInRange:(NSRange)range
{
    if (range.length == 0 || self->_rangeCount == 0)
    {
        return 0;
    }

    NSUInteger start = range.location;
    NSUInteger end = NSIndexSetRangeBound(range);
    if (start >= end)
    {
        return 0;
    }

    NSUInteger total = 0;
    NSUInteger i = NSIndexSetFindRangeWithEndGreaterThan(self, start);
    for (; i < self->_rangeCount; i++)
    {
        NSRange entry = self->_ranges[i];
        if (entry.location >= end)
        {
            break;
        }
        NSUInteger overlapStart = MAX(entry.location, start);
        NSUInteger overlapEnd = MIN(NSIndexSetRangeEnd(entry), end);
        total += overlapEnd - overlapStart;
    }
    return total;
}

- (BOOL)containsIndex:(NSUInteger)value
{
    NSUInteger i = NSIndexSetFindRangeWithEndGreaterThan(self, value);
    return i < self->_rangeCount && self->_ranges[i].location <= value;
}

- (BOOL)containsIndexesInRange:(NSRange)range
{
    if (range.length == 0)
    {
        return NO;
    }
    return [self countOfIndexesInRange:range] == range.length;
}

- (BOOL)containsIndexes:(NSIndexSet *)indexSet
{
    if (indexSet == nil)
    {
        return YES;
    }
    for (NSUInteger i = 0; i < indexSet->_rangeCount; i++)
    {
        if (![self containsIndexesInRange:indexSet->_ranges[i]])
        {
            return NO;
        }
    }
    return YES;
}

- (BOOL)intersectsIndexesInRange:(NSRange)range
{
    if (range.length == 0 || self->_rangeCount == 0)
    {
        return NO;
    }

    NSUInteger start = range.location;
    NSUInteger end = NSIndexSetRangeBound(range);
    if (start >= end)
    {
        return NO;
    }

    NSUInteger i = NSIndexSetFindRangeWithEndGreaterThan(self, start);
    return i < self->_rangeCount && self->_ranges[i].location < end;
}

- (void)_enumerateIndexesInRange:(NSRange)range options:(NSEnumerationOptions)options usingBlock:(IndexSetEnumerateBlock)block
{
    NSUInteger clipStart = range.location;
    NSUInteger clipEnd = NSIndexSetRangeBound(range);
    if (clipStart >= clipEnd || self->_rangeCount == 0)
    {
        return;
    }

    if ((options & NSEnumerationReverse) == 0)
    {
        NSUInteger i = NSIndexSetFindRangeWithEndGreaterThan(self, clipStart);
        for (; i < self->_rangeCount; i++)
        {
            NSRange entry = self->_ranges[i];
            if (entry.location >= clipEnd)
            {
                break;
            }
            NSUInteger start = MAX(entry.location, clipStart);
            NSUInteger end = MIN(NSIndexSetRangeEnd(entry), clipEnd);
            for (NSUInteger index = start; index < end; index++)
            {
                BOOL stop = NO;
                block(index, &stop);
                if (stop)
                {
                    return;
                }
            }
        }
    }
    else
    {
        NSUInteger after = NSIndexSetFindRangeWithLocationAtLeast(self, clipEnd);
        while (after > 0)
        {
            NSUInteger i = --after;
            NSRange entry = self->_ranges[i];
            if (NSIndexSetRangeEnd(entry) <= clipStart)
            {
                break;
            }
            NSUInteger start = MAX(entry.location, clipStart);
            NSUInteger end = MIN(NSIndexSetRangeEnd(entry), clipEnd);
            for (NSUInteger index = end; index-- > start;)
            {
                BOOL stop = NO;
                block(index, &stop);
                if (stop)
                {
                    return;
                }
            }
        }
    }
}

- (NSUInteger)_indexInRange:(NSRange)range options:(NSEnumerationOptions)options passingTest:(IndexSetPredicateBlock)predicate
{
    NSUInteger clipStart = range.location;
    NSUInteger clipEnd = NSIndexSetRangeBound(range);
    if (clipStart >= clipEnd || self->_rangeCount == 0)
    {
        return NSNotFound;
    }

    if ((options & NSEnumerationReverse) == 0)
    {
        NSUInteger i = NSIndexSetFindRangeWithEndGreaterThan(self, clipStart);
        for (; i < self->_rangeCount; i++)
        {
            NSRange entry = self->_ranges[i];
            if (entry.location >= clipEnd)
            {
                break;
            }
            NSUInteger start = MAX(entry.location, clipStart);
            NSUInteger end = MIN(NSIndexSetRangeEnd(entry), clipEnd);
            for (NSUInteger index = start; index < end; index++)
            {
                BOOL stop = NO;
                if (predicate(index, &stop))
                {
                    return index;
                }
                if (stop)
                {
                    return NSNotFound;
                }
            }
        }
    }
    else
    {
        NSUInteger after = NSIndexSetFindRangeWithLocationAtLeast(self, clipEnd);
        while (after > 0)
        {
            NSUInteger i = --after;
            NSRange entry = self->_ranges[i];
            if (NSIndexSetRangeEnd(entry) <= clipStart)
            {
                break;
            }
            NSUInteger start = MAX(entry.location, clipStart);
            NSUInteger end = MIN(NSIndexSetRangeEnd(entry), clipEnd);
            for (NSUInteger index = end; index-- > start;)
            {
                BOOL stop = NO;
                if (predicate(index, &stop))
                {
                    return index;
                }
                if (stop)
                {
                    return NSNotFound;
                }
            }
        }
    }
    return NSNotFound;
}

- (NSIndexSet *)_indexesInRange:(NSRange)range options:(NSEnumerationOptions)options passingTest:(IndexSetPredicateBlock)predicate
{
    NSMutableIndexSet *result = [[NSMutableIndexSet alloc] init];
    [self _enumerateIndexesInRange:range options:options usingBlock:^(NSUInteger index, BOOL *stop) {
        if (predicate(index, stop))
        {
            [result addIndex:index];
        }
    }];
    return [result autorelease];
}

- (void)_enumerateRangesInRange:(NSRange)range options:(NSEnumerationOptions)options usingBlock:(IndexSetRangeBlock)block
{
    NSUInteger clipStart = range.location;
    NSUInteger clipEnd = NSIndexSetRangeBound(range);
    if (clipStart >= clipEnd || self->_rangeCount == 0)
    {
        return;
    }

    if ((options & NSEnumerationReverse) == 0)
    {
        NSUInteger i = NSIndexSetFindRangeWithEndGreaterThan(self, clipStart);
        for (; i < self->_rangeCount; i++)
        {
            NSRange entry = self->_ranges[i];
            if (entry.location >= clipEnd)
            {
                break;
            }
            NSUInteger start = MAX(entry.location, clipStart);
            NSUInteger end = MIN(NSIndexSetRangeEnd(entry), clipEnd);
            if (start < end)
            {
                BOOL stop = NO;
                block(NSMakeRange(start, end - start), &stop);
                if (stop)
                {
                    return;
                }
            }
        }
    }
    else
    {
        NSUInteger after = NSIndexSetFindRangeWithLocationAtLeast(self, clipEnd);
        while (after > 0)
        {
            NSUInteger i = --after;
            NSRange entry = self->_ranges[i];
            if (NSIndexSetRangeEnd(entry) <= clipStart)
            {
                break;
            }
            NSUInteger start = MAX(entry.location, clipStart);
            NSUInteger end = MIN(NSIndexSetRangeEnd(entry), clipEnd);
            if (start < end)
            {
                BOOL stop = NO;
                block(NSMakeRange(start, end - start), &stop);
                if (stop)
                {
                    return;
                }
            }
        }
    }
}

- (void)enumerateIndexesUsingBlock:(IndexSetEnumerateBlock)block
{
    [self enumerateIndexesWithOptions:0 usingBlock:block];
}

- (void)enumerateIndexesWithOptions:(NSEnumerationOptions)options usingBlock:(IndexSetEnumerateBlock)block
{
    if (block == nil)
    {
        [NSException raise:NSInvalidArgumentException format:@"block is nil"];
    }
    [self _enumerateIndexesInRange:NSMakeRange(0, NSNotFound) options:options usingBlock:block];
}

- (void)enumerateIndexesInRange:(NSRange)range options:(NSEnumerationOptions)options usingBlock:(IndexSetEnumerateBlock)block
{
    if (block == nil)
    {
        [NSException raise:NSInvalidArgumentException format:@"block is nil"];
    }
    [self _enumerateIndexesInRange:range options:options usingBlock:block];
}

- (NSUInteger)indexPassingTest:(IndexSetPredicateBlock)predicate
{
    return [self indexWithOptions:0 passingTest:predicate];
}

- (NSUInteger)indexWithOptions:(NSEnumerationOptions)options passingTest:(IndexSetPredicateBlock)predicate
{
    if (predicate == nil)
    {
        [NSException raise:NSInvalidArgumentException format:@"block is nil"];
    }
    return [self _indexInRange:NSMakeRange(0, NSNotFound) options:options passingTest:predicate];
}

- (NSUInteger)indexInRange:(NSRange)range options:(NSEnumerationOptions)options passingTest:(IndexSetPredicateBlock)predicate
{
    if (predicate == nil)
    {
        [NSException raise:NSInvalidArgumentException format:@"block is nil"];
    }
    return [self _indexInRange:range options:options passingTest:predicate];
}

- (NSIndexSet *)indexesPassingTest:(IndexSetPredicateBlock)predicate
{
    return [self indexesWithOptions:0 passingTest:predicate];
}

- (NSIndexSet *)indexesWithOptions:(NSEnumerationOptions)options passingTest:(IndexSetPredicateBlock)predicate
{
    if (predicate == nil)
    {
        [NSException raise:NSInvalidArgumentException format:@"block is nil"];
    }
    return [self _indexesInRange:NSMakeRange(0, NSNotFound) options:options passingTest:predicate];
}

- (NSIndexSet *)indexesInRange:(NSRange)range options:(NSEnumerationOptions)options passingTest:(IndexSetPredicateBlock)predicate
{
    if (predicate == nil)
    {
        [NSException raise:NSInvalidArgumentException format:@"block is nil"];
    }
    return [self _indexesInRange:range options:options passingTest:predicate];
}

- (void)enumerateRangesUsingBlock:(IndexSetRangeBlock)block
{
    [self enumerateRangesWithOptions:0 usingBlock:block];
}

- (void)enumerateRangesWithOptions:(NSEnumerationOptions)options usingBlock:(IndexSetRangeBlock)block
{
    if (block == nil)
    {
        [NSException raise:NSInvalidArgumentException format:@"block is nil"];
    }
    [self _enumerateRangesInRange:NSMakeRange(0, NSNotFound) options:options usingBlock:block];
}

- (void)enumerateRangesInRange:(NSRange)range options:(NSEnumerationOptions)options usingBlock:(IndexSetRangeBlock)block
{
    if (block == nil)
    {
        [NSException raise:NSInvalidArgumentException format:@"block is nil"];
    }
    [self _enumerateRangesInRange:range options:options usingBlock:block];
}

@end

@implementation NSMutableIndexSet

- (void)addIndexes:(NSIndexSet *)indexSet
{
    if (indexSet == nil || indexSet == self)
    {
        return;
    }
    for (NSUInteger i = 0; i < indexSet->_rangeCount; i++)
    {
        NSIndexSetAddRange(self, indexSet->_ranges[i]);
    }
}

- (void)removeIndexes:(NSIndexSet *)indexSet
{
    if (indexSet == nil || indexSet->_rangeCount == 0)
    {
        return;
    }
    if (indexSet == self)
    {
        [self removeAllIndexes];
        return;
    }
    for (NSUInteger i = 0; i < indexSet->_rangeCount; i++)
    {
        NSIndexSetRemoveRange(self, indexSet->_ranges[i]);
    }
}

- (void)removeAllIndexes
{
    self->_rangeCount = 0;
    self->_count = 0;
}

- (void)addIndex:(NSUInteger)value
{
    NSIndexSetAddRange(self, NSMakeRange(value, 1));
}

- (void)removeIndex:(NSUInteger)value
{
    NSIndexSetRemoveRange(self, NSMakeRange(value, 1));
}

- (void)addIndexesInRange:(NSRange)range
{
    NSIndexSetAddRange(self, range);
}

- (void)removeIndexesInRange:(NSRange)range
{
    NSIndexSetRemoveRange(self, range);
}

- (void)shiftIndexesStartingAtIndex:(NSUInteger)index by:(NSInteger)delta
{
    if (delta == 0 || self->_rangeCount == 0)
    {
        return;
    }

    NSUInteger up = 0;
    NSUInteger down = 0;
    if (delta > 0)
    {
        up = (NSUInteger)delta;
    }
    else
    {
        // Avoid the undefined negation of NSIntegerMin.
        down = (NSUInteger)(-(delta + 1)) + 1;
    }

    NSIndexSetBuilder builder;
    builder.ranges = NULL;
    builder.count = 0;
    builder.capacity = 0;

    for (NSUInteger i = 0; i < self->_rangeCount; i++)
    {
        NSRange entry = self->_ranges[i];
        NSUInteger entryEnd = NSIndexSetRangeEnd(entry);

        if (up > 0)
        {
            // Indexes below index stay put.
            NSUInteger keepEnd = MIN(entryEnd, index);
            if (entry.location < keepEnd)
            {
                NSIndexSetBuilderAppend(&builder, NSMakeRange(entry.location, keepEnd - entry.location));
            }
            // Indexes at or above index move up; those that would reach
            // NSNotFound are dropped.
            NSUInteger moveStart = MAX(entry.location, index);
            if (moveStart < entryEnd)
            {
                NSUInteger keepLimit = up >= NSNotFound ? moveStart : MIN(entryEnd, NSNotFound - up);
                if (moveStart < keepLimit)
                {
                    NSIndexSetBuilderAppend(&builder, NSMakeRange(moveStart + up, keepLimit - moveStart));
                }
            }
        }
        else
        {
            // Indexes in [index - down, index) are overwritten and removed.
            NSUInteger limit = index >= down ? index - down : 0;
            NSUInteger keepEnd = MIN(entryEnd, limit);
            if (entry.location < keepEnd)
            {
                NSIndexSetBuilderAppend(&builder, NSMakeRange(entry.location, keepEnd - entry.location));
            }
            // Indexes at or above index move down; those that would fall
            // below zero are dropped.
            NSUInteger moveStart = MAX(entry.location, index);
            if (moveStart < entryEnd && down < entryEnd)
            {
                NSUInteger newLocation = moveStart > down ? moveStart - down : 0;
                NSIndexSetBuilderAppend(&builder, NSMakeRange(newLocation, entryEnd - down - newLocation));
            }
        }
    }

    NSUInteger newCount = 0;
    for (NSUInteger i = 0; i < builder.count; i++)
    {
        newCount += builder.ranges[i].length;
    }

    free(self->_ranges);
    self->_ranges = builder.ranges;
    self->_rangeCount = builder.count;
    self->_capacity = builder.capacity;
    self->_count = newCount;
}

@end