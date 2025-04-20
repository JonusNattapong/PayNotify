package com.paynotify.app;

import android.content.Context;
import android.content.Intent;
import android.provider.Settings;
import android.util.Log;

import androidx.annotation.NonNull;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

public class NotificationListenerPlugin implements FlutterPlugin, MethodCallHandler, BankNotificationListenerService.NotificationEventListener {
    private static final String TAG = "NotificationPlugin";
    private static final String CHANNEL_NAME = "com.paynotify/notification_listener";

    private MethodChannel channel;
    private Context context;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPlugin.FlutterPluginBinding binding) {
        context = binding.getApplicationContext();
        channel = new MethodChannel(binding.getBinaryMessenger(), CHANNEL_NAME);
        channel.setMethodCallHandler(this);

        // Set this class as the notification event listener
        BankNotificationListenerService.setNotificationEventListener(this);
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPlugin.FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
        channel = null;
        context = null;
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        switch (call.method) {
            case "isNotificationServiceEnabled":
                boolean isEnabled = isNotificationListenerEnabled();
                result.success(isEnabled);
                break;
            case "openNotificationListenerSettings":
                openNotificationListenerSettings();
                result.success(null);
                break;
            case "startService":
                startNotificationListenerService();
                result.success(null);
                break;
            case "stopService":
                stopNotificationListenerService();
                result.success(null);
                break;
            default:
                result.notImplemented();
                break;
        }
    }

    @Override
    public void onNotificationReceived(String packageName, String title, String text) {
        if (channel != null && context != null) {
            try {
                // Process notification using BankNotificationProcessor
                BankNotificationProcessor processor = new BankNotificationProcessor(context);
                BankNotificationProcessor.ProcessedNotification result =
                    processor.processNotification(packageName, title, text);

                if (result != null) {
                    // Create a map with the processed data
                    java.util.Map<String, Object> data = new java.util.HashMap<>();
                    data.put("packageName", packageName);
                    data.put("bankName", result.bankName);
                    data.put("amount", result.amount);
                    data.put("accountNumber", result.accountNumber);
                    data.put("senderInfo", result.senderInfo);
                    data.put("rawText", result.rawText);
                    data.put("timestamp", System.currentTimeMillis());

                    // Invoke Flutter method on the UI thread with enhanced data
                    new android.os.Handler(android.os.Looper.getMainLooper()).post(() -> {
                        channel.invokeMethod("onNotificationReceived", data, new MethodChannel.Result() {
                            @Override
                            public void success(Object result) {
                                Log.d(TAG, "Successfully sent bank notification to Flutter");
                            }

                            @Override
                            public void error(String errorCode, String errorMessage, Object errorDetails) {
                                Log.e(TAG, "Error in Flutter while processing notification: " + errorMessage);
                            }

                            @Override
                            public void notImplemented() {
                                Log.e(TAG, "Notification handling not implemented in Flutter");
                            }
                        });
                    });
                } else {
                    Log.d(TAG, "Notification was not a valid bank transaction");
                }
            } catch (Exception e) {
                Log.e(TAG, "Error processing bank notification: " + e.getMessage());
                e.printStackTrace();
            }
        } else {
            Log.e(TAG, "Channel or context is null, cannot process notification");
        }
    }

    private boolean isNotificationListenerEnabled() {
        try {
            String packageName = context.getPackageName();
            String enabledNotificationListeners = Settings.Secure.getString(
                    context.getContentResolver(),
                    "enabled_notification_listeners"
            );
            return enabledNotificationListeners != null && enabledNotificationListeners.contains(packageName);
        } catch (Exception e) {
            Log.e(TAG, "Error checking notification listener status: " + e.getMessage());
            return false;
        }
    }

    private void openNotificationListenerSettings() {
        try {
            Intent intent = new Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS");
            intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            context.startActivity(intent);
        } catch (Exception e) {
            Log.e(TAG, "Error opening notification listener settings: " + e.getMessage());
        }
    }

    private void startNotificationListenerService() {
        try {
            if (isNotificationListenerEnabled()) {
                Intent intent = new Intent(context, BankNotificationListenerService.class);
                intent.putExtra("start_reason", "manual_start");
                context.startService(intent);
                Log.d(TAG, "Notification listener service started");
                
                // Initialize BankNotificationProcessor
                new BankNotificationProcessor(context);
                Log.d(TAG, "Bank notification processor initialized");
            } else {
                Log.w(TAG, "Notification listener permission not granted");
                openNotificationListenerSettings();
            }
        } catch (SecurityException se) {
            Log.e(TAG, "Security exception starting service: " + se.getMessage());
            openNotificationListenerSettings();
        } catch (Exception e) {
            Log.e(TAG, "Error starting notification listener service", e);
            e.printStackTrace();
        }
    }

    private void stopNotificationListenerService() {
        try {
            Intent intent = new Intent(context, BankNotificationListenerService.class);
            context.stopService(intent);
            Log.d(TAG, "Notification listener service stopped");
        } catch (Exception e) {
            Log.e(TAG, "Error stopping notification listener service: " + e.getMessage());
        }
    }
}