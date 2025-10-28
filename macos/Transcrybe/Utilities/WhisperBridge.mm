//
//  WhisperBridge.mm
//  Transcrybe
//
//  Objective-C implementation of Whisper C API bridge
//

#import "WhisperBridge.h"
#include "whisper/whisper.h"
#import <os/log.h>

@interface WhisperBridge ()
@property (nonatomic, assign) struct whisper_context *whisperContext;
@property (nonatomic, strong) NSString *modelPath;
@end

@implementation WhisperBridge

- (instancetype _Nullable)initWithModelPath:(NSString * _Nonnull)modelPath {
    self = [super init];
    if (self) {
        self.modelPath = modelPath;

        // Initialize whisper context with model
        const char *modelPathCStr = [modelPath UTF8String];
        self.whisperContext = whisper_init_from_file(modelPathCStr);

        if (self.whisperContext == NULL) {
            os_log_error(OS_LOG_DEFAULT, "Failed to initialize whisper from model: %{public}@", modelPath);
            return nil;
        }

        os_log_info(OS_LOG_DEFAULT, "Successfully initialized whisper from model: %{public}@", modelPath);
    }
    return self;
}

- (NSString * _Nullable)transcribeAudioSamples:(NSArray<NSNumber *> * _Nonnull)samples {
    if (self.whisperContext == NULL) {
        os_log_error(OS_LOG_DEFAULT, "Whisper context is NULL");
        return nil;
    }

    if (samples.count == 0) {
        os_log_error(OS_LOG_DEFAULT, "No audio samples provided");
        return nil;
    }

    // Convert NSArray of NSNumbers to C float array
    float *audioSamples = (float *)malloc(sizeof(float) * samples.count);
    if (audioSamples == NULL) {
        os_log_error(OS_LOG_DEFAULT, "Failed to allocate memory for audio samples");
        return nil;
    }

    for (NSUInteger i = 0; i < samples.count; i++) {
        audioSamples[i] = [samples[i] floatValue];
    }

    // Run whisper
    struct whisper_full_params wparams = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
    int result = whisper_full(self.whisperContext, wparams, audioSamples, (int)samples.count);

    free(audioSamples);

    if (result != 0) {
        os_log_error(OS_LOG_DEFAULT, "Whisper full failed with result: %d", result);
        return nil;
    }

    // Get the result text
    NSMutableString *resultText = [NSMutableString string];
    int numSegments = whisper_full_n_segments(self.whisperContext);

    for (int i = 0; i < numSegments; i++) {
        const char *text = whisper_full_get_segment_text(self.whisperContext, i);
        if (text != NULL) {
            if (resultText.length > 0) {
                [resultText appendString:@" "];
            }
            [resultText appendString:[NSString stringWithUTF8String:text]];
        }
    }

    os_log_info(OS_LOG_DEFAULT, "Transcription completed. Result: %{public}@", resultText);
    return [resultText copy];
}

- (void)dealloc {
    if (self.whisperContext != NULL) {
        whisper_free(self.whisperContext);
        self.whisperContext = NULL;
    }
}

@end
