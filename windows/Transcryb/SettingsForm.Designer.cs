namespace Transcryb
{
    partial class SettingsForm
    {
      /// <summary>
        ///  Required designer variable.
        /// </summary>
        private System.ComponentModel.IContainer components = null;

        /// <summary>
        ///  Clean up any resources being used.
        /// </summary>
        /// <param name="disposing">true if managed resources should be disposed; otherwise, false.</param>
 protected override void Dispose(bool disposing)
   {
          if (disposing && (components != null))
            {
     components.Dispose();
            }
   base.Dispose(disposing);
      }

   #region Windows Form Designer generated code

        /// <summary>
        ///  Required method for Designer support - do not modify
        ///  the contents of this method with the code editor.
     /// </summary>
     private void InitializeComponent()
        {
     panelHeader = new Panel();
      lblSubtitle = new Label();
  lblTitle = new Label();
     panelMain = new Panel();
            panelModelSection = new Panel();
            panelModelDownload = new Panel();
   btnUninstall = new Button();
            btnDownload = new Button();
            progressDownload = new ProgressBar();
   lblDownloadProgress = new Label();
     lblModelStatus = new Label();
lblModelDescription = new Label();
            cmbModel = new ComboBox();
            lblModelTitle = new Label();
    panelSystemSection = new Panel();
  lblSystemDescription = new Label();
       chkLaunchOnStartup = new CheckBox();
       lblSystemTitle = new Label();
panelError = new Panel();
            lblErrorMessage = new Label();
          lblErrorTitle = new Label();
    panelHeader.SuspendLayout();
    panelMain.SuspendLayout();
 panelModelSection.SuspendLayout();
            panelModelDownload.SuspendLayout();
            panelSystemSection.SuspendLayout();
   panelError.SuspendLayout();
    SuspendLayout();
   // 
            // panelHeader
            // 
          panelHeader.BackColor = Color.FromArgb(240, 240, 240);
            panelHeader.BorderStyle = BorderStyle.FixedSingle;
  panelHeader.Controls.Add(lblSubtitle);
    panelHeader.Controls.Add(lblTitle);
       panelHeader.Dock = DockStyle.Top;
            panelHeader.Location = new Point(0, 0);
         panelHeader.Name = "panelHeader";
            panelHeader.Padding = new Padding(16);
            panelHeader.Size = new Size(800, 90);
  panelHeader.TabIndex = 0;
            // 
  // lblSubtitle
            // 
            lblSubtitle.AutoSize = true;
     lblSubtitle.Font = new Font("Segoe UI", 9F, FontStyle.Regular, GraphicsUnit.Point);
     lblSubtitle.ForeColor = Color.FromArgb(108, 117, 125);
 lblSubtitle.Location = new Point(16, 53);
    lblSubtitle.Name = "lblSubtitle";
    lblSubtitle.Size = new Size(427, 20);
            lblSubtitle.TabIndex = 1;
   lblSubtitle.Text = "Whisper transcription at your fingertip. Hold ctrl+win and start talking!";
    // 
    // lblTitle
          // 
       lblTitle.AutoSize = true;
        lblTitle.Font = new Font("Segoe UI", 16F, FontStyle.Bold, GraphicsUnit.Point);
       lblTitle.Location = new Point(16, 16);
            lblTitle.Name = "lblTitle";
  lblTitle.Size = new Size(155, 37);
  lblTitle.TabIndex = 0;
  lblTitle.Text = "Transcryb";
            // 
 // panelMain
            // 
   panelMain.AutoScroll = true;
    panelMain.BackColor = Color.White;
            panelMain.Controls.Add(panelModelSection);
            panelMain.Controls.Add(panelSystemSection);
 panelMain.Controls.Add(panelError);
            panelMain.Dock = DockStyle.Fill;
            panelMain.Location = new Point(0, 90);
            panelMain.Name = "panelMain";
 panelMain.Padding = new Padding(16);
            panelMain.Size = new Size(800, 560);
            panelMain.TabIndex = 1;
  // 
            // panelModelSection
         // 
    panelModelSection.BackColor = Color.FromArgb(245, 245, 245);
    panelModelSection.Controls.Add(panelModelDownload);
       panelModelSection.Controls.Add(lblModelDescription);
            panelModelSection.Controls.Add(cmbModel);
            panelModelSection.Controls.Add(lblModelTitle);
 panelModelSection.Location = new Point(16, 16);
  panelModelSection.Name = "panelModelSection";
     panelModelSection.Padding = new Padding(12);
panelModelSection.Size = new Size(750, 280);
   panelModelSection.TabIndex = 0;
        // 
            // panelModelDownload
            // 
    panelModelDownload.Controls.Add(btnUninstall);
  panelModelDownload.Controls.Add(btnDownload);
      panelModelDownload.Controls.Add(progressDownload);
        panelModelDownload.Controls.Add(lblDownloadProgress);
 panelModelDownload.Controls.Add(lblModelStatus);
  panelModelDownload.Location = new Point(12, 130);
     panelModelDownload.Name = "panelModelDownload";
     panelModelDownload.Size = new Size(720, 130);
    panelModelDownload.TabIndex = 3;
 // 
            // btnUninstall
            // 
     btnUninstall.BackColor = Color.FromArgb(220, 53, 69);
      btnUninstall.FlatStyle = FlatStyle.Flat;
        btnUninstall.Font = new Font("Segoe UI", 9F, FontStyle.Regular, GraphicsUnit.Point);
   btnUninstall.ForeColor = Color.White;
   btnUninstall.Location = new Point(150, 5);
            btnUninstall.Name = "btnUninstall";
       btnUninstall.Size = new Size(90, 30);
    btnUninstall.TabIndex = 4;
      btnUninstall.Text = "Delete";
         btnUninstall.UseVisualStyleBackColor = false;
       btnUninstall.Visible = false;
      // 
    // btnDownload
            // 
  btnDownload.Anchor = AnchorStyles.Top | AnchorStyles.Right;
            btnDownload.BackColor = Color.FromArgb(0, 122, 255);
   btnDownload.FlatStyle = FlatStyle.Flat;
        btnDownload.Font = new Font("Segoe UI", 9F, FontStyle.Bold, GraphicsUnit.Point);
            btnDownload.ForeColor = Color.White;
         btnDownload.Location = new Point(610, 5);
       btnDownload.Name = "btnDownload";
            btnDownload.Size = new Size(110, 32);
            btnDownload.TabIndex = 3;
            btnDownload.Text = "Download";
  btnDownload.UseVisualStyleBackColor = false;
          // 
      // progressDownload
  // 
 progressDownload.Location = new Point(5, 50);
     progressDownload.Name = "progressDownload";
    progressDownload.Size = new Size(710, 25);
  progressDownload.TabIndex = 2;
         progressDownload.Visible = false;
   // 
        // lblDownloadProgress
            // 
            lblDownloadProgress.AutoSize = true;
            lblDownloadProgress.Font = new Font("Segoe UI", 9F, FontStyle.Bold, GraphicsUnit.Point);
            lblDownloadProgress.ForeColor = Color.FromArgb(108, 117, 125);
            lblDownloadProgress.Location = new Point(5, 80);
            lblDownloadProgress.Name = "lblDownloadProgress";
 lblDownloadProgress.Size = new Size(150, 20);
      lblDownloadProgress.TabIndex = 1;
            lblDownloadProgress.Text = "Starting download...";
            lblDownloadProgress.Visible = false;
    // 
 // lblModelStatus
   // 
    lblModelStatus.AutoSize = true;
            lblModelStatus.Font = new Font("Segoe UI", 9F, FontStyle.Bold, GraphicsUnit.Point);
            lblModelStatus.ForeColor = Color.FromArgb(40, 167, 69);
        lblModelStatus.Location = new Point(5, 10);
     lblModelStatus.Name = "lblModelStatus";
        lblModelStatus.Size = new Size(127, 20);
            lblModelStatus.TabIndex = 0;
       lblModelStatus.Text = "Installed";
        // 
        // lblModelDescription
// 
            lblModelDescription.Font = new Font("Segoe UI", 9F, FontStyle.Regular, GraphicsUnit.Point);
        lblModelDescription.ForeColor = Color.FromArgb(108, 117, 125);
            lblModelDescription.Location = new Point(12, 90);
  lblModelDescription.Name = "lblModelDescription";
     lblModelDescription.Size = new Size(720, 30);
    lblModelDescription.TabIndex = 2;
            lblModelDescription.Text = "Best balance of speed and accuracy. Ideal for most use cases.";
         // 
   // cmbModel
   // 
      cmbModel.DropDownStyle = ComboBoxStyle.DropDownList;
  cmbModel.Font = new Font("Segoe UI", 10F, FontStyle.Regular, GraphicsUnit.Point);
    cmbModel.FormattingEnabled = true;
   cmbModel.Items.AddRange(new object[] { "Tiny", "Base (Recommended)", "Small" });
          cmbModel.Location = new Point(12, 45);
       cmbModel.Name = "cmbModel";
    cmbModel.Size = new Size(720, 31);
     cmbModel.TabIndex = 1;
     // 
    // lblModelTitle
       // 
            lblModelTitle.AutoSize = true;
            lblModelTitle.Font = new Font("Segoe UI", 11F, FontStyle.Bold, GraphicsUnit.Point);
     lblModelTitle.Location = new Point(12, 12);
     lblModelTitle.Name = "lblModelTitle";
            lblModelTitle.Size = new Size(193, 25);
            lblModelTitle.TabIndex = 0;
  lblModelTitle.Text = "Whisper Model";
       // 
 // panelSystemSection
            // 
            panelSystemSection.BackColor = Color.FromArgb(245, 245, 245);
          panelSystemSection.Controls.Add(lblSystemDescription);
   panelSystemSection.Controls.Add(chkLaunchOnStartup);
 panelSystemSection.Controls.Add(lblSystemTitle);
         panelSystemSection.Location = new Point(16, 312);
  panelSystemSection.Name = "panelSystemSection";
            panelSystemSection.Padding = new Padding(12);
          panelSystemSection.Size = new Size(750, 120);
            panelSystemSection.TabIndex = 1;
            // 
  // lblSystemDescription
       // 
      lblSystemDescription.Font = new Font("Segoe UI", 8F, FontStyle.Regular, GraphicsUnit.Point);
         lblSystemDescription.ForeColor = Color.FromArgb(108, 117, 125);
  lblSystemDescription.Location = new Point(12, 75);
      lblSystemDescription.Name = "lblSystemDescription";
   lblSystemDescription.Size = new Size(720, 30);
     lblSystemDescription.TabIndex = 2;
            lblSystemDescription.Text = "Automatically launch Transcryb when Windows starts up";
   // 
  // chkLaunchOnStartup
      // 
      chkLaunchOnStartup.AutoSize = true;
   chkLaunchOnStartup.Font = new Font("Segoe UI", 10F, FontStyle.Regular, GraphicsUnit.Point);
            chkLaunchOnStartup.Location = new Point(12, 45);
            chkLaunchOnStartup.Name = "chkLaunchOnStartup";
 chkLaunchOnStartup.Size = new Size(177, 27);
     chkLaunchOnStartup.TabIndex = 1;
            chkLaunchOnStartup.Text = "Launch on Startup";
            chkLaunchOnStartup.UseVisualStyleBackColor = true;
         // 
  // lblSystemTitle
       // 
     lblSystemTitle.AutoSize = true;
          lblSystemTitle.Font = new Font("Segoe UI", 11F, FontStyle.Bold, GraphicsUnit.Point);
   lblSystemTitle.Location = new Point(12, 12);
       lblSystemTitle.Name = "lblSystemTitle";
        lblSystemTitle.Size = new Size(218, 25);
            lblSystemTitle.TabIndex = 0;
     lblSystemTitle.Text = "System Integration";
          // 
            // panelError
  // 
            panelError.BackColor = Color.FromArgb(255, 243, 205);
     panelError.BorderStyle = BorderStyle.FixedSingle;
            panelError.Controls.Add(lblErrorMessage);
 panelError.Controls.Add(lblErrorTitle);
    panelError.Location = new Point(16, 448);
    panelError.Name = "panelError";
  panelError.Padding = new Padding(12);
        panelError.Size = new Size(750, 90);
    panelError.TabIndex = 2;
       panelError.Visible = false;
   // 
            // lblErrorMessage
            // 
            lblErrorMessage.Font = new Font("Segoe UI", 9F, FontStyle.Regular, GraphicsUnit.Point);
            lblErrorMessage.ForeColor = Color.FromArgb(108, 117, 125);
       lblErrorMessage.Location = new Point(12, 40);
    lblErrorMessage.Name = "lblErrorMessage";
      lblErrorMessage.Size = new Size(720, 40);
      lblErrorMessage.TabIndex = 1;
lblErrorMessage.Text = "Error message will appear here";
   // 
            // lblErrorTitle
          // 
            lblErrorTitle.AutoSize = true;
            lblErrorTitle.Font = new Font("Segoe UI", 10F, FontStyle.Bold, GraphicsUnit.Point);
            lblErrorTitle.ForeColor = Color.FromArgb(255, 152, 0);
   lblErrorTitle.Location = new Point(12, 12);
     lblErrorTitle.Name = "lblErrorTitle";
  lblErrorTitle.Size = new Size(93, 23);
 lblErrorTitle.TabIndex = 0;
   lblErrorTitle.Text = "Error";
  // 
       // SettingsForm
          // 
            AutoScaleDimensions = new SizeF(8F, 20F);
   AutoScaleMode = AutoScaleMode.Font;
         ClientSize = new Size(800, 650);
         Controls.Add(panelMain);
         Controls.Add(panelHeader);
         MinimumSize = new Size(800, 650);
      Name = "SettingsForm";
    StartPosition = FormStartPosition.CenterScreen;
      Text = "Transcryb";
            panelHeader.ResumeLayout(false);
            panelHeader.PerformLayout();
            panelMain.ResumeLayout(false);
    panelModelSection.ResumeLayout(false);
            panelModelSection.PerformLayout();
            panelModelDownload.ResumeLayout(false);
         panelModelDownload.PerformLayout();
  panelSystemSection.ResumeLayout(false);
  panelSystemSection.PerformLayout();
        panelError.ResumeLayout(false);
            panelError.PerformLayout();
         ResumeLayout(false);
        }

     #endregion

        private Panel panelHeader;
private Label lblTitle;
        private Label lblSubtitle;
        private Panel panelMain;
        private Panel panelModelSection;
        private Label lblModelTitle;
        private ComboBox cmbModel;
        private Label lblModelDescription;
        private Panel panelModelDownload;
        private Label lblModelStatus;
        private Label lblDownloadProgress;
      private ProgressBar progressDownload;
        private Button btnDownload;
        private Button btnUninstall;
        private Panel panelSystemSection;
   private Label lblSystemTitle;
        private CheckBox chkLaunchOnStartup;
        private Label lblSystemDescription;
        private Panel panelError;
        private Label lblErrorTitle;
   private Label lblErrorMessage;
    }
}
