package com.paynotify.app;

import android.app.Notification;
import android.content.Intent;
import android.os.Bundle;
import android.os.IBinder;
import android.service.notification.NotificationListenerService;
import android.service.notification.StatusBarNotification;
import android.util.Log;
import androidx.annotation.NonNull;
import androidx.localbroadcastmanager.content.LocalBroadcastManager;
import java.util.Arrays;
import java.util.HashSet;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public class BankNotificationListenerService extends NotificationListenerService {
    private static final String TAG = "PayNotify";
    private static final String ACTION_NOTIFICATION = "com.paynotify.app.NOTIFICATION";
    private static final String NOTIFICATION_CONTENT = "notification_content";
    private static final String NOTIFICATION_PACKAGE = "notification_package";
    private static final String NOTIFICATION_TIMESTAMP = "notification_timestamp";
    private static final String NOTIFICATION_TITLE = "notification_title";
    
    // Enhanced bank app package names for detection
    private static final Set<String> BANK_PACKAGES = new HashSet<>(Arrays.asList(
        "com.scb.phone", // SCB EASY
        "com.scb.retail", // SCB EASY Corporate
        "com.kasikorn.retail.mbanking", // K PLUS
        "com.kasikornbank.kplus.fb", // K PLUS for Facebook
        "com.kasikornbank.kubusiness", // K PLUS Biz
        "com.ktb.consumer", // KTB netbank
        "com.ktb.merchant", // KTB Merchant
        "com.bbl.mobilebanking", // BBL Mobile Banking
        "com.bbl.bblforyou", // BBL for You
        "com.ttb.oneapp", // ttb touch
        "com.tmb.tmbandsest", // TMB ME
        "com.tmb.merchanttouchbiz", // TMB Business Touch
        "com.tmbbank.tmbtouchid", // TMB Touch
        "com.bay.uob", // UOB TMRW
        "com.dbd.android.uob.hk", // UOB Mobile Banking 
        "com.krungsri.mbanking", // Krungsri Mobile App
        "com.krungsri.consumerapp", // Krungsri Online
        "com.krungsri.jad", // Krungsri JAD
        "com.gsb.mobileapp", // GSB MyMo
        "th.co.gsb.mbankingapp", // GSB MBanking
        "com.baac.mobileapp", // BAAC A-Mobile
        "com.baac.baacbanking", // BAAC Banking
        "com.krungthai.kma", // Krungthai NEXT
        "com.line.android", // LINE messenger for LINE Notify
        "com.google.android.apps.messaging", // SMS app for bank SMS notifications
        "com.android.messaging", // Another SMS app
        "com.samsung.android.messaging" // Samsung SMS app
    ));

    // Enhanced payment notification patterns
    private static final Pattern[] MONEY_RECEIVED_PATTERNS = {
        // Thai bank patterns
        Pattern.compile("(?:เงินเข้า|รับโอนเงิน|รับเงิน|ได้รับเงิน|โอนเข้า|โอนเงินเข้า|เติมเงินเข้า|credit|เครดิต).*?(\\d[\\d,\\.]+)(?:\\s*บาท|\\s*THB|\\s*฿)?", Pattern.CASE_INSENSITIVE),
        Pattern.compile("(?:จำนวนเงิน|amount).*?(\\d[\\d,\\.]+)(?:\\s*บาท|\\s*THB|\\s*฿)?", Pattern.CASE_INSENSITIVE),
        Pattern.compile("(?:\\+|\\＋)\\s*(\\d[\\d,\\.]+)(?:\\s*บาท|\\s*THB|\\s*฿)?", Pattern.CASE_INSENSITIVE)
    };

    // Enhanced patterns for specific transactions 
    private static final Pattern ACCOUNT_NUMBER_PATTERN = Pattern.compile("(?:บัญชี|เลขบัญชี|เลขที่บัญชี|account|acc)[\\s.:]*([\\d\\-xX]+)");
    private static final Pattern SENDER_INFO_PATTERN = Pattern.compile("(?:จาก|โอนจาก|from)\\s+([^\\d\\n\\r]+?)(?:\\s|$)");
    private static final Pattern BANK_NAME_PATTERN = Pattern.compile("(?:ธนาคาร|bank)[\\s:]*([^\\d\\n\\r]+?)(?:\\s|$|\\.|,)");

    @Override
    public IBinder onBind(Intent intent) {
        return super.onBind(intent);
    }

    @Override
    public void onNotificationPosted(@NonNull StatusBarNotification sbn) {
        processNotification(sbn);
    }

    @Override
    public void onNotificationRemoved(StatusBarNotification sbn) {
        // Nothing to do here, but could be used to track dismissed notifications
    }

    private BankNotificationProcessor notificationProcessor;
    private int notificationCount = 0;
    private long lastNotificationTime = 0;
    private static final int MAX_NOTIFICATIONS_PER_MINUTE = 10;

    @Override
    public void onCreate() {
        super.onCreate();
        notificationProcessor = new BankNotificationProcessor(this);
        Log.i(TAG, "BankNotificationListenerService created");
    }

    private void processNotification(StatusBarNotification sbn) {
        String packageName = sbn.getPackageName();
        
        // Rate limiting check
        long currentTime = System.currentTimeMillis();
        if (currentTime - lastNotificationTime < 60000) { // Within last minute
            notificationCount++;
            if (notificationCount > MAX_NOTIFICATIONS_PER_MINUTE) {
                Log.w(TAG, "Too many notifications received. Rate limiting activated.");
                return;
            }
        } else {
            notificationCount = 1;
            lastNotificationTime = currentTime;
        }

        // Check if this is from a banking app or messaging app that might contain bank notifications
        if (!BANK_PACKAGES.contains(packageName)) {
            return;
        }

        try {
            Notification notification = sbn.getNotification();
            Bundle extras = notification.extras;
            String title = extras.getString(Notification.EXTRA_TITLE, "");
            CharSequence contentCharSeq = extras.getCharSequence(Notification.EXTRA_TEXT);
            String content = contentCharSeq != null ? contentCharSeq.toString() : "";
            
            // Skip empty notifications
            if (content.isEmpty() && title.isEmpty()) {
                return;
            }

            // Process notification with enhanced processor
            BankNotificationProcessor.ProcessedNotification result =
                notificationProcessor.processNotification(packageName, title, content);

            if (result != null) {
                // Create notification data bundle
                Bundle notificationData = new Bundle();
                notificationData.putString(NOTIFICATION_PACKAGE, packageName);
                notificationData.putString("bankName", result.bankName);
                notificationData.putDouble("amount", result.amount);
                notificationData.putString("accountNumber", result.accountNumber);
                notificationData.putString("senderInfo", result.senderInfo);
                notificationData.putString("rawText", result.rawText);
                notificationData.putLong(NOTIFICATION_TIMESTAMP, sbn.getPostTime());

                // Send to Flutter through method channel
                NotificationListenerPlugin.sendNotificationToFlutter(notificationData);
                
                // Also broadcast locally
                Intent intent = new Intent(ACTION_NOTIFICATION);
                intent.putExtras(notificationData);
                LocalBroadcastManager.getInstance(this).sendBroadcast(intent);
                
                Log.i(TAG, String.format("Processed bank notification: %s - %.2f THB from %s",
                    result.bankName, result.amount, result.senderInfo));
            }

        } catch (Exception e) {
            Log.e(TAG, "Error processing notification", e);
            // Try to recover and continue service
            try {
                notificationProcessor = new BankNotificationProcessor(this);
            } catch (Exception re) {
                Log.e(TAG, "Failed to recover notification processor", re);
            }
        }
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        Log.i(TAG, "BankNotificationListenerService destroyed");
    }
}