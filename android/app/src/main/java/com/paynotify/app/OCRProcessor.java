package com.paynotify.app;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.net.Uri;
import android.util.Log;
import androidx.annotation.NonNull;

import com.google.mlkit.vision.common.InputImage;
import com.google.mlkit.vision.text.Text;
import com.google.mlkit.vision.text.TextRecognition;
import com.google.mlkit.vision.text.TextRecognizer;
import com.google.mlkit.vision.text.latin.TextRecognizerOptions;

import java.io.IOException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CompletableFuture;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public class OCRProcessor {
    private static final String TAG = "OCRProcessor";
    private final Context context;
    private final TextRecognizer recognizer;
    private final BankNotificationProcessor bankProcessor;

    // Bank logo detection coordinates (normalized)
    private static final Map<String, float[]> BANK_LOGO_REGIONS = new HashMap<String, float[]>() {{
        put("SCB", new float[]{0.05f, 0.05f, 0.25f, 0.15f});  // x1, y1, x2, y2
        put("KBANK", new float[]{0.05f, 0.05f, 0.25f, 0.15f});
        put("KTB", new float[]{0.05f, 0.05f, 0.25f, 0.15f});
        put("BBL", new float[]{0.05f, 0.05f, 0.25f, 0.15f});
        // Add more bank logo regions
    }};

    public OCRProcessor(Context context) {
        this.context = context;
        this.recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS);
        this.bankProcessor = new BankNotificationProcessor(context);
    }

    public CompletableFuture<Map<String, Object>> processTransferImage(String imagePath) {
        CompletableFuture<Map<String, Object>> future = new CompletableFuture<>();

        try {
            // Load and prepare the image
            Bitmap bitmap = loadAndPreprocessImage(imagePath);
            if (bitmap == null) {
                future.completeExceptionally(new Exception("Failed to load image"));
                return future;
            }

            InputImage image = InputImage.fromBitmap(bitmap, 0);

            // Process the image with ML Kit
            recognizer.process(image)
                    .addOnSuccessListener(visionText -> {
                        try {
                            Map<String, Object> result = extractTransferInfo(visionText);
                            future.complete(result);
                        } catch (Exception e) {
                            Log.e(TAG, "Error processing OCR result: " + e.getMessage());
                            future.completeExceptionally(e);
                        }
                    })
                    .addOnFailureListener(e -> {
                        Log.e(TAG, "OCR failed: " + e.getMessage());
                        future.completeExceptionally(e);
                    });

        } catch (Exception e) {
            Log.e(TAG, "Error in processTransferImage: " + e.getMessage());
            future.completeExceptionally(e);
        }

        return future;
    }

    private Bitmap loadAndPreprocessImage(String imagePath) {
        try {
            // Load the image
            BitmapFactory.Options options = new BitmapFactory.Options();
            options.inPreferredConfig = Bitmap.Config.ARGB_8888;
            return BitmapFactory.decodeFile(imagePath, options);
        } catch (Exception e) {
            Log.e(TAG, "Error loading image: " + e.getMessage());
            return null;
        }
    }

    @NonNull
    private Map<String, Object> extractTransferInfo(Text visionText) {
        Map<String, Object> result = new HashMap<>();
        String fullText = visionText.getText();
        
        // Try to identify bank from logo region first
        String detectedBank = detectBankFromRegions(visionText);
        if (detectedBank == null) {
            // Fallback to text-based bank detection
            detectedBank = detectBankFromText(fullText);
        }
        result.put("bankName", detectedBank != null ? detectedBank : "Unknown");

        // Extract amount
        Pattern amountPattern = Pattern.compile(
            "(?:THB|฿|บาท)\\s*([0-9,]+\\.?\\d*)|([0-9,]+\\.?\\d*)\\s*(?:THB|฿|บาท)"
        );
        Matcher amountMatcher = amountPattern.matcher(fullText);
        if (amountMatcher.find()) {
            String amountStr = amountMatcher.group(1) != null ? 
                             amountMatcher.group(1) : amountMatcher.group(2);
            amountStr = amountStr.replaceAll(",", "");
            result.put("amount", Double.parseDouble(amountStr));
        }

        // Extract account number
        Pattern accountPattern = Pattern.compile(
            "(?:a/c|account|บัญชี)[^\\d]*(\\d{3}[-\\s]?\\d+[-\\s]?\\d+)"
        );
        Matcher accountMatcher = accountPattern.matcher(fullText);
        if (accountMatcher.find()) {
            result.put("accountNumber", accountMatcher.group(1));
        }

        // Extract sender info
        Pattern senderPattern = Pattern.compile(
            "(?:จาก|from|โดย|By)[^\\d\\n]*([\\wก-๙\\s'\".]+?)(?:\\s|$)"
        );
        Matcher senderMatcher = senderPattern.matcher(fullText);
        if (senderMatcher.find()) {
            result.put("senderInfo", senderMatcher.group(1).trim());
        }

        // Store raw text for reference
        result.put("rawText", fullText);

        return result;
    }

    private String detectBankFromRegions(Text visionText) {
        int imageWidth = visionText.getTextBlocks().get(0).getBoundingBox().width();
        int imageHeight = visionText.getTextBlocks().get(0).getBoundingBox().height();

        for (Map.Entry<String, float[]> entry : BANK_LOGO_REGIONS.entrySet()) {
            String bank = entry.getKey();
            float[] region = entry.getValue();

            // Convert normalized coordinates to actual pixels
            int x1 = (int) (region[0] * imageWidth);
            int y1 = (int) (region[1] * imageHeight);
            int x2 = (int) (region[2] * imageWidth);
            int y2 = (int) (region[3] * imageHeight);

            // Check if any text blocks fall within this region
            for (Text.TextBlock block : visionText.getTextBlocks()) {
                if (block.getBoundingBox() != null &&
                    isWithinRegion(block.getBoundingBox().left, block.getBoundingBox().top,
                                 x1, y1, x2, y2)) {
                    String text = block.getText().toLowerCase();
                    if (text.contains(bank.toLowerCase())) {
                        return bank;
                    }
                }
            }
        }
        return null;
    }

    private String detectBankFromText(String text) {
        text = text.toLowerCase();
        if (text.contains("scb") || text.contains("ไทยพาณิชย์")) return "SCB";
        if (text.contains("kbank") || text.contains("กสิกร")) return "KBANK";
        if (text.contains("ktb") || text.contains("กรุงไทย")) return "KTB";
        if (text.contains("bbl") || text.contains("กรุงเทพ")) return "BBL";
        if (text.contains("ttb") || text.contains("ทหารไทย") || text.contains("ธนชาต")) return "TTB";
        if (text.contains("bay") || text.contains("กรุงศรี")) return "BAY";
        if (text.contains("gsb") || text.contains("ออมสิน")) return "GSB";
        return null;
    }

    private boolean isWithinRegion(int x, int y, int x1, int y1, int x2, int y2) {
        return x >= x1 && x <= x2 && y >= y1 && y <= y2;
    }

    public void cleanup() {
        recognizer.close();
    }
}