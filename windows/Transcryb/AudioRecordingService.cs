using NAudio.Wave;
using System.Diagnostics;

namespace Transcryb
{
    /// <summary>
    /// Service for recording audio from the microphone
    /// </summary>
    public class AudioRecordingService : IDisposable
    {
private WaveInEvent? waveIn;
        private WaveFileWriter? waveWriter;
        private string? currentRecordingPath;
     private bool isRecording;

        public event EventHandler<string>? RecordingCompleted;
 public event EventHandler<string>? RecordingError;

        public bool IsRecording => isRecording;

        /// <summary>
        /// Start recording audio from the default microphone
      /// </summary>
        public void StartRecording()
     {
   if (isRecording)
     return;

        try
     {
    // Create temp file for recording
   currentRecordingPath = Path.Combine(Path.GetTempPath(), $"transcryb_{Guid.NewGuid()}.wav");

// Initialize audio input device
      waveIn = new WaveInEvent
            {
               WaveFormat = new WaveFormat(16000, 1) // 16kHz, mono - optimal for Whisper
       };

          // Create wave file writer
      waveWriter = new WaveFileWriter(currentRecordingPath, waveIn.WaveFormat);

                // Wire up data available event
        waveIn.DataAvailable += OnDataAvailable;
            waveIn.RecordingStopped += OnRecordingStopped;

    // Start recording
                waveIn.StartRecording();
     isRecording = true;

        Debug.WriteLine($"Recording started: {currentRecordingPath}");
     }
            catch (Exception ex)
        {
         isRecording = false;
          RecordingError?.Invoke(this, $"Failed to start recording: {ex.Message}");
             Debug.WriteLine($"Recording error: {ex}");
            }
        }

        /// <summary>
        /// Stop recording and return the path to the recorded file
        /// </summary>
     public void StopRecording()
     {
    if (!isRecording)
return;

            try
{
         isRecording = false;
                waveIn?.StopRecording();
             Debug.WriteLine("Recording stopped");
    }
  catch (Exception ex)
      {
     RecordingError?.Invoke(this, $"Failed to stop recording: {ex.Message}");
        Debug.WriteLine($"Stop recording error: {ex}");
            }
        }

        private void OnDataAvailable(object? sender, WaveInEventArgs e)
        {
            // Write recorded audio data to file
     waveWriter?.Write(e.Buffer, 0, e.BytesRecorded);
        }

        private void OnRecordingStopped(object? sender, StoppedEventArgs e)
     {
          // Clean up
  waveWriter?.Dispose();
        waveWriter = null;

      waveIn?.Dispose();
            waveIn = null;

            // Fire completion event with file path
if (!string.IsNullOrEmpty(currentRecordingPath) && File.Exists(currentRecordingPath))
 {
   RecordingCompleted?.Invoke(this, currentRecordingPath);
     }

   if (e.Exception != null)
         {
       RecordingError?.Invoke(this, $"Recording stopped with error: {e.Exception.Message}");
    Debug.WriteLine($"Recording stopped with error: {e.Exception}");
            }
        }

        public void Dispose()
        {
            if (isRecording)
       {
  StopRecording();
            }

      waveWriter?.Dispose();
      waveIn?.Dispose();
        }
    }
}
