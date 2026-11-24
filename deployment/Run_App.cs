using System;
using System.Diagnostics;
using System.IO;
using System.Windows.Forms;

namespace HekalLauncher
{
    static class Program
    {
        [STAThread]
        static void Main()
        {
            string baseDir = AppDomain.CurrentDomain.BaseDirectory;
            string exePath = Path.Combine(baseDir, "App", "garage_erp.exe");

            if (!File.Exists(exePath))
            {
                exePath = Path.Combine(baseDir, "garage_erp.exe");
            }

            if (!File.Exists(exePath))
            {
                exePath = @"C:\HekalGarage\garage_erp.exe";
            }

            if (File.Exists(exePath))
            {
                ProcessStartInfo psi = new ProcessStartInfo
                {
                    FileName = exePath,
                    WorkingDirectory = Path.GetDirectoryName(exePath)
                };
                Process.Start(psi);
            }
            else
            {
                MessageBox.Show(
                    "لم يتم العثور على ملف تشغيل البرنامج garage_erp.exe.\nيرجى تشغيل مثبت البرنامج Setup.exe أولاً.",
                    "تنبيه",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Warning,
                    MessageBoxDefaultButton.Button1,
                    MessageBoxOptions.RightAlign | MessageBoxOptions.RtlReading);
            }
        }
    }
}
