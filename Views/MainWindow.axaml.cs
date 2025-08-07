using Avalonia.Controls;
using Avalonia.Input;

using FrameExtractor.ViewModels;

namespace FrameExtractor.Views;

public partial class MainWindow : Window
{
    public MainWindow()
    {
        InitializeComponent();
        DataContext = new MainWindowViewModel();
        ExtendClientAreaToDecorationsHint = true;
        ExtendClientAreaChromeHints = Avalonia.Platform.ExtendClientAreaChromeHints.NoChrome;
        SystemDecorations = SystemDecorations.None;
        
        // Enable window dragging
        this.PointerPressed += OnPointerPressed;
    }

    private void OnPointerPressed(object? sender, PointerPressedEventArgs e)
    {
        if (e.GetCurrentPoint(this).Properties.IsLeftButtonPressed)
        {
            BeginMoveDrag(e);
        }
    }
}