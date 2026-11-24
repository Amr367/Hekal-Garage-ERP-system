using System;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Security.Principal;
using System.Diagnostics;
using System.Drawing;
using System.Windows.Forms;
using Microsoft.Win32;
using System.Runtime.InteropServices;

namespace HekalInstaller
{
    static class Program
    {
        [STAThread]
        static void Main()
        {
            // Self-elevation to administrator
            WindowsPrincipal principal = new WindowsPrincipal(WindowsIdentity.GetCurrent());
            if (!principal.IsInRole(WindowsBuiltInRole.Administrator))
            {
                ProcessStartInfo startInfo = new ProcessStartInfo();
                startInfo.UseShellExecute = true;
                startInfo.WorkingDirectory = Environment.CurrentDirectory;
                startInfo.FileName = Application.ExecutablePath;
                startInfo.Verb = "runas";
                try
                {
                    Process.Start(startInfo);
                    return;
                }
                catch
                {
                    MessageBox.Show(
                        "يتطلب التثبيت تشغيل البرنامج بصلاحيات المسؤول (Run as administrator).",
                        "تنبيه",
                        MessageBoxButtons.OK,
                        MessageBoxIcon.Warning,
                        MessageBoxDefaultButton.Button1,
                        MessageBoxOptions.RightAlign | MessageBoxOptions.RtlReading);
                    return;
                }
            }

            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new InstallerForm());
        }
    }

    public class InstallerForm : Form
    {
        private TextBox txtPath;
        private Button btnBrowse;
        private CheckBox chkDesktop;
        private CheckBox chkStartMenu;
        private CheckBox chkFirewall;
        private CheckBox chkLaunch;
        private ProgressBar progressBar;
        private Label lblStatus;
        private Button btnInstall;
        private Button btnCancel;
        private bool isFinished = false;

        public InstallerForm()
        {
            InitializeComponent();
        }

        private void InitializeComponent()
        {
            this.Text = "تثبيت برنامج مركز هيكل لإصلاح السيارات";
            this.Size = new Size(580, 480);
            this.FormBorderStyle = FormBorderStyle.FixedDialog;
            this.MaximizeBox = false;
            this.StartPosition = FormStartPosition.CenterScreen;
            this.RightToLeft = RightToLeft.Yes;
            this.RightToLeftLayout = true;
            this.BackColor = Color.FromArgb(248, 249, 250);
            this.Font = new Font("Segoe UI", 9.5f, FontStyle.Regular);

            try
            {
                this.Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath);
            }
            catch { }

            // ── Header Panel ────────────────────────────────────────────────
            Panel headerPanel = new Panel();
            headerPanel.Dock = DockStyle.Top;
            headerPanel.Height = 95;
            headerPanel.BackColor = Color.FromArgb(20, 35, 60);

            Label lblTitle = new Label();
            lblTitle.Text = "مركز هيكل لإصلاح السيارات";
            lblTitle.Font = new Font("Segoe UI", 15f, FontStyle.Bold);
            lblTitle.ForeColor = Color.White;
            lblTitle.Location = new Point(25, 18);
            lblTitle.AutoSize = true;

            Label lblSubtitle = new Label();
            lblSubtitle.Text = "معالج تثبيت نظام إدارة الورشة والصيانة والمخازن المتكامل — الإصدار 1.0";
            lblSubtitle.Font = new Font("Segoe UI", 9f, FontStyle.Regular);
            lblSubtitle.ForeColor = Color.FromArgb(210, 225, 245);
            lblSubtitle.Location = new Point(25, 52);
            lblSubtitle.AutoSize = true;

            headerPanel.Controls.Add(lblTitle);
            headerPanel.Controls.Add(lblSubtitle);
            this.Controls.Add(headerPanel);

            // ── Main Content Container ──────────────────────────────────────
            Panel contentPanel = new Panel();
            contentPanel.Location = new Point(25, 110);
            contentPanel.Size = new Size(515, 290);

            Label lblPathTitle = new Label();
            lblPathTitle.Text = "مجلد تثبيت البرنامج على هذا الجهاز:";
            lblPathTitle.Font = new Font("Segoe UI", 9.5f, FontStyle.Bold);
            lblPathTitle.Location = new Point(5, 5);
            lblPathTitle.AutoSize = true;
            contentPanel.Controls.Add(lblPathTitle);

            txtPath = new TextBox();
            txtPath.Text = @"C:\HekalGarage";
            txtPath.Location = new Point(100, 32);
            txtPath.Size = new Size(410, 26);
            contentPanel.Controls.Add(txtPath);

            btnBrowse = new Button();
            btnBrowse.Text = "استعراض...";
            btnBrowse.Location = new Point(5, 30);
            btnBrowse.Size = new Size(88, 30);
            btnBrowse.Click += (s, e) => {
                using (FolderBrowserDialog fbd = new FolderBrowserDialog())
                {
                    fbd.Description = "اختر مجلد تثبيت البرنامج:";
                    fbd.SelectedPath = txtPath.Text;
                    if (fbd.ShowDialog() == DialogResult.OK)
                    {
                        txtPath.Text = fbd.SelectedPath;
                    }
                }
            };
            contentPanel.Controls.Add(btnBrowse);

            // Options Checkboxes
            chkDesktop = new CheckBox();
            chkDesktop.Text = "إنشاء اختصار على سطح المكتب (Desktop Shortcut)";
            chkDesktop.Checked = true;
            chkDesktop.Location = new Point(5, 75);
            chkDesktop.AutoSize = true;
            contentPanel.Controls.Add(chkDesktop);

            chkStartMenu = new CheckBox();
            chkStartMenu.Text = "إنشاء اختصار في قائمة ابدأ (Start Menu)";
            chkStartMenu.Checked = true;
            chkStartMenu.Location = new Point(5, 105);
            chkStartMenu.AutoSize = true;
            contentPanel.Controls.Add(chkStartMenu);

            chkFirewall = new CheckBox();
            chkFirewall.Text = "إعداد جدار الحماية (Windows Firewall) للسماح بربط الأجهزة على الشبكة";
            chkFirewall.Checked = true;
            chkFirewall.Location = new Point(5, 135);
            chkFirewall.AutoSize = true;
            contentPanel.Controls.Add(chkFirewall);

            chkLaunch = new CheckBox();
            chkLaunch.Text = "تشغيل برنامج مركز هيكل تلقائياً بعد اكتمال التثبيت";
            chkLaunch.Checked = true;
            chkLaunch.Location = new Point(5, 165);
            chkLaunch.AutoSize = true;
            contentPanel.Controls.Add(chkLaunch);

            // Progress & Status
            lblStatus = new Label();
            lblStatus.Text = "جاهز للبدء. اضغط (تثبيت الآن) لتثبيت النظام.";
            lblStatus.Font = new Font("Segoe UI", 9f, FontStyle.Italic);
            lblStatus.ForeColor = Color.FromArgb(70, 80, 95);
            lblStatus.Location = new Point(5, 205);
            lblStatus.Size = new Size(505, 22);
            contentPanel.Controls.Add(lblStatus);

            progressBar = new ProgressBar();
            progressBar.Location = new Point(5, 230);
            progressBar.Size = new Size(505, 22);
            progressBar.Style = ProgressBarStyle.Blocks;
            contentPanel.Controls.Add(progressBar);

            this.Controls.Add(contentPanel);

            // ── Footer Buttons ──────────────────────────────────────────────
            Panel footerPanel = new Panel();
            footerPanel.Dock = DockStyle.Bottom;
            footerPanel.Height = 60;
            footerPanel.BackColor = Color.FromArgb(235, 238, 242);

            btnInstall = new Button();
            btnInstall.Text = "تثبيت الآن";
            btnInstall.Font = new Font("Segoe UI", 10f, FontStyle.Bold);
            btnInstall.BackColor = Color.FromArgb(20, 35, 60);
            btnInstall.ForeColor = Color.White;
            btnInstall.FlatStyle = FlatStyle.Flat;
            btnInstall.FlatAppearance.BorderSize = 0;
            btnInstall.Location = new Point(25, 12);
            btnInstall.Size = new Size(130, 36);
            btnInstall.Click += BtnInstall_Click;
            footerPanel.Controls.Add(btnInstall);

            btnCancel = new Button();
            btnCancel.Text = "إلغاء";
            btnCancel.Font = new Font("Segoe UI", 9.5f);
            btnCancel.Location = new Point(165, 12);
            btnCancel.Size = new Size(90, 36);
            btnCancel.Click += (s, e) => this.Close();
            footerPanel.Controls.Add(btnCancel);

            this.Controls.Add(footerPanel);
        }

        private void BtnInstall_Click(object sender, EventArgs e)
        {
            if (isFinished)
            {
                if (chkLaunch.Checked)
                {
                    string exePath = Path.Combine(txtPath.Text.Trim(), "garage_erp.exe");
                    if (File.Exists(exePath))
                    {
                        Process.Start(new ProcessStartInfo
                        {
                            FileName = exePath,
                            WorkingDirectory = txtPath.Text.Trim()
                        });
                    }
                }
                Application.Exit();
                return;
            }

            string targetDir = txtPath.Text.Trim();
            if (string.IsNullOrEmpty(targetDir))
            {
                MessageBox.Show("يرجى تحديد مسار مجلد التثبيت.", "تنبيه", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }

            btnInstall.Enabled = false;
            btnBrowse.Enabled = false;
            txtPath.Enabled = false;
            chkDesktop.Enabled = false;
            chkStartMenu.Enabled = false;
            chkFirewall.Enabled = false;
            chkLaunch.Enabled = false;
            btnCancel.Enabled = false;

            progressBar.Style = ProgressBarStyle.Marquee;
            progressBar.MarqueeAnimationSpeed = 30;

            System.Threading.ThreadPool.QueueUserWorkItem((state) =>
            {
                try
                {
                    PerformInstallation(targetDir);
                    this.Invoke(new Action(() =>
                    {
                        progressBar.Style = ProgressBarStyle.Blocks;
                        progressBar.Value = 100;
                        lblStatus.Text = "تم تثبيت البرنامج بنجاح!";
                        lblStatus.ForeColor = Color.FromArgb(15, 120, 50);
                        btnInstall.Enabled = true;
                        btnInstall.Text = "تشغيل وإنهاء";
                        btnCancel.Text = "إغلاق";
                        btnCancel.Enabled = true;
                        isFinished = true;

                        MessageBox.Show(
                            "تم تثبيت برنامج مركز هيكل لإصلاح السيارات بنجاح!\nوتم إنشاء الاختصارات على سطح المكتب.",
                            "اكتمل التثبيت",
                            MessageBoxButtons.OK,
                            MessageBoxIcon.Information,
                            MessageBoxDefaultButton.Button1,
                            MessageBoxOptions.RightAlign | MessageBoxOptions.RtlReading);
                    }));
                }
                catch (Exception ex)
                {
                    this.Invoke(new Action(() =>
                    {
                        progressBar.Style = ProgressBarStyle.Blocks;
                        progressBar.Value = 0;
                        lblStatus.Text = "فشل التثبيت: " + ex.Message;
                        lblStatus.ForeColor = Color.Red;
                        btnInstall.Enabled = true;
                        btnCancel.Enabled = true;

                        MessageBox.Show(
                            "حدث خطأ أثناء التثبيت:\n" + ex.Message,
                            "خطأ في التثبيت",
                            MessageBoxButtons.OK,
                            MessageBoxIcon.Error);
                    }));
                }
            });
        }

        private void PerformInstallation(string targetDir)
        {
            UpdateStatus("جاري إنشاء مجلد التثبيت...");
            if (!Directory.Exists(targetDir))
            {
                Directory.CreateDirectory(targetDir);
            }

            // Extract embedded ZIP payload
            UpdateStatus("جاري استخراج ونسخ ملفات البرنامج...");
            Assembly asm = Assembly.GetExecutingAssembly();
            using (Stream zipStream = asm.GetManifestResourceStream("app_payload"))
            {
                if (zipStream != null)
                {
                    using (ZipArchive archive = new ZipArchive(zipStream, ZipArchiveMode.Read))
                    {
                        foreach (ZipArchiveEntry entry in archive.Entries)
                        {
                            string destinationPath = Path.GetFullPath(Path.Combine(targetDir, entry.FullName));
                            if (!destinationPath.StartsWith(Path.GetFullPath(targetDir), StringComparison.OrdinalIgnoreCase))
                            {
                                continue;
                            }

                            if (string.IsNullOrEmpty(entry.Name))
                            {
                                Directory.CreateDirectory(destinationPath);
                            }
                            else
                            {
                                string parentDir = Path.GetDirectoryName(destinationPath);
                                if (!Directory.Exists(parentDir))
                                {
                                    Directory.CreateDirectory(parentDir);
                                }
                                entry.ExtractToFile(destinationPath, true);
                            }
                        }
                    }
                }
                else
                {
                    // Fallback to local App directory if running portable
                    string localApp = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "App");
                    if (Directory.Exists(localApp))
                    {
                        CopyDirectory(localApp, targetDir);
                    }
                    else
                    {
                        throw new FileNotFoundException("تعذر العثور على حزمة ملفات البرنامج المرفقة.");
                    }
                }
            }

            string exePath = Path.Combine(targetDir, "garage_erp.exe");

            // Shortcuts
            if (chkDesktop.Checked)
            {
                UpdateStatus("جاري إنشاء اختصار سطح المكتب...");
                string desktop = Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory);
                string shortcutPath = Path.Combine(desktop, "مركز هيكل لإصلاح السيارات.lnk");
                CreateShortcut(shortcutPath, exePath, targetDir, "مركز هيكل لإصلاح السيارات");
            }

            if (chkStartMenu.Checked)
            {
                UpdateStatus("جاري إنشاء اختصار قائمة ابدأ...");
                string startMenu = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonPrograms), "مركز هيكل لإصلاح السيارات");
                if (!Directory.Exists(startMenu)) Directory.CreateDirectory(startMenu);
                string shortcutPath = Path.Combine(startMenu, "مركز هيكل لإصلاح السيارات.lnk");
                CreateShortcut(shortcutPath, exePath, targetDir, "مركز هيكل لإصلاح السيارات");
            }

            // Firewall
            if (chkFirewall.Checked)
            {
                UpdateStatus("جاري تهيئة جدار الحماية (Windows Firewall)...");
                try
                {
                    ProcessStartInfo psi = new ProcessStartInfo
                    {
                        FileName = "netsh",
                        Arguments = "advfirewall firewall add rule name=\"Hekal Garage ERP LAN\" dir=in action=allow protocol=TCP localport=4455",
                        CreateNoWindow = true,
                        UseShellExecute = false
                    };
                    Process p = Process.Start(psi);
                    p.WaitForExit(3000);
                }
                catch { }
            }

            // Registry Entry for Windows Programs & Features
            UpdateStatus("جاري تسجيل البرنامج في نظام التشغيل...");
            try
            {
                using (RegistryKey key = Registry.LocalMachine.CreateSubKey(@"Software\Microsoft\Windows\CurrentVersion\Uninstall\HekalGarageERP"))
                {
                    if (key != null)
                    {
                        key.SetValue("DisplayName", "مركز هيكل لإصلاح السيارات");
                        key.SetValue("DisplayVersion", "1.0");
                        key.SetValue("Publisher", "مركز هيكل");
                        key.SetValue("InstallLocation", targetDir);
                        key.SetValue("DisplayIcon", exePath + ",0");
                        key.SetValue("NoModify", 1, RegistryValueKind.DWord);
                        key.SetValue("NoRepair", 1, RegistryValueKind.DWord);
                    }
                }
            }
            catch { }
        }

        private void UpdateStatus(string text)
        {
            if (this.InvokeRequired)
            {
                this.Invoke(new Action(() => lblStatus.Text = text));
            }
            else
            {
                lblStatus.Text = text;
            }
        }

        private static void CopyDirectory(string sourceDir, string targetDir)
        {
            Directory.CreateDirectory(targetDir);
            foreach (var file in Directory.GetFiles(sourceDir))
            {
                File.Copy(file, Path.Combine(targetDir, Path.GetFileName(file)), true);
            }
            foreach (var sub in Directory.GetDirectories(sourceDir))
            {
                CopyDirectory(sub, Path.Combine(targetDir, Path.GetFileName(sub)));
            }
        }

        private static void CreateShortcut(string shortcutPath, string targetPath, string workingDir, string description)
        {
            try
            {
                Type shellType = Type.GetTypeFromProgID("WScript.Shell");
                dynamic shell = Activator.CreateInstance(shellType);
                dynamic shortcut = shell.CreateShortcut(shortcutPath);
                shortcut.TargetPath = targetPath;
                shortcut.WorkingDirectory = workingDir;
                shortcut.Description = description;
                shortcut.Save();
            }
            catch
            {
                // Fallback using PowerShell
                string psCmd = string.Format(
                    "$ws = New-Object -ComObject WScript.Shell; $s = $ws.CreateShortcut('{0}'); $s.TargetPath = '{1}'; $s.WorkingDirectory = '{2}'; $s.Description = '{3}'; $s.Save()",
                    shortcutPath.Replace("'", "''"),
                    targetPath.Replace("'", "''"),
                    workingDir.Replace("'", "''"),
                    description.Replace("'", "''"));
                Process p = Process.Start(new ProcessStartInfo
                {
                    FileName = "powershell.exe",
                    Arguments = "-NoProfile -Command \"" + psCmd + "\"",
                    CreateNoWindow = true,
                    UseShellExecute = false
                });
                if (p != null) p.WaitForExit(3000);
            }
        }
    }
}
