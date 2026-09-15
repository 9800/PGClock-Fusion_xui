// در ابتدای server.js، این تغییرات را اعمال کنید:

const config = loadConfig();
const {
    HOST: dvhost_host = 'localhost', PORT: dvhost_port = '2053', PATH: dvhost_path = '',
    USERNAME = 'admin',
    // حذف PASSWORD از config
    // PASSWORD = 'admin',
    PROTOCOL = 'https', SUBSCRIPTION = '',
    PUBLIC_KEY_PATH = '', PRIVATE_KEY_PATH = '', TEMPLATE_NAME = 'default',
    SUB_HTTP_PORT = '2082', SUB_HTTPS_PORT = '2083', TELEGRAM_URL = '',
    WHATSAPP_URL = '', Backup_link: BACKUP_LINK = '', TOTP_SECRET = '', 
    TWO_FACTOR = 'false', BRAND_NAME = 'PGClock Fusion X-UI', BRAND_LOGO = ''
} = config;

// خواندن پسورد از environment variable (از systemd)
const PASSWORD = process.env.PANEL_PASSWORD || '';

if (!PASSWORD) {
    console.error("Error: PANEL_PASSWORD environment variable not set!");
    console.error("Please check the .env.credentials file exists and systemd service is configured correctly.");
    process.exit(1);
}
