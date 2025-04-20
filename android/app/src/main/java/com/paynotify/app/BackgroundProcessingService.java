package com.paynotify.app;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Intent;
import android.os.Build;
import android.os.IBinder;
import androidx.core.app.NotificationCompat;
import android.util.Log;

public class BackgroundProcessingService extends Service {
    private static final String TAG = "BackgroundService";
    private static final String CHANNEL_ID = "PayNotifyServiceChannel";
    private static final int FOREGROUND_ID = 1;
    private static BackgroundProcessingService instance;

    private BankNotificationProcessor processor;
    private boolean isRunning = false;

    public static BackgroundProcessingService getInstance() {
        return instance;
    }

    @Override
    public void onCreate() {
        super.onCreate();
        instance = this;
        processor = new BankNotificationProcessor(this);
        createNotificationChannel();
        startForeground(FOREGROUND_ID, createForegroundNotification());
        isRunning = true;
        Log.i(TAG, "Background service created");
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        Log.i(TAG, "Background service started");
        return START_STICKY;
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel serviceChannel = new NotificationChannel(
                CHANNEL_ID,
                "PayNotify Background Service",
                NotificationManager.IMPORTANCE_LOW
            );
            serviceChannel.setShowBadge(false);
            
            NotificationManager manager = getSystemService(NotificationManager.class);
            manager.createNotificationChannel(serviceChannel);
        }
    }

    private Notification createForegroundNotification() {
        Intent notificationIntent = new Intent(this, MainActivity.class);
        PendingIntent pendingIntent = PendingIntent.getActivity(
            this, 0, notificationIntent,
            PendingIntent.FLAG_IMMUTABLE
        );

        return new NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("PayNotify กำลังทำงาน")
            .setContentText("กำลังตรวจสอบการแจ้งเตือนจากธนาคาร")
            .setSmallIcon(R.drawable.notification_icon)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build();
    }

    public void processNotification(Notification notification, String packageName) {
        if (!isRunning) return;
        processor.processNotification(notification, packageName);
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        isRunning = false;
        instance = null;
        Log.i(TAG, "Background service destroyed");
    }

    public boolean isServiceRunning() {
        return isRunning;
    }

    public void refreshForegroundNotification() {
        if (isRunning) {
            NotificationManager manager = getSystemService(NotificationManager.class);
            manager.notify(FOREGROUND_ID, createForegroundNotification());
        }
    }
}