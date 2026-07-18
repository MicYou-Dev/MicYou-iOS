#import "MicYouUpdateChecker.h"
#import "MicYouLogger.h"

static NSString * const kMicYouGitHubReleaseAPI = @"https://api.github.com/repos/MicYou-Dev/MicYou-iOS/releases/latest";
static NSString * const kMicYouGitHubUserAgent = @"MicYou-iOS/UpdateChecker";

@implementation MicYouUpdateChecker

+ (instancetype)shared {
    static MicYouUpdateChecker *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[MicYouUpdateChecker alloc] init];
    });
    return instance;
}

- (NSString *)currentAppVersion {
    NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    if (version.length == 0) {
        version = [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString *)kCFBundleVersionKey];
    }
    if (version.length == 0) {
        return @"0.0.0";
    }
    return version;
}

- (void)checkForUpdateWithCompletion:(void (^)(MicYouUpdateStatus, NSString * _Nullable, NSURL * _Nullable))completion {
    NSURL *url = [NSURL URLWithString:kMicYouGitHubReleaseAPI];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"GET"];
    [request setValue:kMicYouGitHubUserAgent forHTTPHeaderField:@"User-Agent"];
    [request setValue:@"application/vnd.github+json" forHTTPHeaderField:@"Accept"];

    NSURLSessionTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request
                                                              completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        [self handleUpdateResponse:data response:response error:error completion:completion];
    }];
    [task resume];
}

#pragma mark - Response handling

- (void)handleUpdateResponse:(NSData *)data
                    response:(NSURLResponse *)response
                       error:(NSError *)error
                  completion:(void (^)(MicYouUpdateStatus, NSString * _Nullable, NSURL * _Nullable))completion {
    if (error) {
        [[MicYouLogger sharedLogger] logError:
            [NSString stringWithFormat:@"UpdateChecker: network error %@", error.localizedDescription]];
        [self deliverStatus:MicYouUpdateStatusError latestVersion:nil releaseURL:nil completion:completion];
        return;
    }

    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    NSInteger statusCode = httpResponse.statusCode;
    if (statusCode != 200) {
        [[MicYouLogger sharedLogger] logError:
            [NSString stringWithFormat:@"UpdateChecker: HTTP %ld", (long)statusCode]];
        [self deliverStatus:MicYouUpdateStatusError latestVersion:nil releaseURL:nil completion:completion];
        return;
    }

    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data
                                                         options:NSJSONReadingAllowFragments
                                                           error:&error];
    if (error || ![json isKindOfClass:[NSDictionary class]]) {
        NSString *detail = error ? error.localizedDescription : @"unexpected JSON structure";
        [[MicYouLogger sharedLogger] logError:
            [NSString stringWithFormat:@"UpdateChecker: JSON parse error %@", detail]];
        [self deliverStatus:MicYouUpdateStatusError latestVersion:nil releaseURL:nil completion:completion];
        return;
    }

    NSString *tagName = json[@"tag_name"];
    NSString *htmlURLString = json[@"html_url"];
    if (tagName.length == 0) {
        [[MicYouLogger sharedLogger] logError:@"UpdateChecker: missing tag_name"];
        [self deliverStatus:MicYouUpdateStatusError latestVersion:nil releaseURL:nil completion:completion];
        return;
    }

    NSString *latestVersion = [tagName stringByReplacingOccurrencesOfString:@"v" withString:@"" options:NSAnchoredSearch range:NSMakeRange(0, tagName.length)];
    NSString *currentVersion = [self currentAppVersion];
    NSURL *releaseURL = htmlURLString.length > 0 ? [NSURL URLWithString:htmlURLString] : nil;

    BOOL hasUpdate = [self isNewerVersion:currentVersion than:latestVersion];
    [[MicYouLogger sharedLogger] log:
        [NSString stringWithFormat:@"UpdateChecker: current=%@ latest=%@ updateAvailable=%@",
            currentVersion, latestVersion, hasUpdate ? @"YES" : @"NO"]];

    MicYouUpdateStatus status = hasUpdate ? MicYouUpdateStatusUpdateAvailable : MicYouUpdateStatusUpToDate;
    [self deliverStatus:status latestVersion:latestVersion releaseURL:releaseURL completion:completion];
}

- (void)deliverStatus:(MicYouUpdateStatus)status
        latestVersion:(nullable NSString *)latestVersion
          releaseURL:(nullable NSURL *)releaseURL
           completion:(void (^)(MicYouUpdateStatus, NSString * _Nullable, NSURL * _Nullable))completion {
    if (!completion) {
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        completion(status, latestVersion, releaseURL);
    });
}

#pragma mark - Version comparison

/**
 * Returns YES when `latest` is strictly newer than `current`.
 * Mirrors the Android UpdateChecker#isNewerVersion logic:
 *   - strip leading "v"
 *   - split by "."
 *   - for each segment, drop anything after "-" (pre-release suffixes)
 *   - parse as int (non-numeric -> 0)
 *   - compare component-by-component, missing components treated as 0
 */
- (BOOL)isNewerVersion:(NSString *)current than:(NSString *)latest {
    NSArray<NSString *> *currentParts = [self versionComponents:current];
    NSArray<NSString *> *latestParts = [self versionComponents:latest];
    NSUInteger count = MAX(currentParts.count, latestParts.count);

    for (NSUInteger i = 0; i < count; i++) {
        NSInteger curr = i < currentParts.count ? [self numericValue:currentParts[i]] : 0;
        NSInteger late = i < latestParts.count ? [self numericValue:latestParts[i]] : 0;
        if (late != curr) {
            return late > curr;
        }
    }
    return NO;
}

- (NSArray<NSString *> *)versionComponents:(NSString *)version {
    if (version.length == 0) {
        return @[];
    }
    NSString *trimmed = version;
    if ([trimmed hasPrefix:@"v"] || [trimmed hasPrefix:@"V"]) {
        trimmed = [trimmed substringFromIndex:1];
    }
    return [trimmed componentsSeparatedByString:@"."];
}

- (NSInteger)numericValue:(NSString *)segment {
    // Drop any pre-release suffix such as "-beta1".
    NSString *numeric = [segment componentsSeparatedByString:@"-"].firstObject;
    return [numeric integerValue];
}

@end
