using System;
using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Interactivity;
using Avalonia.Threading;
using FrameExtractor.Helpers;
using FrameExtractor.Services;

namespace FrameExtractor.Views;

public partial class LogDialog : Window
{
    public LogDialog()
    {
        InitializeComponent();
        
        RoundedWindowHelper.SetupRoundedWindow(this, useNativeChrome: true, cornerRadius: 16);
        
        // Subscribe to logger events
        Logger.LogUpdated += OnLogUpdated;
        
        // Load existing logs
        UpdateLogDisplay();
        
        // Enable window dragging
        this.PointerPressed += OnPointerPressed;
    }

    private void OnLogUpdated(object? sender, EventArgs e)
    {
        Dispatcher.UIThread.InvokeAsync(UpdateLogDisplay);
    }

    private void UpdateLogDisplay()
    {
        if (LogTextBlock != null)
        {
            LogTextBlock.Text = Logger.GetAllLogs();
            
            // Auto-scroll to bottom if enabled
            if (AutoScrollCheckBox?.IsChecked == true && LogScrollViewer != null)
            {
                LogScrollViewer.ScrollToEnd();
            }
        }
    }

    private void ClearButton_Click(object? sender, RoutedEventArgs e)
    {
        Logger.ClearLogs();
        UpdateLogDisplay();
    }

    private void CloseButton_Click(object? sender, RoutedEventArgs e)
    {
        Close();
    }
    
    private void OnPointerPressed(object? sender, PointerPressedEventArgs e)
    {
        if (e.GetCurrentPoint(this).Properties.IsLeftButtonPressed)
        {
            BeginMoveDrag(e);
        }
    }

    protected override void OnClosed(EventArgs e)
    {
        // Unsubscribe from logger events
        Logger.LogUpdated -= OnLogUpdated;
        base.OnClosed(e);
    }
}