//
//  ViewController.m
//  SnowflakesMaker
//
//  Created by Oleksiy Radyvanyuk on 1/2/13.
//  Copyright (c) 2013 Oleksiy Radyvanyuk. All rights reserved.
//

#import "ViewController.h"

NSInteger const kMinRects = 10;
NSInteger const kMaxRects = 20;
CGFloat const kMinRectSizeRatio = 0.02f;
CGFloat const kMaxRectSizeRatio = 0.5f;

NSInteger const kNumberOfSnowflakes = 128;
CGFloat const kMinSnowflakeRatio = 0.05f;
CGFloat const kMaxSnowflakeRatio = 0.1f;
NSTimeInterval const kTimerRate = 0.1;
CGFloat const kFallSpeed = 5.0f;
NSInteger const kMinPhases = 1;
NSInteger const kMaxPhases = 3;

@interface ViewController ()

- (CGImageRef)randomizeOneSnowflakeBranchInRect:(CGRect)rect;
- (UIImage *)createSnowflake;

@end

@implementation ViewController {
    NSMutableArray *snowflakes;
}

- (CGImageRef)randomizeOneSnowflakeBranchInRect:(CGRect)rect {
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL, rect.size.width, rect.size.height, 8, rect.size.width * 4, cs, kCGImageAlphaPremultipliedLast);

    CGContextSetStrokeColorWithColor(context, [UIColor whiteColor].CGColor);
    CGContextClearRect(context, rect);

    // going top to bottom in the middle of the image
    CGContextMoveToPoint(context, CGRectGetMidX(rect), CGRectGetMaxY(rect));
    CGContextAddLineToPoint(context, CGRectGetMidX(rect), CGRectGetMinY(rect));
    CGContextDrawPath(context, kCGPathStroke);

    NSInteger numRects = kMinRects + lroundf((CGFloat)random() / RAND_MAX * (kMaxRects - kMinRects));
    CGFloat h = CGRectGetHeight(rect);
    for (NSInteger i = 0; i < numRects; i++) {
        // calculating random size of the square
        CGFloat rectExtent = roundf(h * (kMinRectSizeRatio + (CGFloat)random() / RAND_MAX * (kMaxRectSizeRatio - kMinRectSizeRatio)));
        CGRect square = CGRectMake(0.0f, 0.0f, rectExtent, rectExtent);

        // calculate random position of the rect on line, excluding edge cases
        CGFloat minY = CGRectGetMinY(rect) + rectExtent / 2;
        CGFloat maxY = CGRectGetMaxY(rect) - rectExtent / 2;
        CGFloat yPos = roundf(minY + (CGFloat)random() / RAND_MAX * (maxY - minY));

        // shifting square to the middle of the rect horizontally
        // and by the random amount of points vertically
        square = CGRectOffset(square, CGRectGetMidX(rect) - rectExtent / 2, yPos);

        // centering and rotating context so that the rect is drawn as a romb
        CGContextSaveGState(context);
        CGContextTranslateCTM(context, CGRectGetMidX(square), CGRectGetMidY(square));
        CGContextRotateCTM(context, M_PI_4);
        CGRect bounds = CGRectMake(0.0f, 0.0f, square.size.width, square.size.height);
        // draw line from bottom left to bottom right corner
        CGContextMoveToPoint(context, CGRectGetMinX(bounds), CGRectGetMinY(bounds));
        CGContextAddLineToPoint(context, CGRectGetMaxX(bounds), CGRectGetMinY(bounds));
        // draw line from bottom left to top left corner
        CGContextMoveToPoint(context, CGRectGetMinX(bounds), CGRectGetMinY(bounds));
        CGContextAddLineToPoint(context, CGRectGetMinX(bounds), CGRectGetMaxY(bounds));
        // stroke the lines
        CGContextStrokePath(context);
        CGContextRestoreGState(context);
    }

    CGImageRef imageRef = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    CGColorSpaceRelease(cs);
    return imageRef;
}

- (UIImage *)createSnowflake {
    // creating image for the quarter size of the image view
    CGSize size = self.imgView.frame.size;
    size.width = roundf(size.width / 4);
    size.height = roundf(size.height / 4);
    CGRect rect = CGRectMake(0.0f, 0.0f, floorf(size.width / 2), floorf(size.height / 2));

    CGImageRef branchRef = [self randomizeOneSnowflakeBranchInRect:rect];

    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL, size.width, size.height, 8, size.width * 4, cs, kCGImageAlphaPremultipliedLast);
    CGRect bounds = CGRectMake(0.0f, 0.0f, rect.size.width, rect.size.height);

    CGContextTranslateCTM(context, CGRectGetMidX(rect), CGRectGetMaxY(rect));
    CGContextDrawImage(context, bounds, branchRef);

    CGFloat deltaAngle = -M_PI / 3;
    CGFloat dX = CGRectGetMidX(rect)*cosf(deltaAngle);
    CGFloat dY = -CGRectGetMidY(rect)*sinf(deltaAngle);

    for (int i = 1; i < 6; i++) {
        CGContextTranslateCTM(context, dX, dY);
        CGContextRotateCTM(context, deltaAngle);
        CGContextDrawImage(context, bounds, branchRef);
    }

    CGImageRef imageRef = CGBitmapContextCreateImage(context);
    UIImage *image = [UIImage imageWithCGImage:imageRef];

    // tidy up
    CGImageRelease(branchRef);
    CGImageRelease(imageRef);
    CGContextRelease(context);
    CGColorSpaceRelease(cs);

    return image;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    NSDate *date = [NSDate date];
    srandom((unsigned int)(NSTimeIntervalSince1970 - [date timeIntervalSinceReferenceDate]));

    self.imgView.image = [self createSnowflake];

    snowflakes = [[NSMutableArray alloc] initWithCapacity:kNumberOfSnowflakes];
    [NSTimer scheduledTimerWithTimeInterval:kTimerRate target:self selector:@selector(onTimer:) userInfo:nil repeats:YES];
}

- (IBAction)onRefresh:(id)sender {
    self.imgView.image = [self createSnowflake];
}

- (void)onTimer:(NSTimer *)timer {
    NSMutableArray *flakesToRemove = [[NSMutableArray alloc] init];

    // move existing snowflakes down one step
    [snowflakes enumerateObjectsUsingBlock:^(UIImageView *snowflake, NSUInteger idx, BOOL *stop) {
        CGFloat fallSpeed = kFallSpeed;

        CGRect frame = snowflake.frame;
        frame.origin.y += fallSpeed;
        CGFloat x = frame.origin.y / self.view.frame.size.height * snowflake.tag * M_PI;
        frame.origin.x += kFallSpeed * sinf(x) * cosf(x);
        snowflake.frame = frame;

        // if the snowflake falls off the screen, mark it for removal
        if (frame.origin.y > self.view.frame.size.height) {
            [flakesToRemove addObject:snowflake];
            [snowflake removeFromSuperview];
        }
    }];

    // remove snowflakes that are out of view
    [snowflakes removeObjectsInArray:flakesToRemove];

    // add new snowflake
    if ([snowflakes count] < kNumberOfSnowflakes) {
        CGFloat flakeSize = self.view.frame.size.width * (kMinSnowflakeRatio + (CGFloat)random() / RAND_MAX * (kMaxSnowflakeRatio - kMinSnowflakeRatio));
        CGFloat minX = 0.0f;
        CGFloat maxX = self.view.frame.size.width - flakeSize / 2;
        CGFloat flakeX = minX + (CGFloat)random() / RAND_MAX * (maxX - minX);
        CGRect flakeFrame = CGRectIntegral(CGRectMake(flakeX, -flakeSize, flakeSize, flakeSize));
        UIImageView *snowflake = [[UIImageView alloc] initWithFrame:flakeFrame];
        // choosing random value of number of phases
        snowflake.tag = kMinPhases + lroundf((CGFloat)random() / RAND_MAX * (kMaxPhases - kMinPhases));
        snowflake.image = [self createSnowflake];
        [self.view addSubview:snowflake];
        [snowflakes addObject:snowflake];
    }
}

@end
