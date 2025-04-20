package com.paynotify.app;

import android.accessibilityservice.AccessibilityService;
import android.accessibilityservice.AccessibilityServiceInfo;
import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.PixelFormat;
import android.hardware.display.DisplayManager;
import android.hardware.display.VirtualDisplay;
import android.media.ImageReader;
import android.media.projection.MediaProjection;
import android.media.projection.MediaProjectionManager;
import android.util.DisplayMetrics;
import android.util.Log;
import android.view.accessibility.AccessibilityEvent;
import android.view.WindowManager;

import java.nio.ByteBuffer;

public class ScreenCaptureService extends AccessibilityService {
    private static final String TAG = "ScreenCaptureService";
    private MediaProjection mediaProjection;
    private VirtualDisplay virtualDisplay;
    private ImageReader imageReader;
    private OCRProcessor ocrProcessor;
    private boolean isCapturing = false;
    private static final String[] TARGET_PACKAGES = {
        "com.scb.phone",
        "com.kasikorn.retail.mbanking",
        "com.ktb.netbank",
        "com.bbl.mobilebanking",
        // Add more banking apps
    };

    @Override
    protected void onServiceConnected() {
        super.onServiceConnected();
        
        AccessibilityServiceInfo info = new AccessibilityServiceInfo();
        info.eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED | 
                         AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED;
        info.feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC;
        info.notificationTimeout = 100;
        info.packageNames = TARGET_PACKAGES;
        
        this.setServiceInfo(info);
        ocrProcessor = new OCRProcessor(this);
        
        Log.i(TAG, "ScreenCaptureService connected");
    }

    @Override
    public void onAccessibilityEvent(AccessibilityEvent event) {
        if (!isCapturing && isBankingApp(event.getPackageName().toString())) {
            startScreenCapture();
        }
    }

    private boolean isBankingApp(String packageName) {
        for (String targetPackage : TARGET_PACKAGES) {
            if (targetPackage.equals(packageName)) {
                return true;
            }
        }
        return false;
    }

    private void startScreenCapture() {
        if (isCapturing) return;
        
        try {
            DisplayMetrics metrics = getResources().getDisplayMetrics();
            int width = metrics.widthPixels;
            int height = metrics.heightPixels;
            int density = metrics.densityDpi;

            imageReader = ImageReader.newInstance(width, height, PixelFormat.RGBA_8888, 2);
            imageReader.setOnImageAvailableListener(reader -> {
                try (android.media.Image image = reader.acquireLatestImage()) {
                    if (image != null) {
                        processScreenImage(image);
                    }
                } catch (Exception e) {
                    Log.e(TAG, "Error processing screen image: " + e.getMessage());
                }
            }, null);

            MediaProjectionManager projectionManager = 
                (MediaProjectionManager) getSystemService(MEDIA_PROJECTION_SERVICE);
            
            // Request screen capture permission if not granted
            Intent intent = new Intent(this, ScreenCaptureRequestActivity.class);
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            startActivity(intent);
            
            isCapturing = true;

        } catch (Exception e) {
            Log.e(TAG, "Error starting screen capture: " + e.getMessage());
        }
    }

    private void processScreenImage(android.media.Image image) {
        ByteBuffer buffer = image.getPlanes()[0].getBuffer();
        byte[] bytes = new byte[buffer.remaining()];
        buffer.get(bytes);
        
        // Convert to bitmap
        int width = image.getWidth();
        int height = image.getHeight();
        Bitmap bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888);
        bitmap.copyPixelsFromBuffer(ByteBuffer.wrap(bytes));
        
        // Process with OCR
        ocrProcessor.processScreenBitmap(bitmap)
            .thenAccept(result -> {
                if (result != null && result.containsKey("amount")) {
                    // Found transaction data, notify Flutter
                    NotificationListenerPlugin.sendScreenCaptureResult(result);
                }
            })
            .exceptionally(e -> {
                Log.e(TAG, "Error processing OCR: " + e.getMessage());
                return null;
            });
    }

    @Override
    public void onInterrupt() {
        stopScreenCapture();
    }

    private void stopScreenCapture() {
        isCapturing = false;
        if (virtualDisplay != null) {
            virtualDisplay.release();
            virtualDisplay = null;
        }
        if (mediaProjection != null) {
            mediaProjection.stop();
            mediaProjection = null;
        }
        if (imageReader != null) {
            imageReader.close();
            imageReader = null;
        }
    }

    public void onScreenCapturePermissionGranted(MediaProjection projection) {
        mediaProjection = projection;
        setupVirtualDisplay();
    }

    private void setupVirtualDisplay() {
        DisplayMetrics metrics = getResources().getDisplayMetrics();
        virtualDisplay = mediaProjection.createVirtualDisplay(
            "ScreenCapture",
            metrics.widthPixels,
            metrics.heightPixels,
            metrics.densityDpi,
            DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
            imageReader.getSurface(),
            null,
            null
        );
    }
}