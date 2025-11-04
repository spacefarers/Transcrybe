using System.Diagnostics;
using System.IO;
using System.Net.Security;
using System.Runtime.InteropServices;

namespace Transcryb
{
    public partial class SettingsForm : Form
    {
        // Windows API constants and structures for SendInput
        private const int INPUT_KEYBOARD = 1;
        private const uint KEYEVENTF_UNICODE = 0x0004;
        private const uint KEYEVENTF_KEYUP = 0x0002;

      [StructLayout(LayoutKind.Sequential)]
 private struct INPUT
   {
            public int type;
            public INPUTUNION u;
        }

        [StructLayout(LayoutKind.Explicit)]
        private struct INPUTUNION
        {
[FieldOffset(0)]
            public MOUSEINPUT mi;
            [FieldOffset(0)]
   public KEYBDINPUT ki;
         [FieldOffset(0)]
            public HARDWAREINPUT hi;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct KEYBDINPUT
        {
            public ushort wVk;
            public ushort wScan;
        public uint dwFlags;
            public uint time;
   public IntPtr dwExtraInfo;
 }

        [StructLayout(LayoutKind.Sequential)]
        private struct MOUSEINPUT
        {
            public int dx;
      public int dy;
         public uint mouseData;
         public uint dwFlags;
        public uint time;
         public IntPtr dwExtraInfo;
        }

   [StructLayout(LayoutKind.Sequential)]
   private struct HARDWAREINPUT
      {
        public uint uMsg;
public ushort wParamL;
       public ushort wParamH;
        }

        [DllImport("user32.dll", SetLastError = true)]
     private static extern uint SendInput(uint nInputs, INPUT[] pInputs, int cbSize);

      private string selectedModelId = "base";
private readonly Dictionary<string, ModelInfo> availableModels;
        private GlobalKeyboardHook? keyboardHook;
        private RecordingIndicatorForm? recordingIndicator;
        private NotifyIcon? trayIcon;
        private AudioRecordingService? audioRecorder;
        private WhisperTranscriptionService? whisperService;
        private ModelDownloadService? modelDownloadService;
        private EventWaitHandle? _showSettingsEvent;
        private readonly Icon? appIcon;

      public SettingsForm()
        {
            InitializeComponent();

            // Load the application icon from the executable or bundled file
            appIcon = LoadApplicationIcon();
            if (appIcon != null)
            {
                this.Icon = appIcon;
            }
            else
            {
                Debug.WriteLine("Application icon could not be loaded; falling back to default.");
            }

            // Initialize model data
    availableModels = new Dictionary<string, ModelInfo>
   {
  { "tiny", new ModelInfo("tiny", "Tiny", "Fastest model, lower accuracy. Good for quick notes.", false) },
    { "base", new ModelInfo("base", "Base (Recommended)", "Best balance of speed and accuracy. Ideal for most use cases.", true) },
       { "small", new ModelInfo("small", "Small", "Better accuracy than base, slightly slower.", false) }
    };

       InitializeUI();
  InitializeTrayIcon();
     InitializeModelDownloadService();
InitializeAudioServices();
  InitializeKeyboardHook();
       InitializeSingleInstanceListener();
    
   // Check which models are actually downloaded
      RefreshModelInstallationStatus();
   }

      private void InitializeUI()
        {
   // Load the previously selected model
        LoadSelectedModel();
     
   // Wire up events
        cmbModel.SelectedIndexChanged += CmbModel_SelectedIndexChanged;
 btnDownload.Click += BtnDownload_Click;
       btnUninstall.Click += BtnUninstall_Click;
  chkLaunchOnStartup.CheckedChanged += ChkLaunchOnStartup_CheckedChanged;

    // Check and update startup checkbox state
   UpdateLaunchOnStartupCheckbox();

      // Update initial display
  UpdateModelDisplay();
      }

    private void LoadSelectedModel()
        {
    try
          {
var key = Microsoft.Win32.Registry.CurrentUser
   .OpenSubKey(@"Software\Transcryb", false);
    
             if (key != null)
        {
  var savedModel = key.GetValue("SelectedModel") as string;
     key.Close();
            
  if (!string.IsNullOrEmpty(savedModel))
      {
     // Map model ID to combo box index
     int index = savedModel switch
     {
    "tiny" => 0,
       "base" => 1,
     "small" => 2,
   _ => 1 // Default to base
 };
   
         cmbModel.SelectedIndex = index;
     selectedModelId = savedModel;
     Debug.WriteLine($"Loaded previously selected model: {savedModel}");
     return;
    }
         }
    }
      catch (Exception ex)
            {
      Debug.WriteLine($"Failed to load selected model: {ex.Message}");
            }
  
       // Default to base if no saved model or error
            cmbModel.SelectedIndex = 1; // Base (Recommended)
      selectedModelId = "base";
   }

     private void SaveSelectedModel(string modelId)
      {
    try
    {
       var key = Microsoft.Win32.Registry.CurrentUser
          .CreateSubKey(@"Software\Transcryb");
        
      if (key != null)
       {
  key.SetValue("SelectedModel", modelId);
   key.Close();
 Debug.WriteLine($"Saved selected model: {modelId}");
     }
            }
            catch (Exception ex)
            {
    Debug.WriteLine($"Failed to save selected model: {ex.Message}");
            }
  }

    private void UpdateLaunchOnStartupCheckbox()
        {
        try
      {
          const string registryKey = @"SOFTWARE\Microsoft\Windows\CurrentVersion\Run";
    const string appName = "Transcryb";
            
      using var key = Microsoft.Win32.Registry.CurrentUser.OpenSubKey(registryKey, false);
        if (key == null) return;

                var value = key.GetValue(appName);
          bool isInStartup = value != null;

    // Update checkbox without triggering the event
            chkLaunchOnStartup.CheckedChanged -= ChkLaunchOnStartup_CheckedChanged;
  chkLaunchOnStartup.Checked = isInStartup;
   chkLaunchOnStartup.CheckedChanged += ChkLaunchOnStartup_CheckedChanged;

            Debug.WriteLine($"Launch on startup status: {isInStartup}");
    }
       catch (Exception ex)
         {
     Debug.WriteLine($"Failed to check startup status: {ex.Message}");
   }
     }

        private void InitializeModelDownloadService()
      {
            try
            {
         modelDownloadService = new ModelDownloadService();
       modelDownloadService.DownloadProgressChanged += OnDownloadProgressChanged;
  modelDownloadService.DownloadCompleted += OnDownloadCompleted;
  modelDownloadService.DownloadError += OnDownloadError;
     
                Debug.WriteLine("Model download service initialized successfully");
         }
      catch (Exception ex)
      {
        ShowError($"Failed to initialize model download service: {ex.Message}");
          Debug.WriteLine($"Model download service initialization error: {ex}");
        }
  }

        private void RefreshModelInstallationStatus()
        {
            if (modelDownloadService == null) return;

            foreach (var model in availableModels)
     {
            model.Value.IsInstalled = modelDownloadService.IsModelDownloaded(model.Key);
       Debug.WriteLine($"Model {model.Key} installed: {model.Value.IsInstalled}");
            }
      
            UpdateModelDisplay();
      }

        private void InitializeAudioServices()
        {
  try
     {
 // Initialize audio recording service
         audioRecorder = new AudioRecordingService();
   audioRecorder.RecordingCompleted += OnRecordingCompleted;
       audioRecorder.RecordingError += OnRecordingError;

            // Initialize Whisper transcription service
  whisperService = new WhisperTranscriptionService();
     whisperService.SetModel(selectedModelId);
      whisperService.TranscriptionCompleted += OnTranscriptionCompleted;
        whisperService.TranscriptionError += OnTranscriptionError;
    whisperService.TranscriptionStatus += OnTranscriptionStatus;

  Debug.WriteLine("Audio services initialized successfully");
            }
            catch (Exception ex)
            {
                ShowError($"Failed to initialize audio services: {ex.Message}");
                Debug.WriteLine($"Audio services initialization error: {ex}");
            }
        }

        private void InitializeTrayIcon()
      {
 // Create system tray icon
            trayIcon = new NotifyIcon();
            trayIcon.Text = "Transcryb - Ready";
            trayIcon.Visible = true;
 
            // Prefer the application icon for the tray, fall back to the generated one
            trayIcon.Icon = appIcon ?? Icon.ExtractAssociatedIcon(Application.ExecutablePath) ?? CreateMicrophoneIcon();

 // Create context menu
   var contextMenu = new ContextMenuStrip();

            contextMenu.Items.Add("Transcryb", null, (s, e) => { }).Enabled = false;
  contextMenu.Items.Add(new ToolStripSeparator());
      contextMenu.Items.Add("Open Settings", null, (s, e) => ShowSettings());
      contextMenu.Items.Add(new ToolStripSeparator());
        contextMenu.Items.Add("Exit", null, (s, e) => ExitApplication());
 
    trayIcon.ContextMenuStrip = contextMenu;
     trayIcon.DoubleClick += (s, e) => ShowSettings();
        }

        private Icon CreateMicrophoneIcon()
        {
            // Create a simple microphone icon
            var bitmap = new Bitmap(16, 16);
            using (var g = Graphics.FromImage(bitmap))
  {
     g.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
  g.Clear(Color.Transparent);
        
      // Draw microphone shape
                using (var brush = new SolidBrush(Color.White))
            {
          // Mic body
         g.FillEllipse(brush, 6, 3, 4, 6);
        // Mic stand
 g.FillRectangle(brush, 7, 9, 2, 3);
     // Mic base
            g.FillRectangle(brush, 5, 12, 6, 2);
 }
            }
     
            return Icon.FromHandle(bitmap.GetHicon());
        }

        private Icon? LoadApplicationIcon()
        {
            try
            {
                var iconPath = Path.Combine(AppContext.BaseDirectory, "Transcryb.ico");
                if (File.Exists(iconPath))
                {
                    using var stream = File.OpenRead(iconPath);
                    return new Icon(stream);
                }

                return Icon.ExtractAssociatedIcon(Application.ExecutablePath);
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"Failed to load application icon: {ex.Message}");
                return null;
            }
        }

private void ShowSettings()
        {
        this.Show();
          this.WindowState = FormWindowState.Normal;
            this.BringToFront();
      }

        private void ExitApplication()
        {
            // Clean up and exit
          audioRecorder?.Dispose();
      whisperService = null;
            trayIcon?.Dispose();
            keyboardHook?.Stop();
  keyboardHook?.Dispose();
      recordingIndicator?.Close();
            _showSettingsEvent?.Dispose();
            Application.Exit();
        }

      protected override void OnFormClosing(FormClosingEventArgs e)
        {
            // Minimize to tray instead of closing when user clicks X
 if (e.CloseReason == CloseReason.UserClosing)
  {
      e.Cancel = true;
     this.Hide();
  
    // Show balloon tip on first minimize
if (trayIcon != null && !HasShownTrayTip())
    {
   trayIcon.ShowBalloonTip(3000, "Transcryb", 
   "Transcryb is still running in the system tray. Press Ctrl+Win to record.", 
    ToolTipIcon.Info);
         MarkTrayTipShown();
    }
   }
        else
{
     // Actually closing (from Exit menu)
      audioRecorder?.Dispose();
      keyboardHook?.Stop();
   keyboardHook?.Dispose();
   recordingIndicator?.Close();
        _showSettingsEvent?.Dispose();
 base.OnFormClosing(e);
  }
    }

   private bool HasShownTrayTip()
        {
 return Microsoft.Win32.Registry.CurrentUser
      .OpenSubKey(@"Software\Transcryb", false)
  ?.GetValue("TrayTipShown") != null;
        }

   private void MarkTrayTipShown()
        {
            var key = Microsoft.Win32.Registry.CurrentUser
  .CreateSubKey(@"Software\Transcryb");
            key?.SetValue("TrayTipShown", "1");
            key?.Close();
        }

        private void InitializeKeyboardHook()
        {
  try
   {
    // Create recording indicator form
   recordingIndicator = new RecordingIndicatorForm();
  
              // Initialize global keyboard hook
         keyboardHook = new GlobalKeyboardHook();
    keyboardHook.HotkeyPressed += OnHotkeyPressed;
     keyboardHook.HotkeyReleased += OnHotkeyReleased;
          keyboardHook.Start();
        }
     catch (Exception ex)
      {
           ShowError($"Failed to initialize keyboard hook: {ex.Message}");
   }
        }

        private void OnHotkeyPressed(object? sender, EventArgs e)
 {
      // Check if the selected model is installed
            if (!IsSelectedModelInstalled())
  {
           // Show error message box
      this.Invoke(() =>
    {
    MessageBox.Show(
  $"The selected model '{selectedModelId}' is not installed.\n\n" +
      "Please download the model from the settings window before recording.",
     "Model Not Installed",
       MessageBoxButtons.OK,
    MessageBoxIcon.Warning);
         });
   
             Debug.WriteLine($"Recording blocked - model '{selectedModelId}' not installed");
       return;
            }

    // Update tray icon tooltip
  if (trayIcon != null)
            {
    trayIcon.Text = "Transcryb - Recording...";
         }
      
      // Show recording indicator at bottom center
            recordingIndicator?.ShowIndicator();

       // Start audio recording
    audioRecorder?.StartRecording();
         Debug.WriteLine("Hotkey pressed - Recording started");
        }

   private bool IsSelectedModelInstalled()
        {
            return availableModels.TryGetValue(selectedModelId, out var model) && model.IsInstalled;
        }

        private void OnHotkeyReleased(object? sender, EventArgs e)
        {
       // Update tray icon tooltip
       if (trayIcon != null)
      {
    trayIcon.Text = "Transcryb - Processing...";
  }
 
       // Stop audio recording
audioRecorder?.StopRecording();
            Debug.WriteLine("Hotkey released - Recording stopped");
     }

        private void OnRecordingCompleted(object? sender, string audioFilePath)
        {
    Debug.WriteLine($"Recording completed: {audioFilePath}");
   
     // Change indicator to processing state
         recordingIndicator?.StartProcessing();

     // Start transcription
     _ = whisperService?.TranscribeAsync(audioFilePath);
        }

        private void OnRecordingError(object? sender, string error)
     {
        Debug.WriteLine($"Recording error: {error}");
  recordingIndicator?.HideIndicator();
  
     if (trayIcon != null)
      {
    trayIcon.Text = "Transcryb - Ready";
        }
     
       this.Invoke(() => ShowError(error));
        }

        private void OnTranscriptionCompleted(object? sender, string transcription)
        {
            Debug.WriteLine($"========================================");
            Debug.WriteLine($"TRANSCRIPTION RESULT:");
            Debug.WriteLine($"{transcription}");
            Debug.WriteLine($"========================================");

            // Update UI on the UI thread
            this.Invoke(() =>
            {
                // Hide the processing indicator
                recordingIndicator?.HideIndicator();

                // Update tray status
                if (trayIcon != null)
                {
                    trayIcon.Text = "Transcryb - Ready";
                }

                // Do not insert text if transcription is blank audio
                if (string.Equals(transcription.Trim(), "[BLANK_AUDIO]", StringComparison.OrdinalIgnoreCase))
                {
                    Debug.WriteLine("Blank audio detected, not inserting text.");
                    return;
                }

                // Insert transcription at cursor position
                InsertTextAtCursor(transcription);
            });
        }

        private void OnTranscriptionError(object? sender, string error)
        {
            Debug.WriteLine($"Transcription error: {error}");
  
       // Update UI on the UI thread
         this.Invoke(() =>
            {
          recordingIndicator?.HideIndicator();
    
    if (trayIcon != null)
     {
            trayIcon.Text = "Transcryb - Ready";
     }
    
      ShowError(error);
     });
        }

        private void OnTranscriptionStatus(object? sender, string status)
        {
      Debug.WriteLine($"Transcription status: {status}");
     }

        /// <summary>
        /// Insert text at the current cursor position using SendInput API with Unicode support
     /// </summary>
      private void InsertTextAtCursor(string text)
        {
 if (string.IsNullOrWhiteSpace(text))
       {
     Debug.WriteLine("No text to insert");
      return;
   }

       try
     {
     Debug.WriteLine($"Inserting text at cursor: {text}");
   
  SendUnicodeText(text);
   Debug.WriteLine("Text inserted successfully using SendInput");
   }
            catch (Exception ex)
        {
    Debug.WriteLine($"Error inserting text at cursor: {ex.Message}");
   ShowError($"Failed to insert transcription: {ex.Message}");
  }
   }

        /// <summary>
        /// Send Unicode text using SendInput API for proper Unicode and emoji support
      /// </summary>
     private void SendUnicodeText(string text)
    {
  try
       {
        var inputs = new List<INPUT>();

     foreach (char c in text)
{
        // Handle surrogate pairs for emoji and special characters
         if (char.IsHighSurrogate(c))
   {
          // This is the first part of a surrogate pair, skip for now
  // We'll handle it when we encounter the low surrogate
          continue;
       }

          ushort scanCode;
         if (char.IsLowSurrogate(c))
  {
       // This is part of a surrogate pair - we need to reconstruct the full character
         // For now, just use the character code
         scanCode = c;
        }
      else
     {
    scanCode = c;
       }

       // Key down
       inputs.Add(new INPUT
        {
             type = INPUT_KEYBOARD,
 u = new INPUTUNION
        {
    ki = new KEYBDINPUT
{
         wVk = 0,
                  wScan = scanCode,
            dwFlags = KEYEVENTF_UNICODE,
          time = 0,
      dwExtraInfo = IntPtr.Zero
        }
      }
       });

     // Key up
     inputs.Add(new INPUT
       {
        type = INPUT_KEYBOARD,
          u = new INPUTUNION
    {
        ki = new KEYBDINPUT
      {
        wVk = 0,
       wScan = scanCode,
         dwFlags = KEYEVENTF_UNICODE | KEYEVENTF_KEYUP,
   time = 0,
  dwExtraInfo = IntPtr.Zero
   }
       }
  });
       }

  if (inputs.Count > 0)
      {
    Debug.WriteLine($"Sending {inputs.Count / 2} characters via SendInput");
     
       // Send all inputs at once for better reliability
       uint result = SendInput((uint)inputs.Count, inputs.ToArray(), Marshal.SizeOf(typeof(INPUT)));
            
        if (result == 0)
   {
     int errorCode = Marshal.GetLastWin32Error();
      Debug.WriteLine($"SendInput failed with error code: {errorCode}");
      throw new System.ComponentModel.Win32Exception(errorCode);
      }
         else if (result != inputs.Count)
   {
           Debug.WriteLine($"SendInput warning: Expected {inputs.Count} inputs, but only {result} were sent");
  }
 else
            {
     Debug.WriteLine($"SendInput successfully sent {result} inputs ({result / 2} characters)");
      }
  }
   else
            {
       Debug.WriteLine("No inputs to send (text was empty or contained only surrogate pairs)");
      }
          }
  catch (Exception ex)
      {
        Debug.WriteLine($"Error in SendUnicodeText: {ex.GetType().Name} - {ex.Message}");
          Debug.WriteLine($"Stack trace: {ex.StackTrace}");
throw; // Re-throw to be caught by InsertTextAtCursor
   }
    }

        private void CmbModel_SelectedIndexChanged(object? sender, EventArgs e)
    {
      UpdateModelDisplay();
    
   // Update the Whisper service model
   var selectedIndex = cmbModel.SelectedIndex;
   string modelId = selectedIndex switch
  {
0 => "tiny",
         1 => "base",
     2 => "small",
   _ => "base"
     };
            
  selectedModelId = modelId;
 whisperService?.SetModel(modelId);
 
     // Save the selected model to registry
   SaveSelectedModel(modelId);
}

     private void UpdateModelDisplay()
     {
      var selectedIndex = cmbModel.SelectedIndex;
  ModelInfo? selectedModel = null;

    switch (selectedIndex)
    {
    case 0: selectedModel = availableModels["tiny"]; break;
      case 1: selectedModel = availableModels["base"]; break;
   case 2: selectedModel = availableModels["small"]; break;
   }

  if (selectedModel != null)
   {
    lblModelDescription.Text = selectedModel.Description;
   
    if (selectedModel.IsInstalled)
     {
      lblModelStatus.Text = "Installed";
    lblModelStatus.ForeColor = Color.FromArgb(40, 167, 69);
btnDownload.Visible = false;
     btnUninstall.Visible = true;
    }
     else
  {
// Show model size in the status
           var modelSize = modelDownloadService?.GetModelSizeFormatted(selectedModel.Id) ?? "";
     lblModelStatus.Text = $"Not installed ({modelSize})";
    lblModelStatus.ForeColor = Color.FromArgb(255, 152, 0);
 btnDownload.Visible = true;
        btnUninstall.Visible = false;
      }

progressDownload.Visible = false;
   lblDownloadProgress.Visible = false;
  }
 }

  private async void BtnDownload_Click(object? sender, EventArgs e)
   {
    if (modelDownloadService == null)
 {
  ShowError("Model download service not initialized");
     return;
       }

       var selectedIndex = cmbModel.SelectedIndex;
   string modelId = selectedIndex switch
   {
    0 => "tiny",
 1 => "base",
 2 => "small",
   _ => "base"
 };

  btnDownload.Enabled = false;
   cmbModel.Enabled = false;
        progressDownload.Visible = true;
     lblDownloadProgress.Visible = true;
  progressDownload.Value = 0;
  lblDownloadProgress.Text = "Starting download...";

  try
  {
   await modelDownloadService.DownloadModelAsync(modelId);
     }
 catch (Exception ex)
     {
 ShowError($"Download failed: {ex.Message}");
    btnDownload.Enabled = true;
         cmbModel.Enabled = true;
   progressDownload.Visible = false;
     lblDownloadProgress.Visible = false;
  }
     }

   private void OnDownloadProgressChanged(object? sender, int progress)
      {
   this.Invoke(() =>
       {
  progressDownload.Value = Math.Min(progress, 100);
      lblDownloadProgress.Text = $"{progress}%";
  });
}

   private void OnDownloadCompleted(object? sender, string modelName)
 {
  this.Invoke(() =>
     {
      // Mark as installed
 if (availableModels.TryGetValue(modelName, out var model))
      {
   model.IsInstalled = true;
   }

      btnDownload.Enabled = true;
    cmbModel.Enabled = true;
     UpdateModelDisplay();

    MessageBox.Show(
      $"Model '{modelName}' downloaded successfully!",
      "Download Complete",
 MessageBoxButtons.OK,
    MessageBoxIcon.Information);
        });
   }

        private void OnDownloadError(object? sender, string error)
   {
      this.Invoke(() =>
   {
       ShowError(error);
      btnDownload.Enabled = true;
    cmbModel.Enabled = true;
        progressDownload.Visible = false;
         lblDownloadProgress.Visible = false;
 });
     }

        private void BtnUninstall_Click(object? sender, EventArgs e)
        {
       if (modelDownloadService == null) return;

         var result = MessageBox.Show(
     "Are you sure you want to uninstall this model?",
    "Confirm Uninstall",
    MessageBoxButtons.YesNo,
    MessageBoxIcon.Question);

   if (result == DialogResult.Yes)
{
          var selectedIndex = cmbModel.SelectedIndex;
 string modelId = selectedIndex switch
          {
   0 => "tiny",
 1 => "base",
          2 => "small",
        _ => "base"
        };

       if (modelDownloadService.DeleteModel(modelId))
  {
     if (availableModels.TryGetValue(modelId, out var model))
    {
         model.IsInstalled = false;
}
               UpdateModelDisplay();
      }
  else
  {
    ShowError("Failed to uninstall model");
      }
    }
      }

        private void ChkLaunchOnStartup_CheckedChanged(object? sender, EventArgs e)
  {
    try
       {
    const string registryKey = @"SOFTWARE\Microsoft\Windows\CurrentVersion\Run";
         const string appName = "Transcryb";

          using var key = Microsoft.Win32.Registry.CurrentUser.OpenSubKey(registryKey, true);
        if (key == null)
             {
      ShowError("Unable to access Windows startup registry");
        return;
        }

     if (chkLaunchOnStartup.Checked)
        {
     // Add to startup - use the executable path
string exePath = $"\"{Application.ExecutablePath}\"";
    key.SetValue(appName, exePath);
          Debug.WriteLine($"Launch on startup enabled: {exePath}");
 }
    else
      {
       // Remove from startup
     if (key.GetValue(appName) != null)
 {
      key.DeleteValue(appName);
  }
      Debug.WriteLine("Launch on startup disabled");
           }
      }
            catch (Exception ex)
        {
      ShowError($"Failed to update startup settings: {ex.Message}");
   Debug.WriteLine($"Startup settings error: {ex}");
    
 // Revert checkbox state on error
    chkLaunchOnStartup.CheckedChanged -= ChkLaunchOnStartup_CheckedChanged;
    chkLaunchOnStartup.Checked = !chkLaunchOnStartup.Checked;
    chkLaunchOnStartup.CheckedChanged += ChkLaunchOnStartup_CheckedChanged;
            }
        }

        public void ShowError(string errorMessage)
 {
       lblErrorMessage.Text = errorMessage;
          panelError.Visible = true;
        }

        public void HideError()
  {
    panelError.Visible = false;
  }

        private void InitializeSingleInstanceListener()
        {
    try
    {
// Create a named event for inter-process communication
 _showSettingsEvent = new EventWaitHandle(false, EventResetMode.AutoReset, "TranscrybShowSettings");
      
           // Start a background thread to listen for show settings signals
 var listenerThread = new Thread(() =>
    {
       while (true)
{
               try
      {
              // Wait for signal from another instance
          _showSettingsEvent.WaitOne();
  
  // Show settings on the UI thread
     this.Invoke(() => ShowSettings());
      }
      catch (ThreadInterruptedException)
        {
            // Thread is being stopped
      break;
  }
      catch (ObjectDisposedException)
          {
      // Event handle was disposed
       break;
      }
       catch (Exception ex)
        {
    Debug.WriteLine($"Error in single instance listener: {ex.Message}");
     }
 }
  })
      {
    IsBackground = true
};
 
      listenerThread.Start();

Debug.WriteLine("Single instance listener initialized");
        }
 catch (Exception ex)
            {
          Debug.WriteLine($"Failed to initialize single instance listener: {ex.Message}");
}
        }

        // Helper class for model information
private class ModelInfo
   {
      public string Id { get; set; }
  public string DisplayName { get; set; }
    public string Description { get; set; }
public bool IsInstalled { get; set; }

   public ModelInfo(string id, string displayName, string description, bool isInstalled)
   {
      Id = id;
    DisplayName = displayName;
 Description = description;
          IsInstalled = isInstalled;
     }
      }
    }
}
