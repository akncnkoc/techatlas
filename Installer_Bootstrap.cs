using System;
using System.ComponentModel;
using System.Diagnostics;
using System.Drawing;
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
    public class InstallerForm : Form
    {
        private ProgressBar progressBar;
        private Label statusLabel;
        private Label titleLabel;
        
        // Configuration
        private const string REPO_OWNER = "akncnkoc";
        private const string REPO_NAME = "techatlas";
        private const string ASSET_NAME = "techatlas.zip";
        private const string APP_NAME = "TechAtlas";
        private const string EXECUTABLE_NAME = "techatlas.exe";
        
        // Paths
        private string installDir;
        private string tempZipPath;

        public InstallerForm()
        {
            InitializeComponent();
            InitializePaths();
            this.Load += InstallerForm_Load;
        }

        private void InitializePaths()
        {
            string localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
            installDir = Path.Combine(localAppData, "TechAtlas");
            tempZipPath = Path.Combine(Path.GetTempPath(), ASSET_NAME);
        }

        private void InitializeComponent()
        {
            this.Size = new Size(400, 250);
            this.Text = APP_NAME + " Kurulumu";
            this.StartPosition = FormStartPosition.CenterScreen;
            this.FormBorderStyle = FormBorderStyle.FixedDialog;
            this.MaximizeBox = false;

            titleLabel = new Label();
            titleLabel.Text = APP_NAME + "\nKurulum ve Güncelleme Aracı";
            titleLabel.Font = new Font("Segoe UI", 12, FontStyle.Bold);
            titleLabel.TextAlign = ContentAlignment.MiddleCenter;
            titleLabel.Dock = DockStyle.Top;
            titleLabel.Height = 80;
            this.Controls.Add(titleLabel);

            statusLabel = new Label();
            statusLabel.Text = "Başlatılıyor...";
            statusLabel.TextAlign = ContentAlignment.MiddleCenter;
            statusLabel.Dock = DockStyle.Bottom;
            statusLabel.Height = 40;
            this.Controls.Add(statusLabel);

            progressBar = new ProgressBar();
            progressBar.Style = ProgressBarStyle.Marquee;
            progressBar.Height = 30;
            progressBar.Width = 340;
            progressBar.Left = (this.ClientSize.Width - progressBar.Width) / 2;
            progressBar.Top = 100;
            this.Controls.Add(progressBar);
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
                // Enable TLS 1.2 (Required for GitHub)
                ServicePointManager.SecurityProtocol = (SecurityProtocolType)3072;

                UpdateStatus("Versiyon kontrolü yapılıyor...");
                
                // 1. Get Remote Version and URL
                var releaseInfo = GetLatestReleaseInfo();
                if (releaseInfo == null)
                {
                    MessageBox.Show("Sunucu ile bağlantı kurulamadı.", "Hata", MessageBoxButtons.OK, MessageBoxIcon.Error);
                    Application.Exit();
                    return;
                }

                string remoteVersion = releaseInfo.Item1;
                string downloadUrl = releaseInfo.Item2;

                // 2. Check Local Version
                string localVersion = GetLocalVersion();
                
                if (!string.IsNullOrEmpty(localVersion))
                {
                    // Simple string comparison or proper version parsing
                    // Assuming tags are like "v1.0.0" or "1.0.0"
                    string normalizedRemote = remoteVersion.TrimStart('v');
                    string normalizedLocal = localVersion.TrimStart('v');

                    if (normalizedRemote == normalizedLocal)
                    {
                        DialogResult result = MessageBox.Show(
                            String.Format("Zaten en son sürümü kullanıyorsunuz ({0}).\nYine de yeniden kurmak ister misiniz?", remoteVersion),
                            "Güncel",
                            MessageBoxButtons.YesNo,
                            MessageBoxIcon.Information);
                        
                        if (result == DialogResult.No)
                        {
                            LaunchApp();
                            Application.Exit();
                            return;
                        }
                    }
                    else
                    {
                        UpdateStatus(String.Format("Yeni sürüm bulundu: {0} (Mevcut: {1})", remoteVersion, localVersion));
                    }
                }

                // 3. Download
                UpdateStatus(String.Format("İndiriliyor: {0}", remoteVersion));
                
                this.Invoke(new Action(() => {
                    progressBar.Style = ProgressBarStyle.Blocks;
                    progressBar.Value = 0;
                }));

                DownloadFile(downloadUrl, tempZipPath);

                // 4. Install
                UpdateStatus("Kuruluyor...");
                CloseRunningApp();

                if (!Directory.Exists(installDir))
                    Directory.CreateDirectory(installDir);

                ExtractZip(tempZipPath, installDir);

                // 5. Shortcuts & Finish
                UpdateStatus("Tamamlanıyor...");
                CreateShortcuts();

                if (File.Exists(tempZipPath))
                    File.Delete(tempZipPath);

                LaunchApp(); // Launch the main app
                Application.Exit();
            }
            catch (Exception ex)
            {
                MessageBox.Show("Hata oluştu:\n" + ex.Message, "Hata", MessageBoxButtons.OK, MessageBoxIcon.Error);
                Application.Exit();
            }
        }

        private string GetLocalVersion()
        {
            try
            {
                string exePath = Path.Combine(installDir, EXECUTABLE_NAME);
                if (File.Exists(exePath))
                {
                    FileVersionInfo versionInfo = FileVersionInfo.GetVersionInfo(exePath);
                    // Returns 1.0.0.0 usually
                    return versionInfo.FileVersion; 
                }
            }
            catch { }
            return null;
        }

        // Returns {Version check ("v1.0.0"), Download URL}
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
                    
                    // Regex for tag_name
                    string tagPattern = "\"tag_name\":\\s*\"([^\"]+)\"";
                    Match tagMatch = Regex.Match(json, tagPattern);
                    
                    // Regex for browser_download_url
                    string urlPattern = String.Format("\"browser_download_url\":\\s*\"([^\"]+/{0})\"", ASSET_NAME);
                    Match urlMatch = Regex.Match(json, urlPattern);
                    
                    if (tagMatch.Success && urlMatch.Success)
                    {
                        return Tuple.Create(tagMatch.Groups[1].Value, urlMatch.Groups[1].Value);
                    }
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine(ex.Message);
            }
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
                
                // Download synchronously to pause the thread
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
                        if (string.IsNullOrEmpty(entry.Name)) // Directory
                        {
                            Directory.CreateDirectory(destinationPath);
                        }
                        else
                        {
                            Directory.CreateDirectory(Path.GetDirectoryName(destinationPath));
                            entry.ExtractToFile(destinationPath, true); // Overwrite
                        }
                    }
                }
            }
        }

        private void CreateShortcuts()
        {
            string desktopDir = Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory);
            string startMenuDir = Environment.GetFolderPath(Environment.SpecialFolder.StartMenu); // Actually Programs folder better?
            
            // Primary Shortcut
            CreateShortcut(
                Path.Combine(desktopDir, "TechAtlas.lnk"),
                Path.Combine(installDir, EXECUTABLE_NAME),
                installDir,
                "Tech Atlas"
            );

            // Drawing Pen Shortcut
            string penBatch = Path.Combine(installDir, "Cizim_Kalemi_Baslat.bat");
            if (File.Exists(penBatch))
            {
                CreateShortcut(
                    Path.Combine(desktopDir, "Cizim Kalemi.lnk"),
                    penBatch,
                    installDir,
                    "Cizim Kalemi",
                    Path.Combine(installDir, EXECUTABLE_NAME) // Use main exe icon
                );
            }
        }

        private void CreateShortcut(string shortcutPath, string targetPath, string workDir, string description, string iconPath = null)
        {
            try
            {
                Type t = Type.GetTypeFromCLSID(new Guid("72C24DD5-D70A-438B-8A42-98424B88AFB8")); // WScript.Shell
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
                    Process.Start(new ProcessStartInfo
                    {
                        FileName = exePath,
                        WorkingDirectory = installDir
                    });
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
