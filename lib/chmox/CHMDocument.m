//
// Chmox a CHM file viewer for Mac OS X
// Copyright (c) 2004 Stéphane Boisson.
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
// $Revision: 1.6 $
//

#import "CHMDocument.h"
#import "CHMContainer.h"
#import "CHMTableOfContents.h"
#import "CHMURLProtocol.h"

@implementation CHMDocument

#pragma mark NSObject

- (id)init {
	if (self = [super init]) {
		
	}
	return self;
}


- (void)dealloc {
	if (container) {
		[CHMURLProtocol unregisterContainer:container];
		[tableOfContents release];
		[container release];
	}
	[super dealloc];
}


#pragma mark NSDocument

- (BOOL)readFromURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError **)outError {
	// in case they try to read *outError:
	if (outError) *outError = nil;
	
	DEBUG_OUTPUT( @"[%@ %@] url.path == \"%@\"", NSStringFromClass([self class]), NSStringFromSelector(_cmd),url.path);
	
	container = [[CHMContainer alloc] initWithContentsOfFile:url.path];
	if (container == nil) return NO;
	
	[CHMURLProtocol registerContainer:container];
    tableOfContents = [[CHMTableOfContents alloc] initWithContainer:container];

    return YES;
}


#pragma mark Accessors

- (NSString *)title {
	return [container title];
}

- (NSURL *)currentLocation {
	return [CHMURLProtocol URLWithPath:[container homePath] inContainer:container];
}

- (CHMTableOfContents *)tableOfContents {
	return tableOfContents;
}

- (NSString *)uniqueID {
	return [container uniqueID];
}

- (NSData *)dataForURL:(NSURL *)url {
	if (!container) {
		return nil;
	}
	return [container dataForURL:url];
}

@end
