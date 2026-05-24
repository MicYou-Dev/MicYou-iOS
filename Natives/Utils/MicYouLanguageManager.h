#import <Foundation/Foundation.h>

@interface MicYouLanguageManager : NSObject

+ (instancetype)shared;

- (NSString *)localizedStringForKey:(NSString *)key;

/**
 * Set the language override.
 * Pass "system" to follow OS language, or a specific locale code:
 * "zh-Hans", "en", "zh-Hant"
 */
- (void)setLanguage:(NSString *)languageCode;

/**
 * Returns the current effective language code.
 * "system" when following OS, else "zh-Hans" / "en" / "zh-Hant"
 */
- (NSString *)currentLanguage;

/**
 * Post notification to inform observers that the language changed
 * so they can reload their localized UI.
 */
- (void)applyLanguage;

@end