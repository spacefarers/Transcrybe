using System.Diagnostics;

namespace Transcryb
{
    /// <summary>
    /// Service for transcribing audio using whisper.cpp
    /// </summary>
    public class WhisperTranscriptionService
    {
        private readonly string whisperExecutablePath;
        private readonly string modelsDirectory;
        private string currentModel = "base";

        public event EventHandler<string>? TranscriptionCompleted;
        public event EventHandler<string>? TranscriptionError;
        public event EventHandler<string>? TranscriptionStatus;

        public bool IsTranscribing { get; private set; }

        public WhisperTranscriptionService()
        {
            // Path to whisper-cli.exe
            whisperExecutablePath = Path.Combine(
                AppDomain.CurrentDomain.BaseDirectory,
                "whisper.cpp",
                "whisper-cli.exe"
            );

            // Path to models directory
            var localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
            modelsDirectory = Path.Combine(localAppData, "Transcryb", "models");

            // Create models directory if it doesn't exist
            if (!Directory.Exists(modelsDirectory))
            {
                Directory.CreateDirectory(modelsDirectory);
            }

            Debug.WriteLine($"Whisper executable: {whisperExecutablePath}");
            Debug.WriteLine($"Models directory: {modelsDirectory}");
        }

        /// <summary>
        /// Set the Whisper model to use (tiny, base, small, medium, large)
        /// </summary>
        public void SetModel(string modelName)
        {
            currentModel = modelName.ToLower();
            Debug.WriteLine($"Whisper model set to: {currentModel}");
        }

        /// <summary>
        /// Check if a model file exists
        /// </summary>
        public bool IsModelAvailable(string modelName)
        {
            var modelPath = GetModelPath(modelName);
            return File.Exists(modelPath);
        }

        /// <summary>
        /// Get the full path to a model file
        /// </summary>
        private string GetModelPath(string modelName)
        {
            return Path.Combine(modelsDirectory, $"ggml-{modelName}.bin");
        }

        /// <summary>
        /// Transcribe an audio file
        /// </summary>
        public async Task TranscribeAsync(string audioFilePath)
        {
            if (IsTranscribing)
            {
                Debug.WriteLine("Already transcribing, ignoring request");
                return;
            }

            if (!File.Exists(whisperExecutablePath))
            {
                var error = $"Whisper executable not found at: {whisperExecutablePath}";
                TranscriptionError?.Invoke(this, error);
                Debug.WriteLine(error);
                return;
            }

            if (!File.Exists(audioFilePath))
            {
                var error = $"Audio file not found: {audioFilePath}";
                TranscriptionError?.Invoke(this, error);
                Debug.WriteLine(error);
                return;
            }

            var modelPath = GetModelPath(currentModel);
            if (!File.Exists(modelPath))
            {
                var error = $"Model file not found: {modelPath}. Please download the model first.";
                TranscriptionError?.Invoke(this, error);
                Debug.WriteLine(error);
                return;
            }

            IsTranscribing = true;
            TranscriptionStatus?.Invoke(this, "Starting transcription...");

            try
            {
                await Task.Run(() => RunWhisperProcess(audioFilePath, modelPath));
            }
            catch (Exception ex)
            {
                TranscriptionError?.Invoke(this, $"Transcription failed: {ex.Message}");
                Debug.WriteLine($"Transcription error: {ex}");
            }
            finally
            {
                IsTranscribing = false;

                // Clean up the temporary audio file
                try
                {
                    if (File.Exists(audioFilePath))
                    {
                        File.Delete(audioFilePath);
                        Debug.WriteLine($"Deleted temporary audio file: {audioFilePath}");
                    }
                }
                catch (Exception ex)
                {
                    Debug.WriteLine($"Failed to delete temp file: {ex.Message}");
                }
            }
        }

        private void RunWhisperProcess(string audioFilePath, string modelPath)
        {
            var startInfo = new ProcessStartInfo
            {
                FileName = whisperExecutablePath,
                Arguments = $"-m \"{modelPath}\" -f \"{audioFilePath}\" --no-timestamps --output-txt",
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                CreateNoWindow = true,
                WorkingDirectory = Path.GetDirectoryName(whisperExecutablePath)
            };

            Debug.WriteLine($"Running: {startInfo.FileName} {startInfo.Arguments}");

            using (var process = new Process { StartInfo = startInfo })
            {
                var output = new System.Text.StringBuilder();
                var error = new System.Text.StringBuilder();

                process.OutputDataReceived += (sender, e) =>
                {
                    if (!string.IsNullOrEmpty(e.Data))
                    {
                        output.AppendLine(e.Data);
                        Debug.WriteLine($"Whisper output: {e.Data}");
                        TranscriptionStatus?.Invoke(this, e.Data);
                    }
                };

                process.ErrorDataReceived += (sender, e) =>
                {
                    if (!string.IsNullOrEmpty(e.Data))
                    {
                        error.AppendLine(e.Data);
                        Debug.WriteLine($"Whisper error: {e.Data}");
                    }
                };

                process.Start();
                process.BeginOutputReadLine();
                process.BeginErrorReadLine();
                process.WaitForExit();

                var exitCode = process.ExitCode;
                Debug.WriteLine($"Whisper process exited with code: {exitCode}");

                if (exitCode == 0)
                {
                    // Check for output .txt file (whisper creates one)
                    var outputTxtPath = Path.ChangeExtension(audioFilePath, ".txt");
                    if (File.Exists(outputTxtPath))
                    {
                        var transcription = File.ReadAllText(outputTxtPath);
                        transcription = transcription.Trim();

                        Debug.WriteLine($"Transcription result: {transcription}");
                        TranscriptionCompleted?.Invoke(this, transcription);

                        // Clean up output file
                        try
                        {
                            File.Delete(outputTxtPath);
                        }
                        catch { }
                    }
                    else
                    {
                        // Parse from stdout
                        var result = output.ToString().Trim();
                        if (!string.IsNullOrEmpty(result))
                        {
                            Debug.WriteLine($"Transcription result: {result}");
                            TranscriptionCompleted?.Invoke(this, result);
                        }
                        else
                        {
                            TranscriptionError?.Invoke(this, "No transcription output received");
                        }
                    }
                }
                else
                {
                    var errorMsg = error.ToString();
                    TranscriptionError?.Invoke(this, $"Whisper failed: {errorMsg}");
                }
            }
        }
    }
}
