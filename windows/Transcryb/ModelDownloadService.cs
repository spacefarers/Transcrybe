using System.Diagnostics;

namespace Transcryb
{
    /// <summary>
    /// Service for downloading Whisper models from HuggingFace
    /// </summary>
    public class ModelDownloadService
    {
        private readonly string modelsDirectory;
 private readonly HttpClient httpClient;

        public event EventHandler<int>? DownloadProgressChanged;
     public event EventHandler<string>? DownloadCompleted;
        public event EventHandler<string>? DownloadError;

        private static readonly Dictionary<string, string> ModelUrls = new()
        {
    { "tiny", "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin" },
            { "base", "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin" },
     { "small", "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin" },
        { "medium", "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.bin" },
         { "large", "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3.bin" }
        };

        private static readonly Dictionary<string, long> ModelSizes = new()
        {
            { "tiny", 75_000_000 },      // ~75 MB
            { "base", 142_000_000 },     // ~142 MB
            { "small", 466_000_000 },    // ~466 MB
      { "medium", 1_500_000_000 }, // ~1.5 GB
            { "large", 3_100_000_000 }   // ~3.1 GB
        };

        public ModelDownloadService()
        {
            var localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
            modelsDirectory = Path.Combine(localAppData, "Transcryb", "models");

            if (!Directory.Exists(modelsDirectory))
            {
                Directory.CreateDirectory(modelsDirectory);
            }

            httpClient = new HttpClient
{
       Timeout = TimeSpan.FromHours(2) // Long timeout for large models
            };
     }

      public bool IsModelDownloaded(string modelName)
    {
          var modelPath = GetModelPath(modelName);
      return File.Exists(modelPath);
   }

        public string GetModelPath(string modelName)
     {
            return Path.Combine(modelsDirectory, $"ggml-{modelName}.bin");
        }

   public long GetModelSize(string modelName)
        {
            return ModelSizes.TryGetValue(modelName, out var size) ? size : 0;
        }

        public string GetModelSizeFormatted(string modelName)
        {
            var bytes = GetModelSize(modelName);
      if (bytes >= 1_000_000_000)
            return $"{bytes / 1_000_000_000.0:F1} GB";
   else
    return $"{bytes / 1_000_000:F0} MB";
        }

public async Task DownloadModelAsync(string modelName)
        {
            if (!ModelUrls.TryGetValue(modelName, out var url))
            {
        DownloadError?.Invoke(this, $"Unknown model: {modelName}");
 return;
            }

            var modelPath = GetModelPath(modelName);
    var tempPath = modelPath + ".tmp";

    try
    {
        Debug.WriteLine($"Downloading model '{modelName}' from {url}");

                using (var response = await httpClient.GetAsync(url, HttpCompletionOption.ResponseHeadersRead))
                {
 response.EnsureSuccessStatusCode();

    var totalBytes = response.Content.Headers.ContentLength ?? ModelSizes[modelName];
       var downloadedBytes = 0L;

                 using (var contentStream = await response.Content.ReadAsStreamAsync())
      using (var fileStream = new FileStream(tempPath, FileMode.Create, FileAccess.Write, FileShare.None, 8192, true))
       {
        var buffer = new byte[8192];
         int bytesRead;

         while ((bytesRead = await contentStream.ReadAsync(buffer, 0, buffer.Length)) > 0)
    {
          await fileStream.WriteAsync(buffer, 0, bytesRead);
   downloadedBytes += bytesRead;

     var progressPercentage = (int)((downloadedBytes * 100) / totalBytes);
      DownloadProgressChanged?.Invoke(this, progressPercentage);

       Debug.WriteLine($"Download progress: {progressPercentage}% ({downloadedBytes:N0} / {totalBytes:N0} bytes)");
    }
         }
      }

  // Move temp file to final location
                if (File.Exists(modelPath))
              {
      File.Delete(modelPath);
                }
     File.Move(tempPath, modelPath);

         Debug.WriteLine($"Model '{modelName}' downloaded successfully to {modelPath}");
  DownloadCompleted?.Invoke(this, modelName);
            }
 catch (Exception ex)
    {
    Debug.WriteLine($"Download error: {ex.Message}");
       DownloadError?.Invoke(this, $"Failed to download model: {ex.Message}");

     // Clean up temp file
                try
    {
  if (File.Exists(tempPath))
     {
          File.Delete(tempPath);
        }
            }
    catch { }
            }
        }

        public bool DeleteModel(string modelName)
        {
            try
       {
            var modelPath = GetModelPath(modelName);
    if (File.Exists(modelPath))
        {
       File.Delete(modelPath);
    Debug.WriteLine($"Model '{modelName}' deleted successfully");
             return true;
    }
    return false;
 }
            catch (Exception ex)
{
                Debug.WriteLine($"Error deleting model: {ex.Message}");
       return false;
            }
  }
  }
}
