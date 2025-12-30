using System;
using System.ComponentModel;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.IO;
using System.IO.Compression;
using System.Net;
using System.Reflection;
using System.Text;
using System.Threading;
using System.Windows.Forms;
using System.Text.RegularExpressions;

namespace TechAtlasInstaller
{
    public class ModernProgressBar : Control
    {
        private int _value;
        public int Value
        {
            get { return _value; }
            set { _value = value; Invalidate(); }
        }

        public ModernProgressBar()
        {
            this.SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer, true);
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            Rectangle rect = this.ClientRectangle;
            Graphics g = e.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;

            // Background (Darker track)
            using (SolidBrush brush = new SolidBrush(Color.FromArgb(40, 40, 55)))
            {
                using (GraphicsPath path = RoundedRect(rect, rect.Height / 2)) 
                {
                    g.FillPath(brush, path);
                }
            }

            // Progress (Glowing Gradient)
            if (_value > 0)
            {
                int width = (int)(rect.Width * ((double)_value / 100));
                if (width < 1) width = 1;
                
                Rectangle progressRect = new Rectangle(0, 0, width, rect.Height);
                using (GraphicsPath path = RoundedRect(progressRect, rect.Height / 2))
                {
                    using (LinearGradientBrush brush = new LinearGradientBrush(rect, Color.FromArgb(0, 198, 255), Color.FromArgb(0, 114, 255), LinearGradientMode.Horizontal))
                    {
                        g.FillPath(brush, path);
                    }
                }
            }
        }

        private GraphicsPath RoundedRect(Rectangle bounds, int radius)
        {
            int diameter = radius * 2;
            Size size = new Size(diameter, diameter);
            Rectangle arc = new Rectangle(bounds.Location, size);
            GraphicsPath path = new GraphicsPath();

            if (radius == 0)
            {
                path.AddRectangle(bounds);
                return path;
            }

            // Top left arc  
            path.AddArc(arc, 180, 90);

            // Top right arc  
            arc.X = bounds.Right - diameter;
            path.AddArc(arc, 270, 90);

            // Bottom right arc  
            arc.Y = bounds.Bottom - diameter;
            path.AddArc(arc, 0, 90);

            // Bottom left arc 
            arc.X = bounds.Left;
            path.AddArc(arc, 90, 90);

            path.CloseFigure();
            return path;
        }
    }

    public class InstallerForm : Form
    {
        private ModernProgressBar progressBar;
        private Label statusLabel;
        private Label titleLabel;
        private Label versionLabel; // [NEW]
        
        // Configuration
        private const string REPO_OWNER = "akncnkoc";
        private const string REPO_NAME = "techatlas";
        private const string ASSET_NAME = "techatlas.zip";
        private const string APP_NAME = "TechAtlas";
        private const string EXECUTABLE_NAME = "techatlas.exe";
        
        // Paths
        private string installDir;
        private string tempZipPath;

        // Mouse Drag
        private bool mouseDown;
        private Point lastLocation;

        public InstallerForm()
        {
            InitializeComponent();
            InitializePaths();
            this.Load += InstallerForm_Load;
            
            // Drag support
            this.MouseDown += (s, e) => { mouseDown = true; lastLocation = e.Location; };
            this.MouseMove += (s, e) => {
                if (mouseDown)
                {
                    this.Location = new Point(
                        (this.Location.X - lastLocation.X) + e.X, (this.Location.Y - lastLocation.Y) + e.Y);
                    this.Update();
                }
            };
            this.MouseUp += (s, e) => { mouseDown = false; };
        }

        private void InitializePaths()
        {
            string localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
            installDir = Path.Combine(localAppData, "TechAtlas");
            tempZipPath = Path.Combine(Path.GetTempPath(), ASSET_NAME);
        }

        private void InitializeComponent()
        {
            this.Size = new Size(500, 350);
            this.Text = APP_NAME;
            this.StartPosition = FormStartPosition.CenterScreen;
            this.FormBorderStyle = FormBorderStyle.None;
            this.BackColor = Color.FromArgb(18, 18, 24); // Dark Background
            this.DoubleBuffered = true;

            // Set window shape
            SetRoundedRegion(20);

            // Title
            titleLabel = new Label();
            titleLabel.Text = "TechAtlas Installer";
            titleLabel.ForeColor = Color.White;
            titleLabel.Font = new Font("Segoe UI", 20, FontStyle.Bold);
            titleLabel.TextAlign = ContentAlignment.MiddleCenter;
            titleLabel.AutoSize = false;
            titleLabel.Size = new Size(this.Width, 50);
            titleLabel.Location = new Point(0, 160); // Below logo
            titleLabel.BackColor = Color.Transparent;
            this.Controls.Add(titleLabel);

            // Version Label
            versionLabel = new Label();
            versionLabel.Text = "";
            versionLabel.ForeColor = Color.FromArgb(100, 100, 120);
            versionLabel.Font = new Font("Segoe UI", 12, FontStyle.Regular);
            versionLabel.TextAlign = ContentAlignment.MiddleCenter;
            versionLabel.AutoSize = false;
            versionLabel.Size = new Size(this.Width, 25);
            versionLabel.Location = new Point(0, 205);
            versionLabel.BackColor = Color.Transparent;
            this.Controls.Add(versionLabel);

            // Progress Bar
            progressBar = new ModernProgressBar();
            progressBar.Size = new Size(400, 10); 
            progressBar.Location = new Point(50, 240);
            this.Controls.Add(progressBar);

            // Status
            statusLabel = new Label();
            statusLabel.Text = "Hazırlanıyor...";
            statusLabel.ForeColor = Color.FromArgb(170, 170, 190);
            statusLabel.Font = new Font("Segoe UI", 10);
            statusLabel.TextAlign = ContentAlignment.MiddleCenter;
            statusLabel.AutoSize = false;
            statusLabel.Size = new Size(this.Width, 30);
            statusLabel.Location = new Point(0, 260);
            statusLabel.BackColor = Color.Transparent;
            this.Controls.Add(statusLabel);
        }

        private GraphicsPath _windowPath;

        private void SetRoundedRegion(int radius)
        {
            if (_windowPath != null) _windowPath.Dispose();
            _windowPath = new System.Drawing.Drawing2D.GraphicsPath();
            _windowPath.AddLine(radius, 0, this.Width - radius, 0);
            _windowPath.AddArc(this.Width - radius, 0, radius, radius, 270, 90);
            _windowPath.AddLine(this.Width, radius, this.Width, this.Height - radius);
            _windowPath.AddArc(this.Width - radius, this.Height - radius, radius, radius, 0, 90);
            _windowPath.AddLine(this.Width - radius, this.Height, radius, this.Height);
            _windowPath.AddArc(0, this.Height - radius, radius, radius, 90, 90);
            _windowPath.AddLine(0, this.Height - radius, 0, radius);
            _windowPath.AddArc(0, 0, radius, radius, 180, 90);
            this.Region = new Region(_windowPath);
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            base.OnPaint(e);
            Graphics g = e.Graphics;
            g.SmoothingMode = SmoothingMode.HighQuality;

            // 1. Draw Gradient Background
            using (LinearGradientBrush brush = new LinearGradientBrush(this.ClientRectangle, 
                Color.FromArgb(20, 23, 39), // Deep Blue
                Color.FromArgb(10, 10, 15), // Nearly Black
                LinearGradientMode.Vertical))
            {
                g.FillRectangle(brush, this.ClientRectangle);
            }

            // 2. Draw Vector Logo (Stylized 'A' or 'Globe')
            // Center X, Top 50
            int cx = this.Width / 2;
            int cy = 90;
            int r = 40;

            // Glow behind logo
            using (GraphicsPath path = new GraphicsPath())
            {
                path.AddEllipse(cx - r - 10, cy - r - 10, (r + 10) * 2, (r + 10) * 2);
                using (PathGradientBrush pgb = new PathGradientBrush(path))
                {
                    pgb.CenterColor = Color.FromArgb(50, 0, 120, 255);
                    pgb.SurroundColors = new Color[] { Color.Transparent };
                    g.FillPath(pgb, path);
                }
            }

            // Logo Circle
            Rectangle logoRect = new Rectangle(cx - r, cy - r, r * 2, r * 2);
            using (LinearGradientBrush brush = new LinearGradientBrush(logoRect, Color.FromArgb(86, 76, 230), Color.FromArgb(50, 40, 180), LinearGradientMode.ForwardDiagonal))
            {
                g.FillEllipse(brush, logoRect);
            }
            
            // Logo Symbol (Stylized 'TA')
            using (Font f = new Font("Segoe UI", 28, FontStyle.Bold))
            using (StringFormat sf = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center })
            {
                g.DrawString("TA", f, Brushes.White, logoRect, sf);
            }

            // 3. Draw Border
            if (_windowPath != null)
            {
                using (Pen p = new Pen(Color.FromArgb(50, 50, 70), 1))
                {
                    g.DrawPath(p, _windowPath);
                }
            }
        }

        private void InstallerForm_Load(object sender, EventArgs e)
        {
            Thread workerThread = new Thread(PerformInstallation);
            workerThread.Start();
        }

        private void UpdateStatus(string message)
        {
            if (this.InvokeRequired)
            {
                this.Invoke(new Action<string>(UpdateStatus), message);
                return;
            }
            statusLabel.Text = message;
        }

        private void PerformInstallation()
        {
            try
            {
                // Enable TLS 1.2
                ServicePointManager.SecurityProtocol = (SecurityProtocolType)3072;

                UpdateStatus("Sunucuya bağlanılıyor...");
                Thread.Sleep(500); // Visual delay
                
                // 1. Get Remote Version
                var releaseInfo = GetLatestReleaseInfo();
                if (releaseInfo == null)
                {
                    MessageBox.Show("İnternet bağlantınızı kontrol ediniz.", "Bağlantı Hatası", MessageBoxButtons.OK, MessageBoxIcon.Error);
                    Application.Exit();
                    return;
                }

                string remoteVersion = releaseInfo.Item1;
                string downloadUrl = releaseInfo.Item2;


                UpdateStatus("Versiyon bulundu");
                this.Invoke(new Action(() => {
                    versionLabel.Text = remoteVersion;
                }));
                Thread.Sleep(500);

                // 2. Check Local
                string localVersion = GetLocalVersion();
                
                if (!string.IsNullOrEmpty(localVersion))
                {
                    string normalizedRemote = remoteVersion.TrimStart('v');
                    string normalizedLocal = localVersion.TrimStart('v');
                    
                    if (normalizedRemote == normalizedLocal)
                    {
                        // Optional silent check could depend on arguments
                    }
                }

                // 3. Download
                UpdateStatus("Dosyalar indiriliyor...");
                this.Invoke(new Action(() => { progressBar.Value = 0; }));
                
                DownloadFile(downloadUrl, tempZipPath);

                // 4. Install
                UpdateStatus("Kurulum yapılıyor...");
                Thread.Sleep(500);
                
                CloseRunningApp();

                if (!Directory.Exists(installDir))
                    Directory.CreateDirectory(installDir);

                ExtractZip(tempZipPath, installDir);

                // 5. Finish
                UpdateStatus("Kısayollar oluşturuluyor...");
                CreateShortcuts();

                if (File.Exists(tempZipPath))
                    File.Delete(tempZipPath);
                    
                UpdateStatus("Başlatılıyor...");
                Thread.Sleep(800);

                LaunchApp();
                Application.Exit();
            }
            catch (Exception ex)
            {
                MessageBox.Show("Kurulum hatası:\n" + ex.Message, "Hata", MessageBoxButtons.OK, MessageBoxIcon.Error);
                Application.Exit();
            }
        }

        // Helper Methods (GetLocalVersion, GetLatestReleaseInfo, DownloadFile, CloseRunningApp, ExtractZip, CreateShortcuts, LaunchApp)
        // Kept same logic, just compacting for brevity in this replace call if needed.
        // I will include the full methods here to be safe.

        private string GetLocalVersion()
        {
            try
            {
                string exePath = Path.Combine(installDir, EXECUTABLE_NAME);
                if (File.Exists(exePath))
                {
                    FileVersionInfo versionInfo = FileVersionInfo.GetVersionInfo(exePath);
                    return versionInfo.FileVersion; 
                }
            }
            catch { }
            return null;
        }

        private Tuple<string, string> GetLatestReleaseInfo()
        {
            try
            {
                string apiUrl = String.Format("https://api.github.com/repos/{0}/{1}/releases/latest", REPO_OWNER, REPO_NAME);
                HttpWebRequest request = (HttpWebRequest)WebRequest.Create(apiUrl);
                request.UserAgent = "TechAtlasInstaller";
                
                using (HttpWebResponse response = (HttpWebResponse)request.GetResponse())
                using (StreamReader reader = new StreamReader(response.GetResponseStream()))
                {
                    string json = reader.ReadToEnd();
                    string tagPattern = "\"tag_name\":\\s*\"([^\"]+)\"";
                    Match tagMatch = Regex.Match(json, tagPattern);
                    string urlPattern = String.Format("\"browser_download_url\":\\s*\"([^\"]+/{0})\"", ASSET_NAME);
                    Match urlMatch = Regex.Match(json, urlPattern);
                    
                    if (tagMatch.Success && urlMatch.Success)
                    {
                        return Tuple.Create(tagMatch.Groups[1].Value, urlMatch.Groups[1].Value);
                    }
                }
            }
            catch { }
            return null;
        }

        private void DownloadFile(string url, string path)
        {
            using (WebClient client = new WebClient())
            {
                client.DownloadProgressChanged += (s, e) =>
                {
                    this.Invoke(new Action(() => {
                        progressBar.Value = e.ProgressPercentage;
                    }));
                };
                client.DownloadFileTaskAsync(new Uri(url), path).Wait();
            }
        }

        private void CloseRunningApp()
        {
            foreach (var process in Process.GetProcessesByName(Path.GetFileNameWithoutExtension(EXECUTABLE_NAME)))
            {
                try { process.Kill(); } catch { }
            }
        }

        private void ExtractZip(string zipPath, string extractPath)
        {
            using (ZipArchive archive = ZipFile.OpenRead(zipPath))
            {
                foreach (ZipArchiveEntry entry in archive.Entries)
                {
                    string destinationPath = Path.GetFullPath(Path.Combine(extractPath, entry.FullName));
                    if (destinationPath.StartsWith(extractPath, StringComparison.Ordinal))
                    {
                        if (string.IsNullOrEmpty(entry.Name)) Directory.CreateDirectory(destinationPath);
                        else {
                            Directory.CreateDirectory(Path.GetDirectoryName(destinationPath));
                            entry.ExtractToFile(destinationPath, true);
                        }
                    }
                }
            }
        }

        private void CreateShortcuts()
        {
            string desktopDir = Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory);
            CreateShortcut(Path.Combine(desktopDir, "TechAtlas.lnk"), Path.Combine(installDir, EXECUTABLE_NAME), installDir, "Tech Atlas", Path.Combine(installDir, EXECUTABLE_NAME));
            
            string penBatch = Path.Combine(installDir, "TechPen.bat");
            if (File.Exists(penBatch))
                CreateShortcut(Path.Combine(desktopDir, "TechPen.lnk"), penBatch, installDir, "TechPen", Path.Combine(installDir, EXECUTABLE_NAME));
        }

        private void CreateShortcut(string shortcutPath, string targetPath, string workDir, string description, string iconPath = null)
        {
            try
            {
                Type t = Type.GetTypeFromCLSID(new Guid("72C24DD5-D70A-438B-8A42-98424B88AFB8")); 
                dynamic shell = Activator.CreateInstance(t);
                var shortcut = shell.CreateShortcut(shortcutPath);
                shortcut.TargetPath = targetPath;
                shortcut.WorkingDirectory = workDir;
                shortcut.Description = description;
                if (iconPath != null) shortcut.IconLocation = iconPath;
                shortcut.Save();
            }
            catch { }
        }

        private void LaunchApp()
        {
            try
            {
                string exePath = Path.Combine(installDir, EXECUTABLE_NAME);
                if (File.Exists(exePath))
                {
                    Process.Start(new ProcessStartInfo { FileName = exePath, WorkingDirectory = installDir });
                }
            }
            catch { }
        }

        [STAThread]
        static void Main()
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new InstallerForm());
        }
    }
}
