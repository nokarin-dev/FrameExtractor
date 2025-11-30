using Avalonia.Controls;
using Avalonia.Threading;
using FrameExtractor.Helpers;

namespace FrameExtractor.Views;

public partial class DownloadDialog : Window
{
    public DownloadDialog()
    {
        InitializeComponent();
        
        RoundedWindowHelper.SetupRoundedWindow(this, useNativeChrome: false, cornerRadius: 16);
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