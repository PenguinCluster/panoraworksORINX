# ORINX by PANORAWORKS

ORINX is a next-generation SaaS platform built with Flutter (Web-first) and Supabase for streamlined business operations, content management, and live alerts.

## Tech Stack
- **Frontend**: Flutter Web (Material 3)
- **Backend**: Supabase (Auth, Database, Storage, Edge Functions)
- **Routing**: GoRouter
- **State Management**: Built-in Flutter State Management (with Supabase Streams)

## Setup Instructions

### 1. Flutter Setup
Ensure you have the Flutter SDK installed (Version 3.10.8 or higher recommended).
```bash
flutter doctor
```

### 2. Supabase Configuration
1. Create a new project on [Supabase](https://supabase.com/).
2. Apply the migrations located in `/supabase/migrations` to your database.
3. Configure the following environment variables or update `lib/core/config/supabase_config.dart`:
   - `SUPABASE_URL`: Your project URL.
   - `SUPABASE_ANON_KEY`: Your project's anonymous key.

### 3. OAuth Configuration & Setup
To enable social logins and connected accounts (Facebook, Discord, TikTok), you must configure both the Provider's Developer Console and your Supabase Dashboard.

#### General Supabase Setup
1. Go to **Supabase Dashboard** > **Authentication** > **URL Configuration**.
2. Add your **Site URL**: `http://localhost:3000` (or your production URL).
3. Add **Redirect URLs**:
   - `http://localhost:3000/` (for generic auth redirects)
   - `https://<your-project-ref>.supabase.co/auth/v1/callback` (Required by some providers)

#### A. Discord Integration
1. Go to the [Discord Developer Portal](https://discord.com/developers/applications).
2. Create a New Application -> Go to **OAuth2** tab.
3. Add **Redirects**: `https://<your-project-ref>.supabase.co/auth/v1/callback`.
4. Copy **Client ID** and **Client Secret**.
5. Go to **Supabase Dashboard** > **Authentication** > **Providers** > **Discord**.
6. Enable Discord, paste Client ID/Secret, and Save.
   - **Scopes**: `identify`, `email` (default is usually sufficient).

#### B. Facebook Integration
1. Go to [Meta for Developers](https://developers.facebook.com/).
2. Create an App (Type: **Consumer** or **Business**).
3. Add **Facebook Login** product.
4. In **Facebook Login Settings**, add **Valid OAuth Redirect URIs**:
   - `https://<your-project-ref>.supabase.co/auth/v1/callback`
5. Go to **App Settings** > **Basic** to find **App ID** and **App Secret**.
6. Go to **Supabase Dashboard** > **Authentication** > **Providers** > **Facebook**.
7. Enable Facebook, paste App ID/Secret, and Save.

#### C. TikTok Integration (Custom / Coming Soon)
*Note: Supabase does not support TikTok as a native Auth provider out-of-the-box as of 2024. The current implementation uses a UI placeholder.*
1. Go to [TikTok for Developers](https://developers.tiktok.com/).
2. Create an App for **Login Kit**.
3. Configure Redirect URI: `https://<your-project-ref>.supabase.co/auth/v1/callback`.
4. *Implementation Note*: Future updates will require a custom Edge Function to handle the TikTok OAuth handshake manually if native support is not added.

### 4. Billing Setup (Flutterwave)
To enable the billing and subscription features, you need a Flutterwave account.

1. **Flutterwave Dashboard**:
   - Sign up at [Flutterwave](https://dashboard.flutterwave.com/).
   - Navigate to **Settings** > **API**.
   - Copy your **Client ID** (sometimes referred to as Public Key) and **Client Secret** (Secret Key).
   - Generate a **Secret Hash** for webhooks.

2. **Supabase Secrets**:
   Set the following secrets in your Supabase project (via dashboard or CLI):
   ```bash
   supabase secrets set FLUTTERWAVE_CLIENT_ID=your_public_key_here
   supabase secrets set FLUTTERWAVE_CLIENT_SECRET=your_secret_key_here
   supabase secrets set FLUTTERWAVE_HASH=your_webhook_hash_here
   ```

3. **Webhook Configuration**:
   - In Flutterwave Dashboard > **Settings** > **Webhooks**.
   - Add your function URL: `https://<project-ref>.supabase.co/functions/v1/flutterwave-webhook`.
   - Enable `Charge Completed` events.

### 5. Running the App
```bash
flutter pub get
flutter run -d chrome
```

### 6. Build for Web
```bash
flutter build web --release
```

## Features
- **Public Marketing Site**: Professional landing page with feature highlights.
- **Secure Authentication**: Email/password and OAuth (Facebook, Discord, etc.) support.
- **Content Hub**: Create and schedule posts for multiple platforms.
- **Live Alerts**: Custom alert rules with Discord integration.
- **Keyword Monitoring**: Track mentions and tags across social media.
- **Production-Ready Settings**: Profile management, billing, team settings, and accessibility.

## Security
- **Row Level Security (RLS)**: Users can only access their own data.
- **Secure Tokens**: OAuth tokens are stored server-side and never exposed to the client.
- **Modular Code**: Clean architecture with separated core, features, and shared modules.
