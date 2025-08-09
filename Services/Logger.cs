using System;
using System.Collections.Generic;
using System.Text;

namespace FrameExtractor.Services;

public class Logger
{
    private static readonly List<LogEntry> Logs = new();
    private static readonly object Lock = new object();

    public static event EventHandler? LogUpdated;

    public static void Log(LogLevel level, string message, Exception? exception = null)
    {
        lock (Lock)
        {
            var entry = new LogEntry
            {
                Timestamp = DateTime.Now,
                Level = level,
                Message = message,
                Exception = exception
            };

            Logs.Add(entry);
            
            // Also log to console
            var logMessage = $"[{entry.Timestamp:HH:mm:ss}] [{level}] {message}";
            if (exception != null)
            {
                logMessage += $"\n    Exception: {exception.Message}";
            }
            Console.WriteLine(logMessage);
        }

        // Notify listeners
        LogUpdated?.Invoke(null, EventArgs.Empty);
    }

    public static void Info(string message) => Log(LogLevel.Info, message);
    public static void Warning(string message) => Log(LogLevel.Warning, message);
    public static void Error(string message, Exception? exception = null) => Log(LogLevel.Error, message, exception);
    public static void Debug(string message) => Log(LogLevel.Debug, message);

    public static string GetAllLogs()
    {
        lock (Lock)
        {
            var sb = new StringBuilder();
            foreach (var log in Logs)
            {
                var level = log.Level.ToString().ToUpper();
                sb.AppendLine($"[{log.Timestamp:yyyy-MM-dd HH:mm:ss}] [ {level} ] {log.Message}");
                
                if (log.Exception != null)
                {
                    sb.AppendLine($"    Exception: {log.Exception.Message}");
                    if (!string.IsNullOrEmpty(log.Exception.StackTrace))
                    {
                        sb.AppendLine($"    Stack Trace: {log.Exception.StackTrace}");
                    }
                }
            }
            return sb.ToString();
        }
    }

    public static void ClearLogs()
    {
        lock (Lock)
        {
            Logs.Clear();
        }
        LogUpdated?.Invoke(null, EventArgs.Empty);
    }
}

public class LogEntry
{
    public DateTime Timestamp { get; set; }
    public LogLevel Level { get; set; }
    public string Message { get; set; } = string.Empty;
    public Exception? Exception { get; set; }
}

public enum LogLevel
{
    Debug,
    Info,
    Warning,
    Error
}