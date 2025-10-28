//
//  WhisperBridge.h
//  Transcrybe
//
//  Objective-C bridge for Whisper C API
//

#ifndef WhisperBridge_h
#define WhisperBridge_h

#import <Foundation/Foundation.h>

@interface WhisperBridge : NSObject

- (instancetype _Nullable)initWithModelPath:(NSString * _Nonnull)modelPath;
- (NSString * _Nullable)transcribeAudioSamples:(NSArray<NSNumber *> * _Nonnull)samples;

@end

#endif /* WhisperBridge_h */
