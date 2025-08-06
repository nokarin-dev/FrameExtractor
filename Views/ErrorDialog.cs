using Avalonia.Controls;
using Avalonia.Interactivity;

namespace FrameExtractor.Views;

public partial class ErrorDialog : Window
{
    public ErrorDialog(string errorLog)
    {
        InitializeComponent();
        
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