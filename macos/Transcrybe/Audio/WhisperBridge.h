//
//  WhisperBridge.h
//  Transcrybe
//
//  Objective-C bridge header for Whisper C API
//

#import <Foundation/Foundation.h>

@interface WhisperBridge : NSObject

- (instancetype)initWithModelPath:(NSString *)modelPath;
- (NSString *)transcribeAudioSamples:(NSArray<NSNumber *> *)audioSamples;

@end
