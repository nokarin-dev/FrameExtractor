using Avalonia.Controls;
using Avalonia.Threading;

namespace FrameExtractor.Views;

public partial class DownloadDialog : Window
{
    public DownloadDialog()
    {
        InitializeComponent();
        ExtendClientAreaToDecorationsHint = true;
        ExtendClientAreaChromeHints = Avalonia.Platform.ExtendClientAreaChromeHints.NoChrome;
    }

    public void UpdateProgress(int percent, string statusText)
    {
        Dispatcher.UIThread.InvokeAsync(() =>
        {
            if (ProgressBar != null)
                ProgressBar.Value = percent;
            
            if (StatusLabel != null)
                StatusLabel.Text = statusText;
        });
    }
}