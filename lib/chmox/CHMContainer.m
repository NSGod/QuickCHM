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
// $Revision: 1.8 $
//

#include <stdint.h>

#import "CHMContainer.h"
#import <CHM/CHM.h>
#import <CommonCrypto/CommonDigest.h>


@interface CHMContainer (CHMPrivate)

- (BOOL)loadMetadata;

- (BOOL)hasObjectAtPath:(NSString *)path;

- (NSData *)dataForObjectAtPath:(NSString *)objectPath;
- (NSString *)stringForObjectAtPath:(NSString *)objectPath;

- (NSString *)findHomeForPath:(NSString *)basePath;

@end



@implementation CHMContainer

#pragma mark Factory

+ (id)containerWithContentsOfFile:(NSString *)chmFilePath {
	return [[(CHMContainer *)[[self class] alloc] initWithContentsOfFile:chmFilePath] autorelease];
}


#pragma mark Lifecycle

- (id)initWithContentsOfFile:(NSString *)chmFilePath {
	if ((self = [super init])) {
		chmFileHandle = chm_open([chmFilePath fileSystemRepresentation]);
		if (chmFileHandle == NULL) {
			[self release];
			return nil;
		}
		filePath = [chmFilePath retain];
		[self loadMetadata];
	}
	return self;
}


- (void)dealloc {
	DEBUG_OUTPUT(@"deallocating %@", self);
	[filePath release];

	if (chmFileHandle) {
		chm_close(chmFileHandle);
	}
	[uniqueID release];
	[title release];
	[homePath release];
	[tableOfContentsPath release];
	[indexPath release];
	[super dealloc];
}


#pragma mark Accessors

- (NSString *)homePath {
	return homePath;
}

- (NSString *)title {
	return title;
}

- (NSString *)uniqueID {
	return uniqueID;
}

- (NSString *)tableOfContentsPath {
	return tableOfContentsPath;
}


#pragma mark Basic CHM reading operations

static inline unsigned short readShort(NSData *data, NSUInteger offset) {
	NSRange valueRange = { offset, 2 };
	unsigned short value;

	[data getBytes:(void *)&value range:valueRange];
	return NSSwapLittleShortToHost(value);
}

static inline uint32_t readLong(NSData *data, NSUInteger offset) {
	NSRange valueRange = { offset, 4 };
	uint32_t value;

	[data getBytes:(void *)&value range:valueRange];
	return NSSwapLittleLongToHost(value);
}

static inline NSString *readString(NSData *data, NSUInteger offset) {
	const char *stringData = (char *)[data bytes] + offset;
	return [NSString stringWithUTF8String:stringData];
}

static inline NSString *readTrimmedString(NSData *data, NSUInteger offset) {
	const char *stringData = (char *)[data bytes] + offset;
	return [[NSMutableString stringWithUTF8String:stringData] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

#pragma mark CHM Object loading

- (BOOL)hasObjectAtPath:(NSString *)path {
	struct chmUnitInfo info;
	if (chm_resolve_object(chmFileHandle, [path UTF8String], &info) != CHM_RESOLVE_SUCCESS) {
		return NO;
	}
	return YES;
}


- (NSData *)dataForObjectAtPath:(NSString *)path {
	//DEBUG_OUTPUT( @"dataForObjectAtPath: %@", path );
	if (!path) {
		return nil;
	}
	if ([path hasPrefix:@"/"]) {
		// Quick fix
		if ([path hasPrefix:@"///"]) {
			path = [path substringFromIndex:2];
		}
	} else {
		path = [NSString stringWithFormat:@"/%@", path];
	}
	
	struct chmUnitInfo info;
	if (chm_resolve_object(chmFileHandle, [path UTF8String], &info) != CHM_RESOLVE_SUCCESS) {
		DEBUG_OUTPUT(@"Unable to find %@", path);
		return nil;
	}
	
	DEBUG_OUTPUT(@"Found object %@ (%qu bytes)", path, (long long)info.length);

	void *buffer = malloc(info.length);

	if (!buffer) {
		// Allocation failed
		DEBUG_OUTPUT(@"Failed to allocate %qu bytes for %@", (long long)info.length, path);
		return nil;
	}
	
	if (!chm_retrieve_object(chmFileHandle, &info, buffer, 0, info.length)) {
		DEBUG_OUTPUT(@"Failed to load %qu bytes for %@", (long long)info.length, path);
		free(buffer);
		return nil;
	}
	return [NSData dataWithBytesNoCopy:buffer length:info.length];
}


- (NSString *)stringForObjectAtPath:(NSString *)objectPath {
	NSData *data = [self dataForObjectAtPath:objectPath];
	if (data) {
		// NSUTF8StringEncoding / NSISOLatin1StringEncoding / NSUnicodeStringEncoding
		return [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
	}
	return nil;
}

- (NSData *)dataWithTableOfContents {
	return [self dataForObjectAtPath:tableOfContentsPath];
}


#pragma mark CHM setup

- (BOOL)loadMetadata {
	//--- Start with WINDOWS object ---
	NSData *windowsData = [self dataForObjectAtPath:@"/#WINDOWS"];
	NSData *stringsData = [self dataForObjectAtPath:@"/#STRINGS"];

	if (windowsData && stringsData) {
		const uint32_t entryCount = readLong(windowsData, 0);
		const uint32_t entrySize = readLong(windowsData, 4);
		
		DEBUG_OUTPUT(@"Entries: %u@ x %u bytes", entryCount, entrySize);
		
		for (uint32_t entryIndex = 0; entryIndex < entryCount; ++entryIndex) {
			uint32_t entryOffset = 8 + (entryIndex * entrySize);

			if (!title || ([title length] == 0)) {
				title = readTrimmedString(stringsData, readLong(windowsData, entryOffset + 0x14));
				DEBUG_OUTPUT(@"Title: %@", title);
			}
			if (!tableOfContentsPath || ([tableOfContentsPath length] == 0)) {
				tableOfContentsPath = readString(stringsData, readLong(windowsData, entryOffset + 0x60));
				DEBUG_OUTPUT(@"Table of contents: %@", tableOfContentsPath);
			}
			if (!indexPath || ([indexPath length] == 0)) {
				indexPath = readString(stringsData, readLong(windowsData, entryOffset + 0x64));
				DEBUG_OUTPUT(@"Index: %@", indexPath);
			}
			if (!homePath || ([homePath length] == 0)) {
				homePath = readString(stringsData, readLong(windowsData, entryOffset + 0x68));
				DEBUG_OUTPUT(@"Home: %@", homePath);
			}
		}
	}
    
	//--- Use SYSTEM object ---
	NSData *systemData = [self dataForObjectAtPath:@"/#SYSTEM"];
	
	if (systemData == nil) {
		return NO;
	}
	
	NSUInteger maxOffset = [systemData length];
	
	for (NSUInteger offset = 0; offset < maxOffset; offset += readShort(systemData, offset + 2) + 4) {
		
		switch (readShort(systemData, offset)) {
			// Table of contents file
			case 0:
				if (!tableOfContentsPath || ([tableOfContentsPath length] == 0)) {
					tableOfContentsPath = readString(systemData, offset + 4);
					DEBUG_OUTPUT(@"SYSTEM Table of contents: %@", tableOfContentsPath);
				}
				break;
				
			// Index file
			case 1:
				if (!indexPath || ([indexPath length] == 0)) {
					indexPath = readString(systemData, offset + 4);
					DEBUG_OUTPUT(@"SYSTEM Index: %@", indexPath);
				}
				break;
				
			// Home page
			case 2:
				if (!homePath || ([homePath length] == 0)) {
					homePath = readString(systemData, offset + 4);
					DEBUG_OUTPUT(@"SYSTEM Home: %@", homePath);
				}
				break;
				
			// Title
			case 3:
				if (!title || ([title length] == 0)) {
					title = readTrimmedString(systemData, offset + 4);
					DEBUG_OUTPUT(@"SYSTEM Title: %@", title);
				}
				break;
				
			// Compiled file
			case 6:
				DEBUG_OUTPUT(@"SYSTEM compiled file: %@", readString(systemData, offset + 4));
				break;
				
			// Compiler
			case 9:
				DEBUG_OUTPUT(@"SYSTEM Compiler: %@", readString(systemData, offset + 4));
				break;
				
			// Default font
			case 16:
				DEBUG_OUTPUT(@"SYSTEM Default font: %@", readString(systemData, offset + 4));
				break;
				
			// Other data not handled
			default:
				break;
		}
	}
	
    //--- Compute unique id ---
	unsigned char digest[CC_SHA1_DIGEST_LENGTH];
	char finalDigest[(2 * CC_SHA1_DIGEST_LENGTH) + 1];
	
	CC_SHA1([systemData bytes], systemData.length, digest);
	
	NSUInteger i = 0;
	
	for (i = 0; i < CC_SHA1_DIGEST_LENGTH; i++) {
		sprintf(finalDigest + (i * 2), "%02x", digest[i]);
	}
	finalDigest[i * 2] = 0;
	
	uniqueID = [[NSString alloc] initWithUTF8String:finalDigest];
	DEBUG_OUTPUT(@"UniqueId=%@", uniqueID);

	// Check for empty string titles
	if ([title length] == 0) {
		title = nil;
	} else {
		[title retain];
	}
	// Check for lack of index page
	if (!homePath) {
		homePath = [self findHomeForPath:@"/"];
		DEBUG_OUTPUT(@"Implicit home: %@", homePath);
	}
	[homePath retain];
	[tableOfContentsPath retain];
	[indexPath retain];

	return YES;
}



- (NSString *)findHomeForPath:(NSString *)basePath {
	NSString *testPath;
	
	NSString *separator = [basePath hasSuffix:@"/"] ? @"" : @"/";
	testPath = [NSString stringWithFormat:@"%@%@index.htm", basePath, separator];
	if ([self hasObjectAtPath:testPath]) {
		return testPath;
	}
	testPath = [NSString stringWithFormat:@"%@%@default.html", basePath, separator];
	if ([self hasObjectAtPath:testPath]) {
		return testPath;
	}
	testPath = [NSString stringWithFormat:@"%@%@default.htm", basePath, separator];
	if ([self hasObjectAtPath:testPath]) {
		return testPath;
	}
	return [NSString stringWithFormat:@"%@%@index.html", basePath, separator];
}


- (BOOL)setupFromSystemObject {
	return YES;
}


- (NSData *)dataForURL:(NSURL *)url {
	NSData *data;

	if ([url parameterString]) {
		data = [self dataForObjectAtPath:[NSString stringWithFormat:@"%@;%@", [url path], [url parameterString]]];
	} else {
		data = [self dataForObjectAtPath:[url path]];
	}
	return data;
}

@end
