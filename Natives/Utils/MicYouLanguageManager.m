#import "MicYouLanguageManager.h"

static NSString * const kMicYouLanguageNotification = @"MicYouLanguageDidChange";
static NSString * const kMicYouLanguageKey = @"micyou_language";

@interface MicYouLanguageManager ()
@property (nonatomic, copy) NSString *languageCode;
@end

@implementation MicYouLanguageManager

+ (instancetype)shared {
    static MicYouLanguageManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[MicYouLanguageManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self loadLanguageFromDefaults];
    }
    return self;
}

- (void)loadLanguageFromDefaults {
    NSInteger langValue = [[NSUserDefaults standardUserDefaults] integerForKey:kMicYouLanguageKey];
    switch (langValue) {
        case 1: self.languageCode = @"zh-Hans"; break;
        case 2: self.languageCode = @"en";      break;
        case 3: self.languageCode = @"zh-Hant"; break;
        default: self.languageCode = @"system";  break;
    }
}

- (NSString *)localizedStringForKey:(NSString *)key {
    NSString *lang = self.languageCode ?: @"system";
    if ([lang isEqualToString:@"system"]) {
        return NSLocalizedString(key, nil);
    }
    // Load from specific bundle
    NSString *path = [[NSBundle mainBundle] pathForResource:lang ofType:@"lproj"];
    if (path) {
        NSBundle *bundle = [NSBundle bundleWithPath:path];
        return [bundle localizedStringForKey:key value:nil table:nil];
    }
    return NSLocalizedString(key, nil);
}

- (void)setLanguage:(NSString *)languageCode {
    self.languageCode = languageCode ?: @"system";
    // Persist to NSUserDefaults
    NSInteger langValue = 0;
    if ([languageCode isEqualToString:@"zh-Hans"]) {
        langValue = 1;
    } else if ([languageCode isEqualToString:@"en"]) {
        langValue = 2;
    } else if ([languageCode isEqualToString:@"zh-Hant"]) {
        langValue = 3;
    }
    [[NSUserDefaults standardUserDefaults] setInteger:langValue forKey:kMicYouLanguageKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSString *)currentLanguage {
    return self.languageCode ?: @"system";
}

- (void)applyLanguage {
    [self loadLanguageFromDefaults];
    [[NSNotificationCenter defaultCenter] postNotificationName:kMicYouLanguageNotification object:nil];
}

@end