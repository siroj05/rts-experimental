using System;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Text;
using System.Windows.Forms;

internal static class Launcher
{
    private const string PackagePrefix = "RTSPC3:";
    private const int VersionLength = 12;
    private const string Stamp = ".rts-pc-build";

    [STAThread]
    private static int Main(string[] args)
    {
        try
        {
            string executable = Assembly.GetExecutingAssembly().Location;
            string version = PackageVersion(executable);
            if (args.Length == 2 && args[0] == "--extract" && version != null)
            {
                string target = Path.GetFullPath(args[1]);
                if (target.Length > Path.GetPathRoot(target).Length)
                    target = target.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
                ExtractOnce(executable, target, version);
                return 0;
            }
            if (args.Length != 0)
                throw new ArgumentException("Gunakan --extract <folder> pada paket mandiri.");

            string folder = Path.GetDirectoryName(executable);
            if (version != null)
            {
                folder = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                    "RTS PC v3", version);
                ExtractOnce(executable, folder, version);
            }

            using (Process game = Process.Start(new ProcessStartInfo {
                FileName = Path.Combine(folder, "spring.exe"),
                WorkingDirectory = folder,
                Arguments = "--isolation --only-local --menu RTSPCMenu.sdd",
                UseShellExecute = false
            })) { }
            return 0;
        }
        catch (Exception error)
        {
            if (args.Length == 0)
                MessageBox.Show(error.Message, "RTS PC v3", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return 1;
        }
    }

    private static string PackageVersion(string executable)
    {
        // Pembuat ZIP menulis ID build di kolom komentar pada akhir executable.
        var tag = new byte[PackagePrefix.Length + VersionLength];
        using (var stream = File.OpenRead(executable))
        using (var reader = new BinaryReader(stream))
        {
            stream.Seek(-tag.Length, SeekOrigin.End);
            tag = reader.ReadBytes(tag.Length);
        }
        string comment = Encoding.ASCII.GetString(tag);
        if (!comment.StartsWith(PackagePrefix, StringComparison.Ordinal)) return null;
        string version = comment.Substring(PackagePrefix.Length);
        foreach (char digit in version)
            if (!Uri.IsHexDigit(digit)) throw new InvalidDataException("ID paket tidak valid.");
        return version;
    }

    private static bool IsExtracted(string folder, string version)
    {
        string marker = Path.Combine(folder, Stamp);
        return File.Exists(marker) && File.ReadAllText(marker) == version
            && File.Exists(Path.Combine(folder, "spring.exe"))
            && File.Exists(Path.Combine(folder, "games", "RTSPCMenu.sdd", "LuaMenu", "main.lua"))
            && File.Exists(Path.Combine(folder, "maps", "lembah-sungai-1v1.sdz"))
            && File.Exists(Path.Combine(folder, "maps", "bukit-tengah-1v1.sdz"));
    }

    private static void ExtractOnce(string executable, string destination, string version)
    {
        if (IsExtracted(destination, version)) return;
        if (Directory.Exists(destination) || File.Exists(destination))
            throw new IOException("Pilih folder baru untuk ekstraksi RTS PC v3.\n" + destination);

        string temporary = destination + ".partial-" + Guid.NewGuid().ToString("N");
        Directory.CreateDirectory(temporary);
        try
        {
            string root = Path.GetFullPath(temporary) + Path.DirectorySeparatorChar;
            using (var zip = ZipFile.OpenRead(executable))
            {
                foreach (ZipArchiveEntry entry in zip.Entries)
                {
                    string path = Path.GetFullPath(Path.Combine(root, entry.FullName));
                    if (!path.StartsWith(root, StringComparison.OrdinalIgnoreCase))
                        throw new InvalidDataException("Lokasi file paket tidak valid.");
                    Directory.CreateDirectory(Path.GetDirectoryName(path));
                    entry.ExtractToFile(path);
                }
            }
            File.WriteAllText(Path.Combine(temporary, Stamp), version);
            if (!IsExtracted(temporary, version)) throw new InvalidDataException("Isi paket tidak lengkap.");
            try { Directory.Move(temporary, destination); }
            catch (IOException) { if (!IsExtracted(destination, version)) throw; }
        }
        finally
        {
            if (Directory.Exists(temporary)) Directory.Delete(temporary, true);
        }
    }
}
