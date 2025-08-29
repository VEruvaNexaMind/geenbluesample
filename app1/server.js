const express = require('express');
const path = require('path');
const os = require('os');
const fs = require('fs');

const app = express();
const PORT = process.env.PORT || 3000;
const VERSION = process.env.VERSION || 'blue';

console.log(`🚀 Starting ${VERSION.toUpperCase()} version of the application`);
console.log(`📦 VERSION environment variable: ${VERSION}`);

// Serve static files
app.use(express.static(path.join(__dirname)));

// Serve the built index.html (copied at build time)
app.get('/', (req, res) => {
    const htmlPath = path.join(__dirname, 'index.html');
    console.log(`📄 Serving index.html for VERSION=${VERSION}`);
    if (fs.existsSync(htmlPath)) {
        res.sendFile(htmlPath);
    } else {
        console.error(`❌ HTML file not found: ${htmlPath}`);
        res.status(404).send(`HTML file not found: index.html`);
    }
});

// Health check endpoint
app.get('/health', (req, res) => {
    res.json({
        status: 'healthy',
        version: VERSION,
        timestamp: new Date().toISOString(),
        hostname: os.hostname(),
        uptime: process.uptime()
    });
});

// Version endpoint
app.get('/version', (req, res) => {
    res.json({
        version: VERSION,
        hostname: os.hostname(),
        timestamp: new Date().toISOString()
    });
});

// Root endpoint
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'index.html'));
});

// Readiness probe
app.get('/ready', (req, res) => {
    res.json({
        status: 'ready',
        version: VERSION,
        timestamp: new Date().toISOString()
    });
});

// Liveness probe
app.get('/live', (req, res) => {
    res.json({
        status: 'alive',
        version: VERSION,
        timestamp: new Date().toISOString()
    });
});

app.listen(PORT, () => {
    console.log(`🚀 Server running on port ${PORT}`);
    console.log(`📦 Version: ${VERSION}`);
    console.log(`🏥 Health check: http://localhost:${PORT}/health`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
    console.log('🛑 SIGTERM received, shutting down gracefully');
    process.exit(0);
});

process.on('SIGINT', () => {
    console.log('🛑 SIGINT received, shutting down gracefully');
    process.exit(0);
});
