    //
//  NetworkActivityViewController.m
//  PassDrop
//
//  Created by Rudis Muiznieks on 2/12/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "NetworkActivityViewController.h"

@implementation NetworkActivityViewController

@synthesize loadingView;
@synthesize loadingMessage;

static int networkIndicatorReq;

- (void)viewDidLoad {
	networkIndicatorReq = 0;
	loadingMessage = @"Loading";
}

- (void)setWorking:(BOOL)working {
    self.view.userInteractionEnabled = !working;
	self.navigationController.view.userInteractionEnabled = !working;
	if (working) {
		loadingView = [[LoadingView alloc] initWithTitle:loadingMessage];
		[loadingView show];
	} else {
		[loadingView dismissAnimated:NO];
		[loadingView release];
		loadingView = nil;
	}
}

- (void)networkRequestStarted {
	UIApplication *app = [UIApplication sharedApplication];
	app.networkActivityIndicatorVisible = YES;
	if(networkIndicatorReq == 0){
		[self setWorking:YES];
	}
	networkIndicatorReq++;
}

- (void)networkRequestStopped {
	networkIndicatorReq--;
	if(networkIndicatorReq <= 0){
		UIApplication *app = [UIApplication sharedApplication];
		app.networkActivityIndicatorVisible = NO;
		networkIndicatorReq = 0;
		[self setWorking:NO];
	}
}

- (void)dealloc {
	[loadingMessage release];
    [super dealloc];
}


@end
