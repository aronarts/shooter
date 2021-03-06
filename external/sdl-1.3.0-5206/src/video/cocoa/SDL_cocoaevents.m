/*
    SDL - Simple DirectMedia Layer
    Copyright (C) 1997-2009 Sam Lantinga

    This library is free software; you can redistribute it and/or
    modify it under the terms of the GNU Lesser General Public
    License as published by the Free Software Foundation; either
    version 2.1 of the License, or (at your option) any later version.

    This library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public
    License along with this library; if not, write to the Free Software
    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA

    Sam Lantinga
    slouken@libsdl.org
*/
#include "SDL_config.h"
#include "SDL_timer.h"

#include "SDL_cocoavideo.h"
#include "../../events/SDL_events_c.h"


/* setAppleMenu disappeared from the headers in 10.4 */
#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_4
@interface NSApplication(NSAppleMenu)
- (void)setAppleMenu:(NSMenu *)menu;
@end
#endif

@implementation NSApplication(SDL)
- (void)setRunning
{
    _running = 1;
}
@end

@interface SDLAppDelegate : NSObject
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender;
@end

@implementation SDLAppDelegate : NSObject
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
    SDL_SendQuit();
    return NSTerminateCancel;
}
@end

static NSString *
GetApplicationName(void)
{
    NSDictionary *dict;
    NSString *appName = 0;

    /* Determine the application name */
    dict = (NSDictionary *)CFBundleGetInfoDictionary(CFBundleGetMainBundle());
    if (dict)
        appName = [dict objectForKey: @"CFBundleName"];
    
    if (![appName length])
        appName = [[NSProcessInfo processInfo] processName];

    return appName;
}

static void
CreateApplicationMenus(void)
{
    NSString *appName;
    NSString *title;
    NSMenu *appleMenu;
    NSMenu *windowMenu;
    NSMenuItem *menuItem;
    
    /* Create the main menu bar */
    [NSApp setMainMenu:[[NSMenu alloc] init]];

    /* Create the application menu */
    appName = GetApplicationName();
    appleMenu = [[NSMenu alloc] initWithTitle:@""];
    
    /* Add menu items */
    title = [@"About " stringByAppendingString:appName];
    [appleMenu addItemWithTitle:title action:@selector(orderFrontStandardAboutPanel:) keyEquivalent:@""];

    [appleMenu addItem:[NSMenuItem separatorItem]];

    title = [@"Hide " stringByAppendingString:appName];
    [appleMenu addItemWithTitle:title action:@selector(hide:) keyEquivalent:@/*"h"*/""];

    menuItem = (NSMenuItem *)[appleMenu addItemWithTitle:@"Hide Others" action:@selector(hideOtherApplications:) keyEquivalent:@/*"h"*/""];
    [menuItem setKeyEquivalentModifierMask:(NSAlternateKeyMask|NSCommandKeyMask)];

    [appleMenu addItemWithTitle:@"Show All" action:@selector(unhideAllApplications:) keyEquivalent:@""];

    [appleMenu addItem:[NSMenuItem separatorItem]];

    title = [@"Quit " stringByAppendingString:appName];
    [appleMenu addItemWithTitle:title action:@selector(terminate:) keyEquivalent:@/*"q"*/""];
    
    /* Put menu into the menubar */
    menuItem = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
    [menuItem setSubmenu:appleMenu];
    [[NSApp mainMenu] addItem:menuItem];
    [menuItem release];

    /* Tell the application object that this is now the application menu */
    [NSApp setAppleMenu:appleMenu];
    [appleMenu release];


    /* Create the window menu */
    windowMenu = [[NSMenu alloc] initWithTitle:@"Window"];
    
    /* "Minimize" item */
    menuItem = [[NSMenuItem alloc] initWithTitle:@"Minimize" action:@selector(performMiniaturize:) keyEquivalent:@/*"m"*/""];
    [windowMenu addItem:menuItem];
    [menuItem release];
    
    /* Put menu into the menubar */
    menuItem = [[NSMenuItem alloc] initWithTitle:@"Window" action:nil keyEquivalent:@""];
    [menuItem setSubmenu:windowMenu];
    [[NSApp mainMenu] addItem:menuItem];
    [menuItem release];
    
    /* Tell the application object that this is now the window menu */
    [NSApp setWindowsMenu:windowMenu];
    [windowMenu release];
}

void
Cocoa_RegisterApp(void)
{
    ProcessSerialNumber psn;
    NSAutoreleasePool *pool;

    if (!GetCurrentProcess(&psn)) {
        TransformProcessType(&psn, kProcessTransformToForegroundApplication);
        SetFrontProcess(&psn);
    }

    pool = [[NSAutoreleasePool alloc] init];
    if (NSApp == nil) {
        [NSApplication sharedApplication];

        if ([NSApp mainMenu] == nil) {
            CreateApplicationMenus();
        }
        [NSApp finishLaunching];
    }
    if ([NSApp delegate] == nil) {
        [NSApp setDelegate:[[SDLAppDelegate alloc] init]];
    }
    [NSApp setRunning];
    [pool release];
}

void
Cocoa_PumpEvents(_THIS)
{
    NSAutoreleasePool *pool;

    /* Update activity every 30 seconds to prevent screensaver */
    /* FIXME: This define isn't available with 64-bit Mac OS X? */
#ifdef UsrActivity
    if (_this->suspend_screensaver) {
        SDL_VideoData *data = (SDL_VideoData *)_this->driverdata;
        Uint32 now = SDL_GetTicks();
        if (!data->screensaver_activity ||
            (int)(now-data->screensaver_activity) >= 30000) {
            UpdateSystemActivity(UsrActivity);
            data->screensaver_activity = now;
        }
    }
#endif

    pool = [[NSAutoreleasePool alloc] init];
    while ([NSApp isRunning]) {
        NSEvent *event = [NSApp nextEventMatchingMask:NSAnyEventMask untilDate:[NSDate distantPast] inMode:NSDefaultRunLoopMode dequeue:YES ];
        if ( event == nil ) {
            break;
        }
        switch ([event type]) {
        case NSKeyDown:
        case NSKeyUp:
        case NSFlagsChanged:
            Cocoa_HandleKeyEvent(_this, event);
            /* Fall through to pass event to NSApp; er, nevermind... */
            /* FIXME: Find a way to stop the beeping, using delegate */

            /* Add to support system-wide keyboard shortcuts like CMD+Space */
            if (([event modifierFlags] & NSCommandKeyMask) || [event type] == NSFlagsChanged)
               [NSApp sendEvent: event];
            break;
        default:
            [NSApp sendEvent:event];
            break;
        }
    }
    [pool release];
}

/* vi: set ts=4 sw=4 expandtab: */
