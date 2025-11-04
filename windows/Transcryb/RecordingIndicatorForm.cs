namespace Transcryb
{
    public partial class RecordingIndicatorForm : Form
    {
    private bool isRecording = false;
private bool isProcessing = false;
  private System.Windows.Forms.Timer animationTimer;
   private int animationFrame = 0;

        public RecordingIndicatorForm()
        {
      InitializeComponent();
   
 // Make form transparent and topmost
  this.FormBorderStyle = FormBorderStyle.None;
        this.BackColor = Color.Black;
          this.TransparencyKey = Color.Black;
      this.TopMost = true;
this.ShowInTaskbar = false;
   
     // Initialize animation timer
     animationTimer = new System.Windows.Forms.Timer();
          animationTimer.Interval = 100;
       animationTimer.Tick += AnimationTimer_Tick;
        
   // Position at bottom center of screen
            PositionAtBottomCenter();
        }

        private void PositionAtBottomCenter()
        {
  var screen = Screen.PrimaryScreen;
 if (screen != null)
    {
      int x = (screen.WorkingArea.Width - this.Width) / 2;
  int y = screen.WorkingArea.Height - this.Height - 20; // 20px from bottom
this.Location = new Point(x, y);
            }
        }

        private void AnimationTimer_Tick(object? sender, EventArgs e)
        {
      animationFrame = (animationFrame + 1) % 10;
       this.Invalidate();
  }

  protected override void OnPaint(PaintEventArgs e)
     {
      base.OnPaint(e);
 
       if (!isRecording && !isProcessing)
 return;

      var g = e.Graphics;
       g.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;

    // Draw circle background
    using (var brush = new System.Drawing.Drawing2D.LinearGradientBrush(
    this.ClientRectangle,
Color.FromArgb(235, 30, 30, 30),
  Color.FromArgb(190, 30, 30, 30),
 System.Drawing.Drawing2D.LinearGradientMode.Vertical))
   {
 g.FillEllipse(brush, 2, 2, 60, 60);
      }

      // Draw border
Color borderColor = isRecording ? Color.Red : Color.FromArgb(0, 122, 255);
    using (var pen = new Pen(borderColor, 3))
     {
g.DrawEllipse(pen, 2, 2, 60, 60);
          }

         // Draw icon or progress
     if (isRecording)
     {
      // Draw microphone icon (simplified)
   using (var brush = new SolidBrush(Color.White))
         {
             g.FillEllipse(brush, 27, 20, 10, 15);
         g.FillRectangle(brush, 30, 35, 4, 8);
 g.FillRectangle(brush, 25, 43, 14, 3);
     }
   }
        else if (isProcessing)
    {
  // Draw processing spinner
   using (var pen = new Pen(Color.White, 2))
   {
     for (int i = 0; i < 8; i++)
   {
    int opacity = i == animationFrame % 8 ? 255 : 100;
 pen.Color = Color.FromArgb(opacity, Color.White);
        
        double angle = i * Math.PI / 4;
      int x1 = 32 + (int)(12 * Math.Cos(angle));
int y1 = 32 + (int)(12 * Math.Sin(angle));
      int x2 = 32 + (int)(18 * Math.Cos(angle));
         int y2 = 32 + (int)(18 * Math.Sin(angle));
 
      g.DrawLine(pen, x1, y1, x2, y2);
   }
    }
  }
        }

        public void StartRecording()
 {
  isRecording = true;
isProcessing = false;
    animationTimer.Stop();
    PositionAtBottomCenter(); // Ensure correct position
   this.Show();
  this.Invalidate();
      }

   public void StopRecording()
        {
  isRecording = false;
     this.Invalidate();
        }

   public void StartProcessing()
   {
       isRecording = false;
       isProcessing = true;
     animationTimer.Start();
            PositionAtBottomCenter(); // Ensure correct position
this.Show();
     this.Invalidate();
        }

    public void StopProcessing()
   {
       isProcessing = false;
  animationTimer.Stop();
     this.Hide();
  }

        public void ShowIndicator()
        {
            isRecording = true;
    isProcessing = false;
  animationTimer.Stop();
            PositionAtBottomCenter();
  this.Show();
        this.Invalidate();
     }

    public void HideIndicator()
  {
            isRecording = false;
        isProcessing = false;
    animationTimer.Stop();
 this.Hide();
        }

      protected override void OnFormClosing(FormClosingEventArgs e)
    {
  if (e.CloseReason == CloseReason.UserClosing)
      {
     e.Cancel = true;
    this.Hide();
     }
            base.OnFormClosing(e);
   }
    }
}
