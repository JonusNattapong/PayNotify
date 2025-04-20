package com.paynotify.app;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.provider.Settings;
import android.util.Log;

public class BootReceiver extends BroadcastReceiver {
    private static final String TAG = "BootReceiver";

    @Override
    public void onReceive(Context context, Intent intent) {
        if (intent.getAction() == null) return;
        
        if (intent.getAction().equals(Intent.ACTION_BOOT_COMPLETED) ||
            intent.getAction().equals(Intent.ACTION_QUICKBOOT_POWERON)) {
            
            Log.d(TAG, "Received boot completed broadcast");
            
            // Check if notification listener permission is granted
            if (isNotificationListenerEnabled(context)) {
                try {
                    // Start the notification service
                    Intent serviceIntent = new Intent(context, BankNotificationListenerService.class);
                    serviceIntent.putExtra("start_reason", "boot_completed");
                    
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        context.startForegroundService(serviceIntent);
                    } else {
                        context.startService(serviceIntent);
                    }
                    
                    Log.d(TAG, "Started BankNotificationListenerService after boot");
                } catch (Exception e) {
                    Log.e(TAG, "Error starting service after boot: " + e.getMessage());
                }
            } else {
                Log.w(TAG, "Notification listener permission not granted");
            }
        }
    }
    
    private boolean isNotificationListenerEnabled(Context context) {
        try {
            String enabledListeners = Settings.Secure.getString(
                context.getContentResolver(),
                "enabled_notification_listeners"
            );
            String packageName = context.getPackageName();
            return enabledListeners != null && enabledListeners.contains(packageName);
        } catch (Exception e) {
            Log.e(TAG, "Error checking notification listener status: " + e.getMessage());
            return false;
        }
    }
}