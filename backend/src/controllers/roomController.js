const Room = require('../models/Room');
const generatePin = require('../utils/generatePin');

const createRoom = async (req, res) => {
    try {
        const { name } = req.body;

        if (!name || !name.trim()) {
            return res.status(400).json({ message: 'Room name is required' });
        }

        let room;
        let attempts = 0;
        while (attempts < 5) {
            const pin = generatePin();
            const exists = await Room.findOne({ pin });
            if (!exists) {
                room = await Room.create({ name: name.trim(), pin });
                break;
            }
            attempts++;
        }

        if (!room) {
            return res.status(500).json({ message: 'Could not generate unique PIN, try again' });
        }

        res.status(201).json({ success: true, room });
    } catch (error) {
        res.status(500).json({ message: error.message });
    }
};

const joinRoom = async (req, res) => {
    try {
        const { pin } = req.body;

        if (!pin) {
            return res.status(400).json({ message: 'PIN is required' });
        }

        const room = await Room.findOne({ pin });

        if (!room) {
            return res.status(404).json({ message: 'Room not found' });
        }

        res.status(200).json({ success: true, room });
    } catch (error) {
        res.status(500).json({ message: error.message });
    }
};

module.exports = { createRoom, joinRoom };
