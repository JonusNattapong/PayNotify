-- PayNotify Database Schema for Supabase PostgreSQL

-- Enable Row Level Security (RLS)
ALTER DATABASE postgres SET timezone TO 'Asia/Bangkok';

-- USERS TABLE
-- This table is managed by Supabase Auth, not needed to create manually

-- TRANSACTIONS TABLE
-- Stores all payment transaction data
CREATE TABLE IF NOT EXISTS public.transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    amount DECIMAL(15, 2) NOT NULL,
    bank_name VARCHAR(255) NOT NULL,
    account_number VARCHAR(255),
    sender_info TEXT,
    description TEXT,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT now(),
    is_verified BOOLEAN DEFAULT FALSE,
    raw_notification_text TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Add index for faster querying by user
CREATE INDEX IF NOT EXISTS idx_transactions_user_id ON public.transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_transactions_timestamp ON public.transactions(timestamp);

-- DEVICE TOKENS TABLE
-- Stores device tokens for push notifications
CREATE TABLE IF NOT EXISTS public.device_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    device_token TEXT NOT NULL,
    platform VARCHAR(50) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    last_used_at TIMESTAMP WITH TIME ZONE,
    is_active BOOLEAN DEFAULT TRUE
);

-- Add unique constraint for device tokens
CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_device_token ON public.device_tokens(user_id, device_token);

-- USER_INTEGRATIONS TABLE
-- Stores user integration configurations like LINE Notify
CREATE TABLE IF NOT EXISTS public.user_integrations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    integration_type VARCHAR(50) NOT NULL,
    config JSONB NOT NULL DEFAULT '{}'::jsonb,
    is_enabled BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Add unique constraint for integration types
CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_integration ON public.user_integrations(user_id, integration_type);

-- USER_SETTINGS TABLE
-- Stores user preferences and settings
CREATE TABLE IF NOT EXISTS public.user_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    notification_settings JSONB NOT NULL DEFAULT '{
        "sound_enabled": true,
        "sound_volume": 0.5,
        "sound_file": "cash_register.mp3",
        "vibration_enabled": true
    }'::jsonb,
    bank_settings JSONB NOT NULL DEFAULT '{
        "banks": []
    }'::jsonb,
    app_settings JSONB NOT NULL DEFAULT '{
        "theme": "system",
        "language": "th"
    }'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Add unique constraint for user settings
CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_user_settings ON public.user_settings(user_id);

-- Set up Row Level Security (RLS) policies
-- Transactions table policies
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY transactions_select ON public.transactions 
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY transactions_insert ON public.transactions 
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY transactions_update ON public.transactions 
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY transactions_delete ON public.transactions 
    FOR DELETE USING (auth.uid() = user_id);

-- Device tokens policies
ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY device_tokens_select ON public.device_tokens 
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY device_tokens_insert ON public.device_tokens 
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY device_tokens_update ON public.device_tokens 
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY device_tokens_delete ON public.device_tokens 
    FOR DELETE USING (auth.uid() = user_id);

-- User integrations policies
ALTER TABLE public.user_integrations ENABLE ROW LEVEL SECURITY;

CREATE POLICY user_integrations_select ON public.user_integrations 
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY user_integrations_insert ON public.user_integrations 
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY user_integrations_update ON public.user_integrations 
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY user_integrations_delete ON public.user_integrations 
    FOR DELETE USING (auth.uid() = user_id);

-- User settings policies
ALTER TABLE public.user_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY user_settings_select ON public.user_settings 
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY user_settings_insert ON public.user_settings 
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY user_settings_update ON public.user_settings 
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY user_settings_delete ON public.user_settings 
    FOR DELETE USING (auth.uid() = user_id);

-- Create function to update timestamps
CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers for updated_at timestamps
CREATE TRIGGER transactions_updated_at
  BEFORE UPDATE ON public.transactions
  FOR EACH ROW
  EXECUTE PROCEDURE update_timestamp();

CREATE TRIGGER user_integrations_updated_at
  BEFORE UPDATE ON public.user_integrations
  FOR EACH ROW
  EXECUTE PROCEDURE update_timestamp();

CREATE TRIGGER user_settings_updated_at
  BEFORE UPDATE ON public.user_settings
  FOR EACH ROW
  EXECUTE PROCEDURE update_timestamp();

-- Create function to notify client of changes
CREATE OR REPLACE FUNCTION notify_transaction_changes()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM pg_notify(
    'transaction_changes',
    json_build_object(
      'type', TG_OP,
      'record', row_to_json(NEW),
      'user_id', NEW.user_id
    )::text
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for transaction changes
CREATE TRIGGER after_transaction_change
  AFTER INSERT OR UPDATE ON public.transactions
  FOR EACH ROW
  EXECUTE PROCEDURE notify_transaction_changes();