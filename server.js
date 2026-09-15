import express from "express";
import fetch from "node-fetch";
import qs from "querystring";
import path from "path";
import fs from "fs";
import { fileURLToPath } from "url";
import https from 'https';
import http from 'http';
import speakeasy from 'speakeasy';

const app = express();
const CONFIG_FILE_NAME = "pgclock.config";
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const loadConfig = () => {
    const configFile = path.join(__dirname, CONFIG_FILE_NAME);
    if (!fs.existsSync(configFile)) {
        console.error("Error: Configuration file 'pgclock.config' not found!");
        process.exit(1);
    }
    return fs.readFileSync(configFile, "utf-8")
        .split("\n")
        .reduce((acc, line) => {
            line = line.trim();
            if (!line || line.startsWith("#")) return acc;
            const [key, ...valueParts] = line.split("=");
            if (key && valueParts.length > 0) acc[key.trim()] = valueParts.join("=").trim();
            return acc;
        }, {});
};

const config = loadConfig();
const {
    HOST: dvhost_host = 'localhost', PORT: dvhost_port = '2053', PATH: dvhost_path = '',
    USERNAME = 'admin', PASSWORD = 'admin', PROTOCOL = 'https', SUBSCRIPTION = '',
    PUBLIC_KEY_PATH = '', PRIVATE_KEY_PATH = '', TEMPLATE_NAME = 'default',
    SUB_HTTP_PORT = '2082', SUB_HTTPS_PORT = '2083', TELEGRAM_URL = '',
    WHATSAPP_URL = '', Backup_link: BACKUP_LINK = '', TOTP_SECRET = '', 
    TWO_FACTOR = 'false', BRAND_NAME = 'PGClock Fusion X-UI', BRAND_LOGO = ''
} = config;

const fetchWithRetry = async (url, options, retries = 3) => {
    try {
        const response = await fetch(url, options);
        if (!response.ok) throw new Error(`Request failed with status ${response.status}`);
        return response;
    } catch (error) {
        if (retries <= 0) throw error;
        return fetchWithRetry(url, options, retries - 1);
    }
};

const fetchUrlContent = async (url) => {
    const isHttps = url.startsWith('https://');
    const agent = isHttps ? new https.Agent({ rejectUnauthorized: false }) : new http.Agent();
    const response = await fetch(url, { agent });
    if (!response.ok) throw new Error(`Failed to fetch URL: ${url}`);
    return await response.text();
};

app.use(express.static(path.join(__dirname, "public")));
app.set("views", path.join(__dirname, `views/templates/${TEMPLATE_NAME}`));
app.set("view engine", "ejs");

const subPath = SUBSCRIPTION.split('/').filter(Boolean).pop() || "sub";

app.get(`/${subPath}/:subId`, async (req, res) => {
    try {
        const { subId: targetSubId } = req.params;
        const userAgent = req.headers['user-agent'] || '';
        const isBrowser = /Mozilla|Chrome|Safari|Edge|Opera|Firefox|Trident|WebKit/i.test(userAgent);
        const suburl_content = await fetchUrlContent(`${SUBSCRIPTION}${targetSubId}`);

        if (!isBrowser) {
            const combinedContent = [BACKUP_LINK, Buffer.from(suburl_content, 'base64').toString('utf-8')].filter(Boolean).join('\n');
            return res.send(Buffer.from(combinedContent, 'utf-8').toString('base64'));
        }

        let loginPayload = { username: USERNAME, password: PASSWORD };
        if (TWO_FACTOR === 'true' && TOTP_SECRET) {
            loginPayload.twoFactorCode = speakeasy.totp({ secret: TOTP_SECRET, encoding: 'base32', window: 1 });
        }

        const loginResponse = await fetchWithRetry(`${PROTOCOL}://${dvhost_host}:${dvhost_port}/${dvhost_path}/login`, {
            method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded" }, body: qs.stringify(loginPayload),
        });
        if (!loginResponse.ok) throw new Error("Login failed");
        const cookie = loginResponse.headers.get("set-cookie");

        const listResponse = await fetchWithRetry(`${PROTOCOL}://${dvhost_host}:${dvhost_port}/${dvhost_path}/panel/api/inbounds/list`, { method: "GET", headers: { cookie } });
        const listResult = await listResponse.json();
        const foundClient = listResult.obj.flatMap(inbound => JSON.parse(inbound.settings).clients).find(client => client.subId === targetSubId);
        if (!foundClient) return res.status(404).send("User not found");

        const trafficResponse = await fetchWithRetry(`${PROTOCOL}://${dvhost_host}:${dvhost_port}/${dvhost_path}/panel/api/inbounds/getClientTraffics/${foundClient.email}`, { method: "GET", headers: { cookie } });
        const trafficData = await trafficResponse.json();
        if (!trafficData.obj) return res.status(404).send("Traffic data not found");

        const user = {
            email: trafficData.obj.email, 
            expire: trafficData.obj.expiryTime,
            used_traffic: trafficData.obj.up + trafficData.obj.down, 
            total_traffic: trafficData.obj.total,
            status: trafficData.obj.enable ? "active" : "disabled", 
            subId: targetSubId, 
            support_url: TELEGRAM_URL
        };

        const links = Buffer.from(suburl_content, 'base64').toString('utf-8').split('\n').filter(l => l.trim() !== '');
        if (BACKUP_LINK) links.unshift(BACKUP_LINK);

        res.render("sub", { 
            data: { 
                user, 
                links, 
                apps: [], 
                suburl: `${req.protocol}://${req.get('host')}${req.originalUrl}`, 
                brandName: BRAND_NAME, 
                brandLogo: BRAND_LOGO 
            } 
        });
    } catch (error) {
        console.error("Error:", error.message);
        res.status(500).send("Internal Server Error: " + error.message);
    }
});

const startServers = () => {
    http.createServer(app).listen(SUB_HTTP_PORT, () => console.log(`HTTP Server on ${SUB_HTTP_PORT}`));
    if (PUBLIC_KEY_PATH && PRIVATE_KEY_PATH && fs.existsSync(PUBLIC_KEY_PATH) && fs.existsSync(PRIVATE_KEY_PATH)) {
        https.createServer({ key: fs.readFileSync(PRIVATE_KEY_PATH), cert: fs.readFileSync(PUBLIC_KEY_PATH) }, app).listen(SUB_HTTPS_PORT, () => console.log(`HTTPS Server on ${SUB_HTTPS_PORT}`));
    }
};
startServers();
