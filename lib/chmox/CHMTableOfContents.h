//
// Chmox a CHM file viewer for Mac OS X
// Copyright (c) 2004 St�phane Boisson.
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
// $Revision: 1.2 $
//

#import <Foundation/Foundation.h>

@class CHMTopic;
@class CHMContainer;

@interface CHMTableOfContents : NSObject {
    NSMutableArray		*rootTopics;
}

- (id)initWithContainer:(CHMContainer *)container;
- (void)addRootTopic:(CHMTopic *)topic;

@end
