//	  QuickCHM a CHM Quicklook plgin for Mac OS X 10.5
//
//    Copyright (C) 2007  Qian Qian (qiqian82@gmail.com)
//
//    QuickCHM is free software: you can redistribute it and/or modify
//    it under the terms of the GNU General Public License as published by
//    the Free Software Foundation, either version 3 of the License, or
//    (at your option) any later version.
//
//    QuickCHM is distributed in the hope that it will be useful,
//    but WITHOUT ANY WARRANTY; without even the implied warranty of
//    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//    GNU General Public License for more details.
//
//    You should have received a copy of the GNU General Public License
//    along with this program.  If not, see <http://www.gnu.org/licenses/>.

#import <CoreFoundation/CoreFoundation.h>
#import <CoreFoundation/CFPlugInCOM.h>
#import <CoreServices/CoreServices.h>
#import <QuickLook/QuickLook.h>

#import <libxml/parser.h>

#import "CHMDocument.h"
#import "CHMContainer.h"
#import "CHMURLProtocol.h"
#import "CHMTableOfContents.h"
#import "CHMTopic.h"
#import "QuickChmPageAdaptor.h"

OSStatus GeneratePreviewForURL(void *thisInterface, QLPreviewRequestRef preview, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options);
void CancelPreviewGeneration(void* thisInterface, QLPreviewRequestRef preview);


#define MD_DEBUG 1

#if MD_DEBUG
static NSString * const MDCHMQuickLookBundleIdentifier = @"com.markdouma.qlgenerator.CHM";
#define MDLog(...) NSLog(__VA_ARGS__)
#else
#define MDLog(...)
#endif

#pragma mark Generate preview

/* -----------------------------------------------------------------------------
   Generate a preview for file

   This function's job is to create preview for designated file
   ----------------------------------------------------------------------------- */

OSStatus GeneratePreviewForURL(void *thisInterface, QLPreviewRequestRef preview, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options)
{
	xmlInitParser();
	LIBXML_TEST_VERSION;
    
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	
	MDLog(@"%@; %s(): file == \"%@\")", MDCHMQuickLookBundleIdentifier, __FUNCTION__, [(NSURL *)URL path]);
	
#if DEBUG_MODE
	BOOL success = [NSURLProtocol registerClass:[CHMURLProtocol class]];
	DEBUG_OUTPUT(@"NSURLProtocol registration %@", success ? @"SUCCESS" : @"FAIL");
#endif
	CHMDocument *doc = [[CHMDocument alloc] init];
	
	if ([doc readFromFile:[(NSURL *)url path] ofType:nil]) {
		NSURL *homeUrl = [doc currentLocation];
		// Get the main page data
		NSData *data = [doc urlData:homeUrl];	
		// Parse and replace hyper link
		NSMutableDictionary *props=[[[NSMutableDictionary alloc] init] autorelease];
		CFDataRef newData = adaptPage(data, doc->_container, homeUrl, &props);
		
		QLPreviewRequestSetDataRepresentation(preview, newData, kUTTypeHTML, (CFDictionaryRef)props);
    }
    [doc release];
	[pool release];
	
	xmlCleanupParser();
	
    return noErr;
}

void CancelPreviewGeneration(void* thisInterface, QLPreviewRequestRef preview)
{
	// implement only if supported
}

