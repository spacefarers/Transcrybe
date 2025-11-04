using System.Diagnostics;
using System.Runtime.InteropServices;

namespace Transcryb
{
    /// <summary>
    /// Global keyboard hook for detecting hotkey combinations
    /// </summary>
    public class GlobalKeyboardHook : IDisposable
    {
        private const int WH_KEYBOARD_LL = 13;
        private const int WM_KEYDOWN = 0x0100;
        private const int WM_KEYUP = 0x0101;
        private const int WM_SYSKEYDOWN = 0x0104;
private const int WM_SYSKEYUP = 0x0105;

        private LowLevelKeyboardProc _proc;
        private IntPtr _hookID = IntPtr.Zero;
        
    private bool _isControlPressed = false;
        private bool _isWinKeyPressed = false;
        private bool _isHotkeyActive = false;

        public event EventHandler? HotkeyPressed;
        public event EventHandler? HotkeyReleased;

        public GlobalKeyboardHook()
        {
         _proc = HookCallback;
        }

        public void Start()
        {
        _hookID = SetHook(_proc);
        }

 public void Stop()
        {
      if (_hookID != IntPtr.Zero)
         {
       UnhookWindowsHookEx(_hookID);
        _hookID = IntPtr.Zero;
     }
 }

        private IntPtr SetHook(LowLevelKeyboardProc proc)
        {
            using (Process curProcess = Process.GetCurrentProcess())
      using (ProcessModule? curModule = curProcess.MainModule)
    {
                if (curModule != null)
  {
        return SetWindowsHookEx(WH_KEYBOARD_LL, proc,
     GetModuleHandle(curModule.ModuleName), 0);
  }
      }
  return IntPtr.Zero;
        }

        private delegate IntPtr LowLevelKeyboardProc(int nCode, IntPtr wParam, IntPtr lParam);

        private IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam)
        {
            if (nCode >= 0)
{
            int vkCode = Marshal.ReadInt32(lParam);
          Keys key = (Keys)vkCode;

    bool isKeyDown = wParam == (IntPtr)WM_KEYDOWN || wParam == (IntPtr)WM_SYSKEYDOWN;
       bool isKeyUp = wParam == (IntPtr)WM_KEYUP || wParam == (IntPtr)WM_SYSKEYUP;

  // Track Control key state
     if (key == Keys.LControlKey || key == Keys.RControlKey || key == Keys.ControlKey)
  {
       if (isKeyDown)
     _isControlPressed = true;
    else if (isKeyUp)
      _isControlPressed = false;
                }

             // Track Windows key state
     if (key == Keys.LWin || key == Keys.RWin)
       {
               if (isKeyDown)
         _isWinKeyPressed = true;
            else if (isKeyUp)
                _isWinKeyPressed = false;
          }

        // Check if both keys are pressed
    bool shouldBeActive = _isControlPressed && _isWinKeyPressed;

          // Fire events on state changes
      if (shouldBeActive && !_isHotkeyActive)
       {
 _isHotkeyActive = true;
             HotkeyPressed?.Invoke(this, EventArgs.Empty);
  }
  else if (!shouldBeActive && _isHotkeyActive)
    {
         _isHotkeyActive = false;
      HotkeyReleased?.Invoke(this, EventArgs.Empty);
 }
    }

      return CallNextHookEx(_hookID, nCode, wParam, lParam);
      }

        public void Dispose()
        {
            Stop();
     }

        #region Win32 API

        [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
   private static extern IntPtr SetWindowsHookEx(int idHook, LowLevelKeyboardProc lpfn, IntPtr hMod, uint dwThreadId);

        [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool UnhookWindowsHookEx(IntPtr hhk);

        [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);

        [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        private static extern IntPtr GetModuleHandle(string lpModuleName);

        #endregion
    }
}
