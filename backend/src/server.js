require('dotenv').config();

const http = require('http');
const { Server } = require('socket.io');

const app = require('./app');
const connectDB = require('./config/db');
const socketHandler = require('./socket/socketHandler');

connectDB();

const server = http.createServer(app);

const io = new Server(server, {
    cors: {
        origin: '*',
    },
});

socketHandler(io);

const PORT = process.env.PORT || 8000;

server.listen(PORT, '0.0.0.0', () => {
    console.log(`Server running on port ${PORT}`);
});
