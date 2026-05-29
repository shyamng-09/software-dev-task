const mongoose = require('mongoose');

const participantSchema = new mongoose.Schema({
    socketId:   { type: String, required: true },
    nickname:   { type: String, required: true },
    score:      { type: Number, default: 0 },
    lastAnswer: { type: String, default: null }
}, { _id: false });

const roomSchema = new mongoose.Schema(
    {
        name: { type: String, required: true },
        pin:  { type: String, required: true, unique: true },
        participants: { type: [participantSchema], default: [] },
        state: {
            type: String,
            enum: ['waiting', 'question', 'leaderboard', 'finished', 'starting',
                   'Question', 'Lobby', 'Leaderboard', 'Starting', 'Q&A'],
            default: 'waiting'
        },
        currentQuestion: { type: mongoose.Schema.Types.Mixed, default: null },
        currentQuestionStartTime: { type: Number, default: null }
    },
    { timestamps: true }
);

module.exports = mongoose.model('Room', roomSchema);
