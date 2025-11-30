using System;
using System.Runtime.InteropServices;
using Avalonia.Controls;
using Avalonia.Platform;
using FrameExtractor.Services;

namespace FrameExtractor.Helpers;

public static class RoundedWindowHelper
{
    #region Windows 11 API
    [DllImport("dwmapi.dll")]
    private static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int attrValue, int attrSize);

    private const int DwmwaWindowCornerPreference = 33;
    private const int DwmwcpRound = 2;
    private const int DwmwcpRoundsmall = 3;
    #endregion

    #region macOS API
    [DllImport("/System/Library/Frameworks/AppKit.framework/AppKit")]
    private static extern IntPtr objc_getClass(string className);
    
    [DllImport("/System/Library/Frameworks/AppKit.framework/AppKit")]
    private static extern IntPtr objc_msgSend(IntPtr receiver, IntPtr selector);
    
    [DllImport("/System/Library/Frameworks/AppKit.framework/AppKit")]
    private static extern void objc_msgSend_double(IntPtr receiver, IntPtr selector, double value);
    
    [DllImport("/System/Library/Frameworks/AppKit.framework/AppKit")]
    private static extern IntPtr sel_registerName(string name);
    #endregion

    private static bool TryEnableWindowsRoundedCorners(IntPtr hwnd, bool smallRadius = false)
    {
        try
        {
            int preference = smallRadius ? DwmwcpRoundsmall : DwmwcpRound;
            int result = DwmSetWindowAttribute(
                hwnd,
                DwmwaWindowCornerPreference,
                ref preference,
                sizeof(int)
            );
            
            bool success = result == 0;
            if (success)
            {
                Logger.Info("[Windows 11] Native rounded corners enabled successfully");
            }
            return success;
        }
        catch (Exception ex)
        {
            Logger.Info($"[Windows 11] Failed to enable rounded corners: {ex.Message}");
            return false;
        }
    }
    
    private static bool TryEnableMacOsRoundedCorners(IntPtr nsWindow, double radius = 10.0)
    {
        try
        {
            // NSWindow.contentView.layer.cornerRadius = radius
            var contentView = objc_msgSend(nsWindow, sel_registerName("contentView"));
            if (contentView == IntPtr.Zero) return false;
            
            var layer = objc_msgSend(contentView, sel_registerName("layer"));
            if (layer == IntPtr.Zero) return false;
            
            // Set corner radius
            objc_msgSend_double(layer, sel_registerName("setCornerRadius:"), radius);
            
            // Enable masksToBounds
            objc_msgSend(layer, sel_registerName("setMasksToBounds:"));
            
            Logger.Info($"[macOS] Native rounded corners enabled (radius: {radius})");
            return true;
        }
        catch (Exception ex)
        {
            Logger.Info($"[macOS] Failed to enable rounded corners: {ex.Message}");
            return false;
        }
    }

    public static void SetupRoundedWindow(Window window, bool useNativeChrome = false, double cornerRadius = 16.0)
    {
        window.ExtendClientAreaToDecorationsHint = true;
        window.ExtendClientAreaChromeHints = useNativeChrome
            ? ExtendClientAreaChromeHints.PreferSystemChrome
            : ExtendClientAreaChromeHints.NoChrome;

        window.Opened += (s, e) =>
        {
            var handle = window.TryGetPlatformHandle();
            if (handle == null)
            {
                Logger.Info("[Platform] Could not get platform handle");
                return;
            }

            bool roundedEnabled = false;

            // Windows 11
            if (OperatingSystem.IsWindowsVersionAtLeast(10, 0, 22000) && 
                handle.HandleDescriptor == "HWND")
            {
                Logger.Info("[Platform] Detected Windows 11");
                roundedEnabled = TryEnableWindowsRoundedCorners(handle.Handle, smallRadius: cornerRadius < 10);
                
                if (roundedEnabled && !useNativeChrome)
                {
                    window.SystemDecorations = SystemDecorations.BorderOnly;
                }
            }
            // macOS
            else if (OperatingSystem.IsMacOS() && handle.HandleDescriptor == "NSWindow")
            {
                Logger.Info("[Platform] Detected macOS");
                roundedEnabled = TryEnableMacOsRoundedCorners(handle.Handle, cornerRadius);
                
                if (!useNativeChrome)
                {
                    window.SystemDecorations = SystemDecorations.None;
                }
            }
            // Other platforms
            else
            {
                var platform = OperatingSystem.IsWindows() ? "Windows 10 or older" :
                              OperatingSystem.IsLinux() ? "Linux" : "Unknown";
                Logger.Info($"[Platform] Detected {platform} - native rounded corners not supported, keeping square corners");
                
                if (!useNativeChrome)
                {
                    window.SystemDecorations = SystemDecorations.None;
                }
            }

            if (!roundedEnabled && !useNativeChrome)
            {
                Logger.Info("[Platform] Window will have square corners with custom chrome");
            }
        };
    }
    
    public static bool IsNativeRoundedCornersSupported()
    {
        // Windows 11
        if (OperatingSystem.IsWindowsVersionAtLeast(10, 0, 22000))
        {
            Logger.Info("[Check] Windows 11 detected - native rounded corners supported");
            return true;
        }

        // macOS
        if (OperatingSystem.IsMacOS())
        {
            Logger.Info("[Check] macOS detected - native rounded corners supported");
            return true;
        }

        // Other platforms  
        var platform = OperatingSystem.IsWindows() ? "Windows 10 or older" :
                      OperatingSystem.IsLinux() ? "Linux" : "Unknown platform";
        Logger.Info($"[Check] {platform} - native rounded corners not supported");
        return false;
    }
    
    public static string GetPlatformName()
    {
        if (OperatingSystem.IsWindowsVersionAtLeast(10, 0, 22000))
            return "Windows 11";
        if (OperatingSystem.IsWindows())
            return "Windows 10 or older";
        if (OperatingSystem.IsMacOS())
            return "macOS";
        if (OperatingSystem.IsLinux())
            return "Linux";
        return "Unknown";
    }
}