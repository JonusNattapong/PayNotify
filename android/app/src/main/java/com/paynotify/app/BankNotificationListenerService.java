package com.paynotify.app;

import android.app.Notification;
import android.content.Intent;
import android.os.Bundle;
import android.os.IBinder;
import android.service.notification.NotificationListenerService;
import android.service.notification.StatusBarNotification;
import android.util.Log;

import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

public class BankNotificationListenerService extends NotificationListenerService {
    private static final String TAG = "BankNotificationListener";
    
    // Set of bank app package names to monitor
    private static final Set<String> BANK_PACKAGES = new HashSet<String>() {{
        // Thai banks
        add("com.scb.phone");               // SCB Easy
        add("com.kasikorn.retail.mbanking.wap");  // K PLUS
        add("com.ktb.netbank");             // Krungthai NEXT
        add("com.bbl.mobilebanking");       // Bangkok Bank Mobile
        add("com.tmb.droid.mybiz");         // ttb touch
        add("th.co.uob.uobmbk");            // UOB TMRW
        add("com.tmbbank.tmb.retail.ios");  // ttb touch iOS
        
        // For testing
        add("com.google.android.gm");       // Gmail (for testing)
        add("com.whatsapp");                // WhatsApp (for testing)
    }};
    
    private static NotificationEventListener mEventListener;
    
    public interface NotificationEventListener {
        void onNotificationReceived(String packageName, String title, String text);
    }
    
    public static void setNotificationEventListener(NotificationEventListener listener) {
        mEventListener = listener;
    }
    
    @Override
    public IBinder onBind(Intent intent) {
        return super.onBind(intent);
    }
    
    @Override
    public void onNotificationPosted(StatusBarNotification sbn) {
        String packageName = sbn.getPackageName();
        
        // Check if notification is from a monitored bank app
        if (BANK_PACKAGES.contains(packageName)) {
            try {
                Notification notification = sbn.getNotification();
                Bundle extras = notification.extras;
                
                String title = extras.getString(Notification.EXTRA_TITLE, "");
                String text = extras.getCharSequence(Notification.EXTRA_TEXT, "").toString();
                
                Log.d(TAG, "Bank notification received: " + packageName);
                Log.d(TAG, "Title: " + title);
                Log.d(TAG, "Text: " + text);
                
                // Send notification data to the Flutter app
                if (mEventListener != null && !title.isEmpty() && !text.isEmpty()) {
                    mEventListener.onNotificationReceived(packageName, title, text);
                }
                
            } catch (Exception e) {
                Log.e(TAG, "Error processing notification: " + e.getMessage());
            }
        }
    }
    
    @Override
    public void onNotificationRemoved(StatusBarNotification sbn) {
        // Not needed for our use case
    }
}