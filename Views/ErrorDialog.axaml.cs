using Avalonia.Controls;
using Avalonia.Interactivity;
using FrameExtractor.Helpers;

namespace FrameExtractor.Views;

public partial class ErrorDialog : Window
{
    public ErrorDialog()
    {
        InitializeComponent();
        
        RoundedWindowHelper.SetupRoundedWindow(this, useNativeChrome: false, cornerRadius: 16);
    }
    
    public ErrorDialog(string errorLog) : this()
    {
        if (LogTextBlock != null)
        {
            LogTextBlock.Text = errorLog;
        }
    }

    private void CloseButton_Click(object? sender, RoutedEventArgs e)
    {
        Close();
    }
}