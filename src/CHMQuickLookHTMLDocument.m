//
//  CHMQuickLookHTMLDocument.m
//  quickchm
//
//  Created by Mark Douma on 5/5/2016.
//
//

#import "CHMQuickLookHTMLDocument.h"
#import <CHMKit/CHMKit.h>
#import <QuickLook/QuickLook.h>
#import <CoreServices/CoreServices.h>


#define MD_DEBUG 1

#if MD_DEBUG
#define MDLog(...) NSLog(__VA_ARGS__)
#else
#define MDLog(...)
#endif

#define MD_DEBUG_DUMP_TO_FILES 0


@interface NSXMLElement (CHMAdditions)

- (NSXMLNode *)chm__attributeForCaseInsensitiveName:(NSString *)aName;

@end


@implementation NSXMLElement (CHMAdditions)

- (NSXMLNode *)chm__attributeForCaseInsensitiveName:(NSString *)aName {
	NSArray *attrs = [self attributes];
	for (NSXMLNode *attr in attrs) {
		if ([attr.name caseInsensitiveCompare:aName] == NSOrderedSame) return attr;
	}
	return nil;
}

@end



@interface CHMQuickLookHTMLDocument	()

@property (nonatomic, retain) NSXMLDocument *document;
@property (nonatomic, retain) CHMDocumentFile *documentFile;
@property (nonatomic, retain) CHMLinkItem *linkItem;

- (void)adaptHTML;

- (NSMutableDictionary *)attachmentsDictionary;

#if MD_DEBUG_DUMP_TO_FILES
- (void)writeDebugDataToDebugPathWithName:(NSString *)aName;
#endif

@end


#if MD_DEBUG_DUMP_TO_FILES
static NSString * MDDesktopDebugFolderPath = nil;
#endif


@implementation CHMQuickLookHTMLDocument

@synthesize document;
@synthesize documentFile;
@synthesize linkItem;
@synthesize quickLookProperties;

@dynamic adaptedHTMLData;


#if MD_DEBUG_DUMP_TO_FILES
+ (void)initialize {
	if (MDDesktopDebugFolderPath == nil) MDDesktopDebugFolderPath = [[@"~/Desktop/chmDebug" stringByExpandingTildeInPath] retain];
	
	NSError *error = nil;
	
	if (![[NSFileManager defaultManager] createDirectoryAtPath:MDDesktopDebugFolderPath withIntermediateDirectories:YES attributes:nil error:&error]) {
		NSLog(@"[%@ %@] *** ERROR: failed to create folder at \"%@\", error == %@", NSStringFromClass([self class]), NSStringFromSelector(_cmd), MDDesktopDebugFolderPath, error);
	}
}
#endif


- (id)initWithLinkItem:(CHMLinkItem *)anItem inDocumentFile:(CHMDocumentFile *)aDocumentFile error:(NSError **)outError {
	if ((self = [super init])) {
		linkItem = [anItem retain];
		documentFile = [aDocumentFile retain];
		
		NSData *pageData = linkItem.archiveItem.data;
		if (pageData == nil) {
			if (outError) {
				*outError = [NSError errorWithDomain:NSCocoaErrorDomain
												code:0
											userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
													  documentFile.filePath, NSFilePathErrorKey,
													  [NSString stringWithFormat:@"Failed to obtain data for object at path \"%@\"", linkItem.path], NSLocalizedDescriptionKey, nil]];
			}
			[self release];
			return nil;
		}
		
		NSError *error = nil;
		
		// pass NSXMLDocumentTidyXML | NSXMLDocumentTidyHTML (both) for best results, as they aren't mutually exclusive
		// NSXMLDocumentTidyXML fixes invalid XML, NSXMLDocumentTidyHTML can make strings easier to read
		
		document = [[NSXMLDocument alloc] initWithData:pageData options:NSXMLDocumentTidyXML | NSXMLDocumentTidyHTML error:&error];
		
		if (document == nil) {
			if (outError && error) {
				*outError = [NSError errorWithDomain:NSCocoaErrorDomain
												code:0
											userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
													  documentFile.filePath, NSFilePathErrorKey,
													  error, NSUnderlyingErrorKey, nil]];
			}
			[self release];
			return nil;
		}
		
		quickLookProperties = [[NSMutableDictionary alloc] init];
		
		if (documentFile.encodingName) [quickLookProperties setObject:documentFile.encodingName forKey:(id)kQLPreviewPropertyTextEncodingNameKey];
		[quickLookProperties setObject:@"text/html" forKey:(id)kQLPreviewPropertyMIMETypeKey];
		
		[self adaptHTML];
	}
	return self;
}


- (void)dealloc {
	[document release];
	[documentFile release];
	[quickLookProperties release];
	[linkItem release];
	[super dealloc];
}


- (NSMutableDictionary *)attachmentsDictionary {
	NSMutableDictionary *attachmentsDictionary = [quickLookProperties objectForKey:(id)kQLPreviewPropertyAttachmentsKey];
	if (attachmentsDictionary == nil) {
		attachmentsDictionary = [NSMutableDictionary dictionary];
		[quickLookProperties setObject:attachmentsDictionary forKey:(id)kQLPreviewPropertyAttachmentsKey];
	}
	return attachmentsDictionary;
}


- (NSData *)adaptedHTMLData {
	return [document XMLDataWithOptions:NSXMLNodePrettyPrint | NSXMLDocumentIncludeContentTypeDeclaration];
}


- (NSDictionary *)quickLookProperties {
	return [[quickLookProperties copy] autorelease];
}


- (void)adaptLinkElement:(NSXMLElement *)linkElement {
	NSXMLNode *typeAttr = [linkElement chm__attributeForCaseInsensitiveName:@"type"];
	NSXMLNode *hrefAttr = [linkElement chm__attributeForCaseInsensitiveName:@"href"];
	
	if (!(typeAttr && hrefAttr)) return;
	
	if (![typeAttr.stringValue isEqualToString:@"text/css"]) return;
	
	NSString *cssFilePath = [[hrefAttr.stringValue copy] autorelease];
	CHMArchiveItem *cssItem = [documentFile archiveItemAtPath:cssFilePath relativeToArchiveItem:linkItem.archiveItem];
	NSData *cssData = cssItem.data;
	if (cssData == nil) {
		
		return;
	}
	NSString *contentIDFilePath = [@"cid:" stringByAppendingString:cssFilePath];
	hrefAttr.stringValue = contentIDFilePath;
	
	NSMutableDictionary *attachments = [self attachmentsDictionary];
	NSMutableDictionary *attachmentEntry = [NSMutableDictionary dictionaryWithObjectsAndKeys:cssData,(id)kQLPreviewPropertyAttachmentDataKey,
											@"text/css",(id)kQLPreviewPropertyMIMETypeKey, nil];
	if (documentFile.encodingName) [attachmentEntry setObject:documentFile.encodingName forKey:(id)kQLPreviewPropertyTextEncodingNameKey];
	[attachments setObject:attachmentEntry forKey:cssFilePath];
	
}


- (void)adaptImageElement:(NSXMLElement *)imgElement {
	NSXMLNode *srcAttr = [imgElement chm__attributeForCaseInsensitiveName:@"src"];
	if (srcAttr == nil) {
		return;
	}
	NSString *imgFilePath = [[srcAttr.stringValue copy] autorelease];
	NSData *imgData = [documentFile archiveItemAtPath:imgFilePath relativeToArchiveItem:linkItem.archiveItem].data;
	if (imgData == nil) {
		
		return;
	}
	
	NSString *contentIDFilePath = [@"cid:" stringByAppendingString:imgFilePath];
	srcAttr.stringValue = contentIDFilePath;
	NSString *mimeType = [CHMArchiveItem MIMETypeForPathExtension:[imgFilePath pathExtension]];
	
	NSMutableDictionary *attachments = [self attachmentsDictionary];
	NSMutableDictionary *attachmentEntry = [NSMutableDictionary dictionaryWithObjectsAndKeys:imgData,(id)kQLPreviewPropertyAttachmentDataKey, nil];
	if (mimeType) [attachmentEntry setObject:mimeType forKey:(id)kQLPreviewPropertyMIMETypeKey];
	[attachments setObject:attachmentEntry forKey:imgFilePath];
}


- (void)adaptHTML {
	
#if MD_DEBUG_DUMP_TO_FILES
	[self writeDebugDataToDebugPathWithName:@"chm__Before.html"];
#endif
	
	NSXMLNode *nextNode = document;
	
	while ((nextNode = [nextNode nextNode])) {
		NSXMLNodeKind kind = nextNode.kind;
		
		if (kind == NSXMLElementKind) {
			
			NSXMLElement *element = (NSXMLElement *)nextNode;
			
			NSString *elementName = [[element name] lowercaseString];
			
			if ([elementName isEqualToString:@"link"]) {
				[self adaptLinkElement:element];
				
			} else if ([elementName isEqualToString:@"a"]) {
				
				
			} else if ([elementName isEqualToString:@"img"]) {
				[self adaptImageElement:element];
			}
			
		}
	}
	
#if MD_DEBUG_DUMP_TO_FILES
	[self writeDebugDataToDebugPathWithName:@"chm__After.html"];
#endif
	
}



#if MD_DEBUG_DUMP_TO_FILES
- (void)writeDebugDataToDebugPathWithName:(NSString *)aName {
	static NSDateFormatter *dateFormatter = nil;
	
	if (dateFormatter == nil) {
		dateFormatter = [[NSDateFormatter alloc] init];
		dateFormatter.dateStyle = NSDateFormatterShortStyle;
		dateFormatter.timeStyle = NSDateFormatterMediumStyle;
	}
	
	NSString *baseName = [aName stringByDeletingPathExtension];
	NSString *uniqueBaseName = [baseName stringByAppendingFormat:@"__%@__", [dateFormatter stringFromDate:[NSDate date]]];
	
	uniqueBaseName = [uniqueBaseName stringByReplacingOccurrencesOfString:@":" withString:@""];
	uniqueBaseName = [uniqueBaseName stringByReplacingOccurrencesOfString:@"/" withString:@"-"];
	uniqueBaseName = [uniqueBaseName stringByReplacingOccurrencesOfString:@", " withString:@"__"];
	
	NSString *uniqueName = [uniqueBaseName stringByAppendingPathExtension:[aName pathExtension]];
	
	NSData *debugData = [self adaptedHTMLData];
	NSError *error = nil;
	
	if (![debugData writeToFile:[MDDesktopDebugFolderPath stringByAppendingPathComponent:uniqueName] options:NSDataWritingAtomic error:&error]) {
		NSLog(@"*** ERROR: failed to write debugData to \"%@\", error == %@", [MDDesktopDebugFolderPath stringByAppendingPathComponent:uniqueName], error);
	}
}
#endif


@end

