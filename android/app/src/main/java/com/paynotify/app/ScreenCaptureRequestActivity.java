package com.paynotify.app;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.media.projection.MediaProjectionManager;
import android.os.Bundle;
import android.util.Log;

public class ScreenCaptureRequestActivity extends Activity {
    private static final String TAG = "ScreenCaptureRequest";
    private static final int REQUEST_MEDIA_PROJECTION = 1;
    private MediaProjectionManager projectionManager;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        
        projectionManager = (MediaProjectionManager) getSystemService(Context.MEDIA_PROJECTION_SERVICE);
        startScreenCapture();
    }

    private void startScreenCapture() {
        try {
            Intent captureIntent = projectionManager.createScreenCaptureIntent();
            startActivityForResult(captureIntent, REQUEST_MEDIA_PROJECTION);
        } catch (Exception e) {
            Log.e(TAG, "Failed to start screen capture: " + e.getMessage());
            finish();
        }
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        if (requestCode == REQUEST_MEDIA_PROJECTION) {
            if (resultCode == RESULT_OK) {
                // Grant permission to service
                ScreenCaptureService service = ScreenCaptureService.getInstance();
                if (service != null) {
                    service.onScreenCapturePermissionGranted(
                        projectionManager.getMediaProjection(resultCode, data)
                    );
                }
            } else {
                Log.w(TAG, "Screen capture permission denied");
            }
        }
        finish();
    }
}