package com.paynotify.app;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.content.Context;
import android.graphics.Color;
import android.os.Build;
import android.util.Log;
import androidx.core.app.NotificationCompat;
import java.util.HashMap;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public class BankNotificationProcessor {
    private static final String TAG = "BankNotificationProcessor";
    
    // Enhanced bank-specific patterns
    private static final Map<String, BankPattern> BANK_PATTERNS = new HashMap<String, BankPattern>() {{
        put("com.scb.phone", new BankPattern(
            "SCB",
            Pattern.compile("(?:transferred|โอนเงิน|รับเงิน|เงินเข้า|ได้รับเงิน|รายการโอน).*?(\\d[\\d,\\.]+)(?:\\s*บาท|\\s*THB|\\s*฿)?"),
            Pattern.compile("(?:a/c|account|บัญชี)[^\\d]*(\\d{3}[-\\s]?\\d+[-\\s]?\\d+)"),
            Pattern.compile("(?:จาก|from|โดย|By)[^\\d\\n]*(.[^\\d\\n]{2,}?)(?:\\s|$)")
        ));
        put("com.kasikorn.retail.mbanking", new BankPattern(
            "KBANK",
            Pattern.compile("(?:transferred|โอนเงิน|รับเงิน|เงินเข้า|ได้รับเงิน|รายการโอน).*?(\\d[\\d,\\.]+)(?:\\s*บาท|\\s*THB|\\s*฿)?"),
            Pattern.compile("(?:a/c|account|บัญชี)[^\\d]*(\\d{3}[-\\s]?\\d+[-\\s]?\\d+)"),
            Pattern.compile("(?:จาก|from|โดย|By)[^\\d\\n]*(.[^\\d\\n]{2,}?)(?:\\s|$)")
        ));
        // Add more bank-specific patterns
    }};
    
    // Notification channels
    private static final String CHANNEL_TRANSACTIONS = "transactions";
    private static final String CHANNEL_ALERTS = "alerts";
    
    private final Context context;
    private NotificationManager notificationManager;
    
    public BankNotificationProcessor(Context context) {
        this.context = context;
        createNotificationChannels();
    }
    
    private void createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            notificationManager = context.getSystemService(NotificationManager.class);
            
            // Transaction channel
            NotificationChannel transactionChannel = new NotificationChannel(
                CHANNEL_TRANSACTIONS,
                "Transactions",
                NotificationManager.IMPORTANCE_HIGH
            );
            transactionChannel.setDescription("Bank transaction notifications");
            transactionChannel.enableLights(true);
            transactionChannel.setLightColor(Color.GREEN);
            transactionChannel.enableVibration(true);
            notificationManager.createNotificationChannel(transactionChannel);
            
            // Alert channel
            NotificationChannel alertChannel = new NotificationChannel(
                CHANNEL_ALERTS,
                "Alerts",
                NotificationManager.IMPORTANCE_DEFAULT
            );
            alertChannel.setDescription("General bank alerts");
            notificationManager.createNotificationChannel(alertChannel);
        }
    }
    
    public ProcessedNotification processNotification(String packageName, String title, String content) {
        try {
            BankPattern bankPattern = BANK_PATTERNS.get(packageName);
            if (bankPattern == null) {
                // Try generic patterns
                return processWithGenericPatterns(packageName, title, content);
            }
            
            String combinedText = title + " " + content;
            
            // Extract amount
            Matcher amountMatcher = bankPattern.amountPattern.matcher(combinedText);
            if (!amountMatcher.find()) {
                return null;
            }
            String amount = amountMatcher.group(1).replaceAll(",", "");
            
            // Extract account number
            String accountNumber = "";
            Matcher accountMatcher = bankPattern.accountPattern.matcher(combinedText);
            if (accountMatcher.find()) {
                accountNumber = accountMatcher.group(1);
            }
            
            // Extract sender info
            String senderInfo = "Unknown";
            Matcher senderMatcher = bankPattern.senderPattern.matcher(combinedText);
            if (senderMatcher.find()) {
                senderInfo = senderMatcher.group(1).trim();
            }
            
            // Create notification data
            ProcessedNotification result = new ProcessedNotification();
            result.amount = Double.parseDouble(amount);
            result.bankName = bankPattern.bankName;
            result.accountNumber = accountNumber;
            result.senderInfo = senderInfo;
            result.rawText = combinedText;
            
            // Show rich notification
            showTransactionNotification(result);
            
            return result;
            
        } catch (Exception e) {
            Log.e(TAG, "Error processing notification: " + e.getMessage());
            return null;
        }
    }
    
    private ProcessedNotification processWithGenericPatterns(String packageName, String title, String content) {
        // Generic patterns for any bank notification
        String combinedText = title + " " + content;
        
        // Try to find any bank name
        for (Map.Entry<String, BankPattern> entry : BANK_PATTERNS.entrySet()) {
            if (combinedText.toLowerCase().contains(entry.getValue().bankName.toLowerCase())) {
                return processNotification(entry.getKey(), title, content);
            }
        }
        
        return null;
    }
    
    private void showTransactionNotification(ProcessedNotification data) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationCompat.Builder builder = new NotificationCompat.Builder(context, CHANNEL_TRANSACTIONS)
                .setSmallIcon(R.drawable.notification_icon)
                .setContentTitle("รับเงินเข้าบัญชี " + data.bankName)
                .setContentText(String.format("%.2f บาท จาก %s", data.amount, data.senderInfo))
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setAutoCancel(true);
                
            NotificationCompat.BigTextStyle bigText = new NotificationCompat.BigTextStyle();
            bigText.bigText(String.format("จำนวน %.2f บาท\nจาก %s\nบัญชี %s", 
                data.amount, data.senderInfo, data.accountNumber));
            builder.setStyle(bigText);
            
            notificationManager.notify(data.hashCode(), builder.build());
        }
    }
    
    private static class BankPattern {
        final String bankName;
        final Pattern amountPattern;
        final Pattern accountPattern;
        final Pattern senderPattern;
        
        BankPattern(String bankName, Pattern amountPattern, Pattern accountPattern, Pattern senderPattern) {
            this.bankName = bankName;
            this.amountPattern = amountPattern;
            this.accountPattern = accountPattern;
            this.senderPattern = senderPattern;
        }
    }
    
    public static class ProcessedNotification {
        public double amount;
        public String bankName;
        public String accountNumber;
        public String senderInfo;
        public String rawText;
    }
}