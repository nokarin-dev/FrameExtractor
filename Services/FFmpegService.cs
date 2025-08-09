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
        Logger.Info("Initialized FFmpegService");
    }

    public async Task<bool> EnsureFFmpegAvailableAsync()
    {
        Logger.Info("Checking for FFmpeg availability");
        
        _ffmpegPath = FindFFmpegExecutable();
        
        if (!string.IsNullOrEmpty(_ffmpegPath))
        {
            Logger.Info($"FFmpeg found at: {_ffmpegPath}");
            return true;
        }

        Logger.Warning("FFmpeg not found on system, attempting to install");
        var installResult = await InstallFFmpegAsync();
        
        if (!installResult)
        {
            Logger.Error("Failed to install FFmpeg");
            await ShowFFmpegNotFoundDialog();
            return false;
        }
        
        Logger.Info("FFmpeg installation completed successfully");
        return true;
    }

    private async Task ShowFFmpegNotFoundDialog()
    {
        var mainWindow = GetMainWindow();
        if (mainWindow != null)
        {
            var messageBox = MessageBoxManager.GetMessageBoxStandard(
                "FFmpeg Required",
                "FFmpeg could not be found or installed automatically.\n\n" +
                "Please install FFmpeg manually:\n" +
                "• Windows: Download from https://ffmpeg.org/download.html\n" +
                "• macOS: Install with 'brew install ffmpeg'\n" +
                "• Linux: Install with your package manager (e.g., 'sudo apt install ffmpeg')\n\n" +
                "After installation, restart the application.",
                ButtonEnum.Ok,
                Icon.Warning);
            
            await messageBox.ShowWindowDialogAsync(mainWindow);
        }
    }

    private string? FindFFmpegExecutable()
    {
        Logger.Debug("Searching for FFmpeg executable");
        
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
                    Logger.Debug($"Found FFmpeg in PATH: {ffmpegPath}");
                    return ffmpegPath;
                }
            }
        }

        // Check common installation paths
        var commonPaths = GetCommonFFmpegPaths();
        foreach (var path in commonPaths)
        {
            Logger.Debug($"Checking common path: {path}");
            if (File.Exists(path))
            {
                Logger.Debug($"Found FFmpeg at common path: {path}");
                return path;
            }
        }

        Logger.Debug("FFmpeg executable not found in any common locations");
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
            Logger.Info("Starting FFmpeg installation process");
            
            string downloadUrl;
            string archiveExtension;
            string executableName;

            if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
            {
                // Check for winget first
                if (await TryInstallWithWingetAsync())
                {
                    _ffmpegPath = "ffmpeg";
                    Logger.Info("FFmpeg installed successfully using winget");
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
            Logger.Info($"Using installation directory: {ffmpegDir}");

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
                Logger.Info($"Downloading FFmpeg from: {downloadUrl}");
                
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
                Logger.Info("Download completed, extracting archive");

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
                    Logger.Error("Could not find FFmpeg executable after extraction");
                    return false;
                }

                Logger.Info($"FFmpeg installed successfully at: {_ffmpegPath}");
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
            Logger.Error($"Failed to install FFmpeg: {ex.Message}", ex);
            return false;
        }
    }

    private async Task<bool> TryInstallWithWingetAsync()
    {
        try
        {
            Logger.Info("Checking winget availability");
            
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
                Logger.Info("Winget is available, asking user for permission");
                
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
                        Logger.Info("User approved winget installation, starting process");
                        
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
                        
                        var success = installProcess.ExitCode == 0;
                        if (success)
                        {
                            Logger.Info("Winget installation completed successfully");
                        }
                        else
                        {
                            Logger.Warning($"Winget installation failed with exit code: {installProcess.ExitCode}");
                        }
                        
                        return success;
                    }
                    else
                    {
                        Logger.Info("User declined winget installation");
                    }
                }
            }
            else
            {
                Logger.Debug("Winget not available or failed to list packages");
            }
        }
        catch (Exception ex)
        {
            Logger.Debug($"Winget not available or failed: {ex.Message}");
        }

        return false;
    }

    private string? FindFFmpegInDirectory(string directory, string executableName)
    {
        var files = Directory.GetFiles(directory, executableName, SearchOption.AllDirectories);
        Logger.Debug($"Found {files.Length} matching files in extracted directory");
        return files.Length > 0 ? files[0] : null;
    }

    private async Task ExtractTarArchiveAsync(string archivePath, string extractPath)
    {
        Logger.Info($"Extracting tar archive: {archivePath}");
        
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
        
        if (process.ExitCode == 0)
        {
            Logger.Info("Tar extraction completed successfully");
        }
        else
        {
            Logger.Error($"Tar extraction failed with exit code: {process.ExitCode}");
        }
    }

    public async Task<string?> GetVideoDurationAsync(string videoPath)
    {
        Logger.Info($"Getting duration for video: {videoPath}");
        
        if (string.IsNullOrEmpty(_ffmpegPath))
        {
            Logger.Warning("FFmpeg path not set, ensuring availability");
            if (!await EnsureFFmpegAvailableAsync())
            {
                Logger.Error("Cannot get video duration: FFmpeg not available");
                return null;
            }
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
                var duration = durationMatch.Groups[1].Value;
                Logger.Info($"Video duration detected: {duration}");
                return duration;
            }
            else
            {
                Logger.Warning("Could not parse video duration from FFmpeg output");
            }
        }
        catch (Exception ex)
        {
            Logger.Error($"Error getting video duration for {videoPath}: {ex.Message}", ex);
        }

        Logger.Info("Using default fallback duration: 00:00:05");
        return "00:00:05"; // Default fallback
    }

    public async Task<bool> ExtractFramesAsync(FrameExtractionParams parameters, IProgress<string>? progress = null)
    {
        Logger.Info($"Starting frame extraction - Video: {parameters.VideoPath}, Output: {parameters.OutputDirectory}");
        
        if (string.IsNullOrEmpty(_ffmpegPath))
        {
            Logger.Warning("FFmpeg path not set, ensuring availability");
            if (!await EnsureFFmpegAvailableAsync())
            {
                Logger.Error("Cannot extract frames: FFmpeg not available");
                return false;
            }
        }

        try
        {
            progress?.Report("Starting frame extraction...");

            var outputPattern = Path.Combine(parameters.OutputDirectory, $"{parameters.FrameNamePrefix}%d.{parameters.Format}");
            
            var arguments = $"-ss {parameters.StartTime} -to {parameters.EndTime} -i \"{parameters.VideoPath}\" -vf fps={parameters.Fps} -fps_mode vfr \"{outputPattern}\"";

            Logger.Info($"FFmpeg arguments: {arguments}");

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
                            var progressMessage = $"Processing: {timeMatch.Groups[1].Value}";
                            progress?.Report(progressMessage);
                            Logger.Debug(progressMessage);
                        }
                    }
                }
            });

            await process.WaitForExitAsync();
            await outputTask;

            if (process.ExitCode == 0)
            {
                Logger.Info("Frame extraction completed successfully");
                progress?.Report("Frame extraction completed successfully!");
                return true;
            }
            else
            {
                Logger.Error($"FFmpeg failed with exit code {process.ExitCode}. Error output: {errorOutput}");
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
            Logger.Error($"Error during frame extraction: {ex.Message}", ex);
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