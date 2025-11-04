namespace Transcryb
{
    internal static class Program
    {
        private static Mutex? _mutex;
        private const string MutexName = "TranscrybAppMutex";

        /// <summary>
        ///  The main entry point for the application.
        /// </summary>
        [STAThread]
        static async Task Main()
        {
            // Add global exception handlers
            Application.ThreadException += Application_ThreadException;
            AppDomain.CurrentDomain.UnhandledException += CurrentDomain_UnhandledException;
            Application.SetUnhandledExceptionMode(UnhandledExceptionMode.CatchException);

            // To customize application configuration such as set high DPI settings or default font,
            // see https://aka.ms/applicationconfiguration.
            ApplicationConfiguration.Initialize();

            // Check for single instance
            bool createdNew;
            _mutex = new Mutex(true, MutexName, out createdNew);

            if (!createdNew)
            {
                // Another instance is already running - signal it to show settings
                SignalExistingInstance();
                return;
            }

            // Launch settings panel directly
            var mainForm = new SettingsForm();
            mainForm.Show();
            mainForm.WindowState = FormWindowState.Normal;
         
            // Run application
            Application.Run(mainForm);

            // Clean up mutex
            _mutex?.ReleaseMutex();
        }

        private static void SignalExistingInstance()
        {
            // Create a named event to signal the existing instance
            try
            {
                using var eventWaitHandle = EventWaitHandle.OpenExisting("TranscrybShowSettings");
                eventWaitHandle.Set();
            }
            catch
            {
                // If event doesn't exist, the other instance might not be fully initialized yet
            }
        }

        private static void Application_ThreadException(object sender, System.Threading.ThreadExceptionEventArgs e)
        {
            System.Diagnostics.Debug.WriteLine($"=== UNHANDLED THREAD EXCEPTION ===");
            System.Diagnostics.Debug.WriteLine($"Exception: {e.Exception.GetType().Name}");
            System.Diagnostics.Debug.WriteLine($"Message: {e.Exception.Message}");
            System.Diagnostics.Debug.WriteLine($"Stack Trace: {e.Exception.StackTrace}");
            System.Diagnostics.Debug.WriteLine($"==================================");

            // Show a user-friendly error message
            MessageBox.Show(
    $"An unexpected error occurred:\n\n{e.Exception.Message}\n\nThe application will continue running.",
      "Error",
    MessageBoxButtons.OK,
MessageBoxIcon.Error);
        }

        private static void CurrentDomain_UnhandledException(object sender, UnhandledExceptionEventArgs e)
        {
            if (e.ExceptionObject is Exception ex)
       {
    System.Diagnostics.Debug.WriteLine($"=== UNHANDLED DOMAIN EXCEPTION ===");
      System.Diagnostics.Debug.WriteLine($"Exception: {ex.GetType().Name}");
       System.Diagnostics.Debug.WriteLine($"Message: {ex.Message}");
    System.Diagnostics.Debug.WriteLine($"Stack Trace: {ex.StackTrace}");
      System.Diagnostics.Debug.WriteLine($"Is Terminating: {e.IsTerminating}");
       System.Diagnostics.Debug.WriteLine($"===================================");
      }
        }
    }
}