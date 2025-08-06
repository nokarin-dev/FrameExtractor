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
    private string _startTime = "00:00:00";
    private string _endTime = "00:00:05";
    private string _fps = "10";
    private string _frameName = "frame";
    private string _selectedFormat = "png";
    private bool _isExtracting = false;
    private string _progressText = string.Empty;

    public MainWindowViewModel()
    {
        _ffmpegService = new FFmpegService();
        
        Formats = new ObservableCollection<string> { "png", "jpg", "jpeg" };
        SelectedFormat = Formats[0];

        BrowseVideoCommand = ReactiveCommand.CreateFromTask(BrowseVideo);
        BrowseOutputCommand = ReactiveCommand.CreateFromTask(BrowseOutput);
        ExtractFramesCommand = ReactiveCommand.CreateFromTask(ExtractFrames, this.WhenAnyValue(x => x.CanExtract));
        CloseCommand = ReactiveCommand.Create(CloseApplication);

        // Auto-detect video duration when video path changes
        this.WhenAnyValue(x => x.VideoPath)
            .Where(path => !string.IsNullOrEmpty(path) && File.Exists(path))
            .Subscribe(async path => await UpdateVideoDuration(path));
    }

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

    public string OutputDirectory
    {
        get => _outputDirectory;
        set
        {
            this.RaiseAndSetIfChanged(ref _outputDirectory, value);
            this.RaisePropertyChanged(nameof(CanExtract));
        }
    }

    public string StartTime
    {
        get => _startTime;
        set => this.RaiseAndSetIfChanged(ref _startTime, value);
    }

    public string EndTime
    {
        get => _endTime;
        set => this.RaiseAndSetIfChanged(ref _endTime, value);
    }

    public string Fps
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
                },
                new FilePickerFileType("All Files")
                {
                    Patterns = new[] { "*.*" }
                }
            }
        });

        if (files.Count > 0)
        {
            VideoPath = files[0].Path.LocalPath;
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
            // Ensure FFmpeg is available first
            if (!await _ffmpegService.EnsureFFmpegAvailableAsync())
                return;

            var duration = await _ffmpegService.GetVideoDurationAsync(videoPath);
            if (!string.IsNullOrEmpty(duration))
            {
                EndTime = duration;
            }
        }
        catch
        {
            // Ignore errors during duration detection
        }
    }

    private async Task ExtractFrames()
    {
        // Validate inputs
        if (!ValidateInputs())
            return;

        try
        {
            IsExtracting = true;
            ProgressText = "Preparing extraction...";

            // Ensure FFmpeg is available
            if (!await _ffmpegService.EnsureFFmpegAvailableAsync())
            {
                await ShowError("FFmpeg Error", "FFmpeg is not available and could not be installed.");
                return;
            }

            // Create output directory
            Directory.CreateDirectory(OutputDirectory);

            var parameters = new FrameExtractionParams
            {
                VideoPath = VideoPath,
                OutputDirectory = OutputDirectory,
                StartTime = StartTime,
                EndTime = EndTime,
                Fps = int.Parse(Fps),
                FrameNamePrefix = FrameName,
                Format = SelectedFormat
            };

            var progress = new Progress<string>(message => ProgressText = message);
            var success = await _ffmpegService.ExtractFramesAsync(parameters, progress);

            if (success)
            {
                await ShowInfo("Success", "Frames extracted successfully!");
            }
            else
            {
                await ShowError("Extraction Failed", "Failed to extract frames. Check the console for details.");
            }
        }
        catch (Exception ex)
        {
            await ShowError("Error", $"An error occurred: {ex.Message}");
        }
        finally
        {
            IsExtracting = false;
            ProgressText = string.Empty;
        }
    }

    private bool ValidateInputs()
    {
        if (string.IsNullOrWhiteSpace(VideoPath))
        {
            ShowError("Validation Error", "Please select a video file.").GetAwaiter().GetResult();
            return false;
        }

        if (!File.Exists(VideoPath))
        {
            ShowError("File Error", "Selected video file does not exist.").GetAwaiter().GetResult();
            return false;
        }

        if (string.IsNullOrWhiteSpace(OutputDirectory))
        {
            ShowError("Validation Error", "Please select an output directory.").GetAwaiter().GetResult();
            return false;
        }

        if (string.IsNullOrWhiteSpace(FrameName))
        {
            ShowError("Validation Error", "Please enter a frame name prefix.").GetAwaiter().GetResult();
            return false;
        }

        if (!IsValidTimeFormat(StartTime) || !IsValidTimeFormat(EndTime))
        {
            ShowError("Time Format Error", "Please use HH:MM:SS format for time values.").GetAwaiter().GetResult();
            return false;
        }

        if (!int.TryParse(Fps, out int fps) || fps <= 0)
        {
            ShowError("FPS Error", "Please enter a valid FPS value.").GetAwaiter().GetResult();
            return false;
        }

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

    private static void CloseApplication()
    {
        if (Application.Current?.ApplicationLifetime is IClassicDesktopStyleApplicationLifetime desktop)
        {
            desktop.Shutdown();
        }
    }
}