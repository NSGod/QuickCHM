//
// Chmox a CHM file viewer for Mac OS X
// Copyright (c) 2004 StŽphane Boisson.
//
// Chmox is free software; you can redistribute it and/or modify it
// under the terms of the GNU Lesser General Public License as published
// by the Free Software Foundation; either version 2.1 of the License, or
// (at your option) any later version.
//
// Chmox is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Lesser General Public License for more details.
// 
// You should have received a copy of the GNU Lesser General Public License
// along with Foobar; if not, write to the Free Software
// Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
//
// $Revision: 1.4 $
//

#import "CHMTopic.h"


@implementation CHMTopic

#pragma mark Lifecycle

- (id)initWithName:(NSString *)topicName location:(NSURL *)topicLocation {
    if ((self = [super init])) {
        name = [topicName retain];
        location = [topicLocation retain];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
	CHMTopic *other = [[CHMTopic allocWithZone:zone] initWithName:name location:location];

	if (subTopics) {
		other->subTopics = [subTopics retain];
	}
	return other;
}


- (void)dealloc {
	[name release];
	[location release];
	[subTopics release];
	[super dealloc];
}


#pragma mark Accessors

- (NSString *)description {
    return [NSString stringWithFormat:@"<CHMTopic:'%@',%@>", name, location];
}


- (NSString *)name {
    return name;
}

- (NSURL *)location {
    return location;
}

- (NSUInteger)countOfSubTopics {
	return [subTopics count];
}


- (CHMTopic *)objectInSubTopicsAtIndex:(NSUInteger)theIndex {
    return [subTopics objectAtIndex:theIndex];
}

#pragma mark Mutators

- (void)setName:(NSString *)text {
	if (name != text) {
		[name release];
		name = [text retain];
	}
}

- (void)setLocation:(NSURL *)URL {
	if (location != URL) {
		[location release];
		location = [URL retain];
	}
}

- (void)addObject:(CHMTopic *)topic {
	if (!subTopics) subTopics = [[NSMutableArray alloc] init];
	[subTopics addObject:topic];
}


- (void)insertObject:(CHMTopic *)topic inSubTopicsAtIndex:(NSUInteger)theIndex {
    if (!subTopics) subTopics = [[NSMutableArray alloc] init];
    [subTopics insertObject:topic atIndex:theIndex];
}

- (void)removeObjectFromSubTopicsAtIndex:(NSUInteger)theIndex {
	[subTopics removeObjectAtIndex:theIndex];
}


@end
