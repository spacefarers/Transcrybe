namespace Transcryb
{
    partial class RecordingIndicatorForm
{
        private System.ComponentModel.IContainer components = null;

     protected override void Dispose(bool disposing)
        {
            if (disposing && (components != null))
            {
        components.Dispose();
            }
            base.Dispose(disposing);
   }

        #region Windows Form Designer generated code

        private void InitializeComponent()
    {
            SuspendLayout();
            // 
       // RecordingIndicatorForm
       // 
     AutoScaleDimensions = new SizeF(8F, 20F);
            AutoScaleMode = AutoScaleMode.Font;
BackColor = Color.Black;
      ClientSize = new Size(64, 64);
   FormBorderStyle = FormBorderStyle.None;
  Name = "RecordingIndicatorForm";
            ShowInTaskbar = false;
       StartPosition = FormStartPosition.Manual;
          Text = "Recording";
            TopMost = true;
            TransparencyKey = Color.Black;
ResumeLayout(false);
        }

        #endregion
    }
}
