using Avalonia;
using Avalonia.Controls.ApplicationLifetimes;
using MsBox.Avalonia;
using MsBox.Avalonia.Enums;

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Net.Http;
using System.Runtime.InteropServices;
using System.Text.RegularExpressions;
using System.Threading.Tasks;

using FrameExtractor.Views;

namespace FrameExtractor.Services;

public class FFmpegService
{
    private readonly HttpClient _httpClient;
    private string? _ffmpegPath;

    public FFmpegService()
    {
        _httpClient = new HttpClient();
    }

    public async Task<bool> EnsureFFmpegAvailableAsync()
    {
        _ffmpegPath = FindFFmpegExecutable();
        
        if (!string.IsNullOrEmpty(_ffmpegPath))
        {
            Console.WriteLine($"FFmpeg found at: {_ffmpegPath}");
            return true;
        }

        Console.WriteLine("FFmpeg not found, attempting to install...");
        return await InstallFFmpegAsync();
    }

    private string? FindFFmpegExecutable()
    {
        // Check if ffmpeg is in PATH
        var pathVar = Environment.GetEnvironmentVariable("PATH");
        if (!string.IsNullOrEmpty(pathVar))
        {
            var paths = pathVar.Split(Path.PathSeparator);
            foreach (var path in paths)
            {
                var ffmpegPath = Path.Combine(path, RuntimeInformation.IsOSPlatform(OSPlatform.Windows) ? "ffmpeg.exe" : "ffmpeg");
                if (File.Exists(ffmpegPath))
                {
                    return ffmpegPath;
                }
            }
        }

        // Check common installation paths
        var commonPaths = GetCommonFFmpegPaths();
        foreach (var path in commonPaths)
        {
            if (File.Exists(path))
            {
                return path;
            }
        }

        return null;
    }

    private List<string> GetCommonFFmpegPaths()
    {
        var paths = new List<string>();

        if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
        {
            paths.AddRange(new[]
            {
                @"C:\ffmpeg\bin\ffmpeg.exe",
                @"C:\Program Files\ffmpeg\bin\ffmpeg.exe",
                @"C:\Program Files (x86)\ffmpeg\bin\ffmpeg.exe",
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "ffmpeg", "ffmpeg.exe")
            });
        }
        else if (RuntimeInformation.IsOSPlatform(OSPlatform.OSX))
        {
            paths.AddRange(new[]
            {
                "/usr/local/bin/ffmpeg",
                "/opt/homebrew/bin/ffmpeg",
                "/usr/bin/ffmpeg"
            });
        }
        else // Linux and others
        {
            paths.AddRange(new[]
            {
                "/usr/bin/ffmpeg",
                "/usr/local/bin/ffmpeg",
                "/snap/bin/ffmpeg"
            });
        }

        return paths;
    }

    private async Task<bool> InstallFFmpegAsync()
    {
        try
        {
            string downloadUrl;
            string archiveExtension;
            string executableName;

            if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
            {
                // Check for winget first
                if (await TryInstallWithWingetAsync())
                {
                    _ffmpegPath = "ffmpeg";
                    return true;
                }

                downloadUrl = "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip";
                archiveExtension = ".zip";
                executableName = "ffmpeg.exe";
            }
            else if (RuntimeInformation.IsOSPlatform(OSPlatform.OSX))
            {
                downloadUrl = "https://evermeet.cx/ffmpeg/ffmpeg.zip";
                archiveExtension = ".zip";
                executableName = "ffmpeg";
            }
            else // Linux
            {
                downloadUrl = "https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz";
                archiveExtension = ".tar.xz";
                executableName = "ffmpeg";
            }

            var appDataPath = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
            var ffmpegDir = Path.Combine(appDataPath, "FrameExtractor", "ffmpeg");
            Directory.CreateDirectory(ffmpegDir);

            var archivePath = Path.Combine(ffmpegDir, $"ffmpeg{archiveExtension}");

            // Show download dialog
            var downloadDialog = new DownloadDialog();
            var mainWindow = GetMainWindow();
            if (mainWindow != null)
            {
                downloadDialog.Show(mainWindow);
            }

            try
            {
                Console.WriteLine($"Downloading FFmpeg from: {downloadUrl}");
                
                using var response = await _httpClient.GetAsync(downloadUrl, HttpCompletionOption.ResponseHeadersRead);
                response.EnsureSuccessStatusCode();
                
                var totalBytes = response.Content.Headers.ContentLength ?? 0;
                var downloadedBytes = 0L;

                await using var contentStream = await response.Content.ReadAsStreamAsync();
                await using var fileStream = File.Create(archivePath);
                
                var buffer = new byte[8192];
                int bytesRead;
                
                while ((bytesRead = await contentStream.ReadAsync(buffer, 0, buffer.Length)) > 0)
                {
                    await fileStream.WriteAsync(buffer, 0, bytesRead);
                    downloadedBytes += bytesRead;
                    
                    if (totalBytes > 0)
                    {
                        var percentage = (int)((downloadedBytes * 100) / totalBytes);
                        downloadDialog.UpdateProgress(percentage, $"Downloading FFmpeg... {percentage}%");
                    }
                }

                downloadDialog.UpdateProgress(100, "Extracting archive...");

                Console.WriteLine("Extracting FFmpeg archive...");
                
                var extractPath = Path.Combine(ffmpegDir, "extracted");
                Directory.CreateDirectory(extractPath);

                if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
                {
                    ZipFile.ExtractToDirectory(archivePath, extractPath, true);
                }
                else
                {
                    // For Linux/macOS, use tar command
                    await ExtractTarArchiveAsync(archivePath, extractPath);
                }

                // Find the ffmpeg executable in the extracted files
                _ffmpegPath = FindFFmpegInDirectory(extractPath, executableName);

                if (string.IsNullOrEmpty(_ffmpegPath))
                {
                    Console.WriteLine("Could not find FFmpeg executable after extraction");
                    return false;
                }

                Console.WriteLine($"FFmpeg installed successfully at: {_ffmpegPath}");
                downloadDialog.UpdateProgress(100, "FFmpeg installed successfully!");
                
                await Task.Delay(1000); // Show success message briefly
                return true;
            }
            finally
            {
                downloadDialog.Close();
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Failed to install FFmpeg: {ex.Message}");
            return false;
        }
    }

    private async Task<bool> TryInstallWithWingetAsync()
    {
        try
        {
            var checkProcess = new Process
            {
                StartInfo = new ProcessStartInfo
                {
                    FileName = "winget",
                    Arguments = "list",
                    UseShellExecute = false,
                    CreateNoWindow = true,
                    RedirectStandardOutput = true
                }
            };

            checkProcess.Start();
            await checkProcess.WaitForExitAsync();

            if (checkProcess.ExitCode == 0)
            {
                // Winget is available, ask user if they want to use it
                var mainWindow = GetMainWindow();
                if (mainWindow != null)
                {
                    var messageBox = MessageBoxManager.GetMessageBoxStandard(
                        "Use Winget?",
                        "Winget package manager is available.\nDo you want to install FFmpeg using winget?",
                        ButtonEnum.YesNo,
                        Icon.Question);
                    
                    var result = await messageBox.ShowWindowDialogAsync(mainWindow);
                    
                    if (result == ButtonResult.Yes)
                    {
                        var installProcess = new Process
                        {
                            StartInfo = new ProcessStartInfo
                            {
                                FileName = "winget",
                                Arguments = "install --id Gyan.FFmpeg -e --accept-source-agreements --accept-package-agreements",
                                UseShellExecute = false,
                                CreateNoWindow = true
                            }
                        };

                        installProcess.Start();
                        await installProcess.WaitForExitAsync();
                        return installProcess.ExitCode == 0;
                    }
                }
            }
        }
        catch
        {
            // Winget not available or failed
        }

        return false;
    }

    private string? FindFFmpegInDirectory(string directory, string executableName)
    {
        var files = Directory.GetFiles(directory, executableName, SearchOption.AllDirectories);
        return files.Length > 0 ? files[0] : null;
    }

    private async Task ExtractTarArchiveAsync(string archivePath, string extractPath)
    {
        var process = new Process
        {
            StartInfo = new ProcessStartInfo
            {
                FileName = "tar",
                Arguments = $"-xf \"{archivePath}\" -C \"{extractPath}\"",
                UseShellExecute = false,
                CreateNoWindow = true
            }
        };

        process.Start();
        await process.WaitForExitAsync();
    }

    public async Task<string?> GetVideoDurationAsync(string videoPath)
    {
        if (string.IsNullOrEmpty(_ffmpegPath))
        {
            if (!await EnsureFFmpegAvailableAsync())
                return null;
        }

        try
        {
            var process = new Process
            {
                StartInfo = new ProcessStartInfo
                {
                    FileName = _ffmpegPath,
                    Arguments = $"-i \"{videoPath}\"",
                    UseShellExecute = false,
                    RedirectStandardError = true,
                    CreateNoWindow = true
                }
            };

            process.Start();
            var stderr = await process.StandardError.ReadToEndAsync();
            await process.WaitForExitAsync();

            var durationMatch = Regex.Match(stderr, @"Duration: (\d{2}:\d{2}:\d{2})");
            if (durationMatch.Success)
            {
                return durationMatch.Groups[1].Value;
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error getting video duration for {videoPath}: {ex.Message}");
        }

        return "00:00:05"; // Default fallback
    }

    public async Task<bool> ExtractFramesAsync(FrameExtractionParams parameters, IProgress<string>? progress = null)
    {
        if (string.IsNullOrEmpty(_ffmpegPath))
        {
            if (!await EnsureFFmpegAvailableAsync())
                return false;
        }

        try
        {
            progress?.Report("Starting frame extraction...");

            var outputPattern = Path.Combine(parameters.OutputDirectory, $"{parameters.FrameNamePrefix}%d.{parameters.Format}");
            
            var arguments = $"-ss {parameters.StartTime} -to {parameters.EndTime} -i \"{parameters.VideoPath}\" -vf fps={parameters.Fps} -fps_mode vfr \"{outputPattern}\"";

            var process = new Process
            {
                StartInfo = new ProcessStartInfo
                {
                    FileName = _ffmpegPath,
                    Arguments = arguments,
                    UseShellExecute = false,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    CreateNoWindow = true
                }
            };

            Console.WriteLine($"Running FFmpeg with arguments: {process.StartInfo.Arguments}");

            process.Start();

            // Monitor progress by reading stderr
            var errorOutput = string.Empty;
            var outputTask = Task.Run(async () =>
            {
                var buffer = new char[1024];
                while (!process.StandardError.EndOfStream)
                {
                    var read = await process.StandardError.ReadAsync(buffer, 0, buffer.Length);
                    if (read > 0)
                    {
                        var chunk = new string(buffer, 0, read);
                        errorOutput += chunk;
                        
                        // Try to extract progress information
                        var timeMatch = Regex.Match(chunk, @"time=(\d{2}:\d{2}:\d{2})");
                        if (timeMatch.Success)
                        {
                            progress?.Report($"Processing: {timeMatch.Groups[1].Value}");
                        }
                    }
                }
            });

            await process.WaitForExitAsync();
            await outputTask;

            if (process.ExitCode == 0)
            {
                progress?.Report("Frame extraction completed successfully!");
                return true;
            }
            else
            {
                Console.WriteLine($"FFmpeg failed with exit code {process.ExitCode}. Error: {errorOutput}");
                progress?.Report("Frame extraction failed");
                
                // Show detailed error dialog
                var mainWindow = GetMainWindow();
                if (mainWindow != null)
                {
                    var errorDialog = new ErrorDialog(errorOutput);
                    await errorDialog.ShowDialog(mainWindow);
                }
                
                return false;
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error during frame extraction: {ex.Message}");
            progress?.Report("Frame extraction failed due to error");
            return false;
        }
    }

    private static Avalonia.Controls.Window? GetMainWindow()
    {
        if (Application.Current?.ApplicationLifetime is IClassicDesktopStyleApplicationLifetime desktop)
        {
            return desktop.MainWindow;
        }
        return null;
    }
}

public class FrameExtractionParams
{
    public required string VideoPath { get; set; }
    public required string OutputDirectory { get; set; }
    public required string StartTime { get; set; }
    public required string EndTime { get; set; }
    public required int Fps { get; set; }
    public required string FrameNamePrefix { get; set; }
    public required string Format { get; set; }
}