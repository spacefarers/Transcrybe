//
//  WhisperBridge.mm
//  Transcrybe
//
//  Objective-C++ bridge for Whisper C API
//

#import <Foundation/Foundation.h>
#include <vector>
#include "whisper/whisper.h"
#import "WhisperBridge.h"

@interface WhisperBridge () {
    @public
    whisper_context *_ctx;
}
@property (nonatomic, strong) NSString *modelPath;
@end

@implementation WhisperBridge

- (instancetype)initWithModelPath:(NSString *)modelPath {
    self = [super init];
    if (!self) return nil;

    whisper_context_params params = whisper_context_default_params();
    whisper_context *ctx = whisper_init_from_file_with_params([modelPath UTF8String], params);

    if (!ctx) {
        NSLog(@"Failed to initialize Whisper context");
        return nil;
    }

    _ctx = ctx;
    _modelPath = modelPath;
    NSLog(@"✓ Whisper model loaded: %@", modelPath);
    return self;
}

- (NSString *)transcribeAudioSamples:(NSArray<NSNumber *> *)audioSamples {
    if (!_ctx) {
        NSLog(@"Whisper context not initialized");
        return nil;
    }

    NSLog(@"Starting transcription with %lu audio samples...", audioSamples.count);

    // Convert NSArray to float array
    std::vector<float> samples;
    samples.reserve(audioSamples.count);
    for (NSNumber *sample in audioSamples) {
        samples.push_back([sample floatValue]);
    }

    // Prepare transcription parameters
    whisper_full_params params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
    params.print_realtime = false;
    params.print_progress = false;
    params.n_threads = 4;

    // Run transcription
    int result = whisper_full(_ctx, params, samples.data(), (int)samples.size());

    if (result != 0) {
        NSLog(@"Whisper transcription failed with error code: %d", result);
        return nil;
    }

    // Extract transcribed text from segments
    int nSegments = whisper_full_n_segments(_ctx);
    NSLog(@"Transcription produced %d segments", nSegments);

    NSMutableString *fullText = [NSMutableString string];
    for (int i = 0; i < nSegments; i++) {
        const char *segmentText = whisper_full_get_segment_text(_ctx, i);
        if (segmentText) {
            NSString *text = [NSString stringWithUTF8String:segmentText];
            [fullText appendString:text];
            NSLog(@"Segment %d: %@", i, text);
        }
    }

    NSLog(@"✓ Transcription completed. Result length: %lu characters", fullText.length);
    return fullText;
}

- (void)dealloc {
    if (_ctx) {
        whisper_free(_ctx);
        NSLog(@"Whisper context freed");
    }
}

@end
