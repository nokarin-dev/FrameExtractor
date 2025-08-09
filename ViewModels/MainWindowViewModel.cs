using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.ApplicationLifetimes;
using Avalonia.Dialogs.Internal;
using Avalonia.Platform.Storage;

using MsBox.Avalonia;
using MsBox.Avalonia.Enums;
using ReactiveUI;

using System;
using System.Collections.ObjectModel;
using System.IO;
using System.Reactive;
using System.Reactive.Linq;
using System.Text.RegularExpressions;
using System.Threading.Tasks;

using FrameExtractor.Services;

namespace FrameExtractor.ViewModels;

public class MainWindowViewModel : AvaloniaDialogsInternalViewModelBase
{
    private readonly FFmpegService _ffmpegService;
    private string _videoPath = string.Empty;
    private string _outputDirectory = string.Empty;
    private int _fps = 10;
    private string _frameName = "frame";
    private string _selectedFormat = "png";
    private bool _isExtracting;
    private bool _videoAvailable;
    private string _progressText = string.Empty;
    private double _startTimeSeconds;
    private double _endTimeSeconds;
    private double _videoDurationInSeconds;
    
    public string StartTimeFormatted => FormatTime(StartTimeSeconds);
    public string EndTimeFormatted => FormatTime(EndTimeSeconds);
    
    public MainWindowViewModel()
    {
        _ffmpegService = new FFmpegService();
        
        Formats = new ObservableCollection<string> { "png", "jpg", "jpeg" };
        SelectedFormat = Formats[0];

        BrowseVideoCommand = ReactiveCommand.CreateFromTask(BrowseVideo);
        BrowseOutputCommand = ReactiveCommand.CreateFromTask(BrowseOutput);
        ExtractFramesCommand = ReactiveCommand.CreateFromTask(ExtractFrames, this.WhenAnyValue(x => x.CanExtract));
        CloseCommand = ReactiveCommand.Create(CloseApplication);
    
        ShowLogCommand = ReactiveCommand.Create(ShowLogDialog);
    
        Logger.Info("Initialized MainWindowViewModel");

        // Auto-detect video duration when video path changes
        this.WhenAnyValue(x => x.VideoPath)
            .Where(path => !string.IsNullOrEmpty(path) && File.Exists(path))
            .Subscribe(async path => await UpdateVideoDuration(path));
    }
    
    private void ShowLogDialog()
    {
        var mainWindow = GetMainWindow();
        if (mainWindow != null)
        {
            var logDialog = new FrameExtractor.Views.LogDialog();
            logDialog.Show(mainWindow);
        }
    }

    public ReactiveCommand<Unit, Unit> ShowLogCommand { get; }
    public ObservableCollection<string> Formats { get; }

    public string VideoPath
    {
        get => _videoPath;
        set
        {
            this.RaiseAndSetIfChanged(ref _videoPath, value);
            this.RaisePropertyChanged(nameof(CanExtract));
        }
    }

    public bool VideoAvailable
    {
        get => _videoAvailable;
        set {
            this.RaiseAndSetIfChanged(ref _videoAvailable, value);
            this.RaisePropertyChanged(nameof(CanExtract));
        }
    }

    public string OutputDirectory
    {
        get => _outputDirectory;
        set
        {
            this.RaiseAndSetIfChanged(ref _outputDirectory, value);
            this.RaisePropertyChanged(nameof(CanExtract));
        }
    }
    
    public double VideoDurationInSeconds
    {
        get => _videoDurationInSeconds;
        set => this.RaiseAndSetIfChanged(ref _videoDurationInSeconds, value);
    }
    
    public double StartTimeSeconds
    {
        get => _startTimeSeconds;
        set
        {
            this.RaiseAndSetIfChanged(ref _startTimeSeconds, value);
            this.RaisePropertyChanged(nameof(StartTimeFormatted));
        }
    }
    
    public double EndTimeSeconds
    {
        get => _endTimeSeconds;
        set
        {
            this.RaiseAndSetIfChanged(ref _endTimeSeconds, value);
            this.RaisePropertyChanged(nameof(EndTimeFormatted));
        }
    }

    public int Fps
    {
        get => _fps;
        set => this.RaiseAndSetIfChanged(ref _fps, value);
    }

    public string FrameName
    {
        get => _frameName;
        set
        {
            this.RaiseAndSetIfChanged(ref _frameName, value);
            this.RaisePropertyChanged(nameof(CanExtract));
        }
    }

    public string SelectedFormat
    {
        get => _selectedFormat;
        set => this.RaiseAndSetIfChanged(ref _selectedFormat, value);
    }

    public bool IsExtracting
    {
        get => _isExtracting;
        set
        {
            this.RaiseAndSetIfChanged(ref _isExtracting, value);
            this.RaisePropertyChanged(nameof(CanExtract));
        }
    }

    public string ProgressText
    {
        get => _progressText;
        set => this.RaiseAndSetIfChanged(ref _progressText, value);
    }

    public bool CanExtract => !IsExtracting && 
                             !string.IsNullOrEmpty(VideoPath) && 
                             !string.IsNullOrEmpty(OutputDirectory) && 
                             !string.IsNullOrEmpty(FrameName);

    public ReactiveCommand<Unit, Unit> BrowseVideoCommand { get; }
    public ReactiveCommand<Unit, Unit> BrowseOutputCommand { get; }
    public ReactiveCommand<Unit, Unit> ExtractFramesCommand { get; }
    public ReactiveCommand<Unit, Unit> CloseCommand { get; }

    private async Task BrowseVideo()
    {
        var mainWindow = GetMainWindow();
        if (mainWindow == null) return;

        var files = await mainWindow.StorageProvider.OpenFilePickerAsync(new FilePickerOpenOptions()
        {
            Title = "Select Video File",
            AllowMultiple = false,
            FileTypeFilter = new[]
            {
                new FilePickerFileType("Video Files")
                {
                    Patterns = new[] { "*.mp4", "*.avi", "*.mov", "*.mkv", "*.wmv", "*.flv", "*.webm" }
                }
            }
        });

        if (files.Count > 0)
        {
            VideoPath = files[0].Path.LocalPath;
            VideoAvailable = true;
        }
    }

    private async Task BrowseOutput()
    {
        var mainWindow = GetMainWindow();
        if (mainWindow == null) return;

        var folders = await mainWindow.StorageProvider.OpenFolderPickerAsync(new FolderPickerOpenOptions
        {
            Title = "Select Output Directory",
            AllowMultiple = false
        });

        if (folders.Count > 0)
        {
            OutputDirectory = folders[0].Path.LocalPath;
        }
    }

    private async Task UpdateVideoDuration(string videoPath)
    {
        try
        {
            Logger.Info($"Updating video duration for: {videoPath}");
            
            // Ensure FFmpeg is available first
            if (!await _ffmpegService.EnsureFFmpegAvailableAsync())
            {
                Logger.Error("Cannot update video duration: FFmpeg not available");
                
                // Show an error to the user
                await ShowError("FFmpeg Required", "FFmpeg is required to analyze videos. Please install FFmpeg and restart the application.");
                return;
            }

            var duration = await _ffmpegService.GetVideoDurationAsync(videoPath);
            if (!string.IsNullOrEmpty(duration))
            {
                if (TimeSpan.TryParse(duration, out var ts))
                {
                    VideoDurationInSeconds = ts.TotalSeconds;

                    // Auto set end time to video duration
                    EndTimeSeconds = ts.TotalSeconds;

                    // Optional: Reset start time too if needed
                    if (StartTimeSeconds > EndTimeSeconds)
                        StartTimeSeconds = 0;
                    
                    Logger.Info($"Video duration updated: {duration} ({ts.TotalSeconds} seconds)");
                }
                else
                {
                    Logger.Warning($"Failed to parse duration: {duration}");
                }
            }
            else
            {
                Logger.Warning("Could not detect video duration");
            }
        }
        catch (Exception ex)
        {
            Logger.Error($"Error updating video duration for {videoPath}: {ex.Message}", ex);
            await ShowError("Error", $"Failed to analyze video: {ex.Message}");
        }
    }

    private async Task ExtractFrames()
    {
        Logger.Info("Extract frames command triggered");
        
        // Validate inputs
        if (!ValidateInputs())
        {
            Logger.Warning("Input validation failed");
            return;
        }

        try
        {
            IsExtracting = true;
            ProgressText = "Preparing extraction...";
            Logger.Info("Starting frame extraction process");

            // Ensure FFmpeg is available
            if (!await _ffmpegService.EnsureFFmpegAvailableAsync())
            {
                Logger.Error("Cannot extract frames: FFmpeg not available");
                await ShowError("FFmpeg Error", "FFmpeg is not available and could not be installed.");
                return;
            }

            // Create output directory
            Directory.CreateDirectory(OutputDirectory);
            Logger.Info($"Output directory created/verified: {OutputDirectory}");

            var parameters = new FrameExtractionParams
            {
                VideoPath = VideoPath,
                OutputDirectory = OutputDirectory,
                StartTime = StartTimeFormatted,
                EndTime = EndTimeFormatted,
                Fps = Fps,
                FrameNamePrefix = FrameName,
                Format = SelectedFormat
            };

            Logger.Info($"Frame extraction parameters: StartTime={parameters.StartTime}, EndTime={parameters.EndTime}, FPS={parameters.Fps}, Format={parameters.Format}");

            var progress = new Progress<string>(message =>
            {
                ProgressText = message;
                Logger.Debug($"Progress: {message}");
            });
            
            var success = await _ffmpegService.ExtractFramesAsync(parameters, progress);

            if (success)
            {
                Logger.Info("Frame extraction completed successfully");
                await ShowInfo("Success", "Frames extracted successfully!");
            }
            else
            {
                Logger.Error("Frame extraction failed");
                await ShowError("Extraction Failed", "Failed to extract frames. Check the console for details.");
            }
        }
        catch (Exception ex)
        {
            Logger.Error($"Exception during frame extraction: {ex.Message}", ex);
            await ShowError("Error", $"An error occurred: {ex.Message}");
        }
        finally
        {
            IsExtracting = false;
            ProgressText = string.Empty;
            Logger.Info("Frame extraction process finished");
        }
    }

    private bool ValidateInputs()
    {
        Logger.Debug("Validating user inputs");
        
        if (string.IsNullOrWhiteSpace(VideoPath))
        {
            Logger.Warning("Validation failed: No video file selected");
            ShowError("Validation Error", "Please select a video file.").GetAwaiter().GetResult();
            return false;
        }

        if (!File.Exists(VideoPath))
        {
            Logger.Warning($"Validation failed: Video file does not exist - {VideoPath}");
            ShowError("File Error", "Selected video file does not exist.").GetAwaiter().GetResult();
            return false;
        }

        if (string.IsNullOrWhiteSpace(OutputDirectory))
        {
            Logger.Warning("Validation failed: No output directory selected");
            ShowError("Validation Error", "Please select an output directory.").GetAwaiter().GetResult();
            return false;
        }

        if (string.IsNullOrWhiteSpace(FrameName))
        {
            Logger.Warning("Validation failed: No frame name prefix entered");
            ShowError("Validation Error", "Please enter a frame name prefix.").GetAwaiter().GetResult();
            return false;
        }

        if (!IsValidTimeFormat(StartTimeFormatted) || !IsValidTimeFormat(EndTimeFormatted))
        {
            Logger.Warning($"Validation failed: Invalid time format - Start: {StartTimeFormatted}, End: {EndTimeFormatted}");
            ShowError("Time Format Error", "Please use HH:MM:SS format for time values.").GetAwaiter().GetResult();
            return false;
        }

        if (Fps <= 0)
        {
            Logger.Warning($"Validation failed: Invalid FPS value - {Fps}");
            ShowError("FPS Error", "Please enter a valid FPS value.").GetAwaiter().GetResult();
            return false;
        }

        if (StartTimeSeconds >= EndTimeSeconds)
        {
            Logger.Warning($"Validation failed: Start time ({StartTimeSeconds}s) >= End time ({EndTimeSeconds}s)");
            ShowError("Time Range Error", "Start time must be less than end time.").GetAwaiter().GetResult();
            return false;
        }
        
        Logger.Debug("Input validation passed");
        return true;
    }

    private static bool IsValidTimeFormat(string time)
    {
        var regex = new Regex(@"^\d{2}:\d{2}:\d{2}$");
        return regex.IsMatch(time);
    }

    private static Window? GetMainWindow()
    {
        if (Application.Current?.ApplicationLifetime is IClassicDesktopStyleApplicationLifetime desktop)
        {
            return desktop.MainWindow;
        }
        return null;
    }

    private static async Task ShowInfo(string title, string message)
    {
        var mainWindow = GetMainWindow();
        if (mainWindow != null)
        {
            var messageBox = MessageBoxManager.GetMessageBoxStandard(
                title, message, ButtonEnum.Ok, Icon.Info);
            await messageBox.ShowWindowDialogAsync(mainWindow);
        }
    }

    private static async Task ShowError(string title, string message)
    {
        var mainWindow = GetMainWindow();
        if (mainWindow != null)
        {
            var messageBox = MessageBoxManager.GetMessageBoxStandard(
                title, message, ButtonEnum.Ok, Icon.Error);
            await messageBox.ShowWindowDialogAsync(mainWindow);
        }
    }
    
    private string FormatTime(double totalSeconds)
    {
        TimeSpan ts = TimeSpan.FromSeconds(totalSeconds);
        return ts.ToString(@"hh\:mm\:ss");
    }

    private static void CloseApplication()
    {
        if (Application.Current?.ApplicationLifetime is IClassicDesktopStyleApplicationLifetime desktop)
        {
            desktop.Shutdown();
        }
    }
}