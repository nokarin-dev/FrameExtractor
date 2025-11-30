using Avalonia.Controls;
using Avalonia.Input;
using FrameExtractor.Helpers;
using FrameExtractor.Services;
using FrameExtractor.ViewModels;

namespace FrameExtractor.Views;

public partial class MainWindow : Window
{
    public MainWindow()
    {
        InitializeComponent();
        DataContext = new MainWindowViewModel();
        
        RoundedWindowHelper.SetupRoundedWindow(this, useNativeChrome: false, cornerRadius: 16);
        
        // Enable window dragging
        this.PointerPressed += OnPointerPressed;
        Logger.Info("Initialized MainWindow");
    }

    private void OnPointerPressed(object? sender, PointerPressedEventArgs e)
    {
        if (e.GetCurrentPoint(this).Properties.IsLeftButtonPressed)
        {
            BeginMoveDrag(e);
        }
    }
}