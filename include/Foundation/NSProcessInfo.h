#import <Foundation/NSObject.h>
#import <Foundation/NSDate.h>

enum {
    NSWindowsNTOperatingSystem = 1,
    NSWindows95OperatingSystem,
    NSSolarisOperatingSystem,
    NSHPUXOperatingSystem,
    NSMACHOperatingSystem,
    NSSunOSOperatingSystem,
    NSOSF1OperatingSystem,
    NSAndroidOperatingSystem,
};

typedef struct
{
	NSInteger majorVersion;
	NSInteger minorVersion;
	NSInteger patchVersion;
}
NSOperatingSystemVersion;

@class NSArray, NSString, NSDictionary;

@interface NSProcessInfo : NSObject
{
    NSDictionary *environment; // not used it seems
    NSArray *arguments; // is really mutable
    NSString *hostName; // singly created
    NSString *name; // singly created, but replaceable
    NSInteger automaticTerminationOptOutCounter;
}

+ (NSProcessInfo *)processInfo;

- (NSDictionary *)environment;
- (NSArray *)arguments;
- (NSString *)hostName;
- (NSString *)processName;
- (int)processIdentifier;
- (void)setProcessName:(NSString *)newName;
- (NSString *)globallyUniqueString;
- (NSUInteger)operatingSystem;
- (NSString *)operatingSystemName;
- (NSString *)operatingSystemVersionString;
- (NSUInteger)processorCount;
- (NSUInteger)activeProcessorCount;
- (unsigned long long)physicalMemory;
- (NSTimeInterval)systemUptime;
- (NSOperatingSystemVersion)operatingSystemVersion;
- (BOOL)isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion)version;

@end

typedef NS_OPTIONS(uint64_t, NSActivityOptions) {
    NSActivityIdleDisplaySleepDisabled = (1ULL << 40),
    NSActivityIdleSystemSleepDisabled = (1ULL << 20),
    NSActivitySuddenTerminationDisabled = (1ULL << 14),
    NSActivityAutomaticTerminationDisabled = (1ULL << 15),
    NSActivityAnimationTrackingEnabled = (1ULL << 45),
    NSActivityTrackingEnabled = (1ULL << 46),
    NSActivityUserInitiated = (0x00FFFFFFULL | NSActivityIdleSystemSleepDisabled),
    NSActivityUserInitiatedAllowingIdleSystemSleep = (NSActivityUserInitiated & ~NSActivityIdleSystemSleepDisabled),
    NSActivityBackground = 0x000000FFULL,
    NSActivityLatencyCritical = 0xFF00000000ULL,
    NSActivityUserInteractive = (NSActivityUserInitiated | NSActivityLatencyCritical),
};

@interface NSProcessInfo (NSProcessInfoActivity)
- (id <NSObject>)beginActivityWithOptions:(NSActivityOptions)options reason:(NSString *)reason;
- (void)endActivity:(id <NSObject>)activity;
- (void)performActivityWithOptions:(NSActivityOptions)options reason:(NSString *)reason usingBlock:(void (^)(void))block;
- (void)performExpiringActivityWithReason:(NSString *)reason usingBlock:(void (^)(BOOL expired))block;
@end

@interface NSProcessInfo (NSProcessInfoPlatform)
-(BOOL)isMacCatalystApp;
-(BOOL)isiOSAppOnMac;
@property(readonly, getter=isMacCatalystApp) BOOL macCatalystApp;
@property(readonly, getter=isiOSAppOnMac) BOOL iOSAppOnMac;
@end

#ifdef DARLING
FOUNDATION_EXPORT void __NSInitializeProcess(int argc,const char *argv[]);
#endif
