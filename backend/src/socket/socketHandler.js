const Room = require("../models/Room");

const socketHandler = (io) => {
  io.on("connection", (socket) => {
    console.log("User Connected:", socket.id);

    socket.on("host-join", async (data) => {
      try {
        const pin = data.pin || data;
        const room = await Room.findOne({ pin });
        if (!room) {
          socket.emit("error-message", "Room not found");
          return;
        }
        socket.join(pin);
        console.log(`Host joined room: ${pin}`);
      } catch (error) {
        console.error("host-join error:", error.message);
      }
    });

    socket.on("join-room", async (data) => {
      try {
        const { pin, nickname } = data;
        if (!pin || !nickname || !nickname.trim()) {
          socket.emit("error-message", "PIN and nickname are required");
          return;
        }
        const room = await Room.findOne({ pin });
        if (!room) {
          socket.emit("error-message", "Room not found");
          return;
        }
        const existingUser = room.participants.find(
          (p) => p.nickname === nickname
        );
        if (existingUser) {
          socket.emit("error-message", "Nickname already taken");
          return;
        }
        room.participants.push({ socketId: socket.id, nickname });
        await room.save();
        socket.join(pin);
        io.to(pin).emit("participants-updated", room.participants);
        socket.emit("joined-successfully", room);
      } catch (error) {
        console.error("join-room error:", error.message);
      }
    });

    socket.on("start-question", async (data) => {
      try {
        const { pin, question } = data;
        if (!pin || !question) return;
        const room = await Room.findOne({ pin });
        if (!room) return;
        room.state = "Question";
        room.currentQuestion = question;
        room.currentQuestionStartTime = Date.now();
        room.participants.forEach((p) => { p.lastAnswer = null; });
        await room.save();
        io.to(pin).emit("question-started", question);
      } catch (error) {
        console.error("start-question error:", error.message);
      }
    });

    socket.on("submit-answer", async (data) => {
      try {
        const { pin, answer } = data;
        const room = await Room.findOne({ pin });
        if (!room) return;
        if (!room.currentQuestion) return;
        // Find participant by socket.id; also accept a nickname fallback sent by client
        const participant = room.participants.find(
          (p) => p.socketId === socket.id
        );
        if (!participant) {
          socket.emit("error-message", "You are not in this room");
          return;
        }
        if (participant.lastAnswer != null) return; // already answered
        const correctAnswer = room.currentQuestion.correctAnswer;
        const isCorrect = answer === correctAnswer;
        let earnedScore = 0;
        participant.lastAnswer = answer;
        if (isCorrect) {
          const timeTaken = Date.now() - room.currentQuestionStartTime;
          const duration = (room.currentQuestion.timer || 10) * 1000;
          earnedScore = Math.max(
            1000 - Math.floor((timeTaken / duration) * 1000),
            100
          );
          participant.score += earnedScore;
        }
        await room.save();
        const leaderboard = [...room.participants].sort(
          (a, b) => b.score - a.score
        );
        socket.emit("answer-result", {
          correct: isCorrect,
          earnedScore,
          totalScore: participant.score,
        });
        io.to(pin).emit("leaderboard", leaderboard);
        const options = room.currentQuestion.options || [];
        const answerCounts = {};
        options.forEach((opt) => { answerCounts[opt] = 0; });
        room.participants.forEach((p) => {
          if (p.lastAnswer && answerCounts[p.lastAnswer] !== undefined) {
            answerCounts[p.lastAnswer]++;
          }
        });
        io.to(pin).emit("answer-aggregate", answerCounts);
      } catch (error) {
        console.error("submit-answer error:", error.message);
      }
    });

    socket.on("change-state", async (data) => {
      try {
        const { pin, state } = data;
        const validStates = ['Lobby', 'Starting', 'Question', 'Leaderboard', 'Q&A', 'Finished'];
        if (!validStates.includes(state)) {
          socket.emit("error-message", `Invalid state: ${state}`);
          return;
        }
        const room = await Room.findOne({ pin });
        if (!room) return;
        room.state = state;
        await room.save();
        io.to(pin).emit("state-changed", state);
      } catch (error) {
        console.error("change-state error:", error.message);
      }
    });

    socket.on("kick-user", async (data) => {
      try {
        const { pin, nickname } = data;
        const room = await Room.findOne({ pin });
        if (!room) return;
        const kicked = room.participants.find((p) => p.nickname === nickname);
        room.participants = room.participants.filter(
          (p) => p.nickname !== nickname
        );
        await room.save();
        io.to(pin).emit("participants-updated", room.participants);
        if (kicked) {
          io.to(kicked.socketId).emit("kicked");
        }
      } catch (error) {
        console.error("kick-user error:", error.message);
      }
    });

    socket.on("reset-scores", async (data) => {
      try {
        const pin = data.pin || data;
        const room = await Room.findOne({ pin });
        if (!room) return;
        room.participants.forEach((p) => {
          p.score = 0;
          p.lastAnswer = null;
        });
        room.currentQuestion = null;
        room.currentQuestionStartTime = null;
        await room.save();
        io.to(pin).emit("participants-updated", room.participants);
      } catch (error) {
        console.error("reset-scores error:", error.message);
      }
    });

    socket.on("next-slide", async (data) => {
      try {
        const pin = data.pin || data;
        // Broadcast only to other sockets in the room (not back to the host)
        socket.to(pin).emit("slide-advanced");
      } catch (error) {
        console.error("next-slide error:", error.message);
      }
    });

    socket.on("submit-qa", async (data) => {
      try {
        const { pin, nickname, text } = data;
        if (!pin || !text || !text.trim()) return;
        const qaQuestion = {
          id: `${socket.id}-${Date.now()}`,
          nickname: nickname || "Anonymous",
          text: text.trim(),
          spotlighted: false,
        };
        io.to(pin).emit("qa-question-received", qaQuestion);
      } catch (error) {
        console.error("submit-qa error:", error.message);
      }
    });

    socket.on("spotlight-qa", async (data) => {
      try {
        const { pin, questionId } = data;
        io.to(pin).emit("qa-spotlighted", { questionId });
      } catch (error) {
        console.error("spotlight-qa error:", error.message);
      }
    });

    socket.on("dismiss-qa", async (data) => {
      try {
        const { pin, questionId } = data;
        io.to(pin).emit("qa-dismissed", { questionId });
      } catch (error) {
        console.error("dismiss-qa error:", error.message);
      }
    });

    socket.on("disconnect", async () => {
      try {
        console.log("User Disconnected:", socket.id);
        const room = await Room.findOne({
          "participants.socketId": socket.id,
        });
        if (!room) return;
        const wasParticipant = room.participants.some(
          (p) => p.socketId === socket.id
        );
        if (!wasParticipant) return;
        room.participants = room.participants.filter(
          (p) => p.socketId !== socket.id
        );
        await room.save();
        io.to(room.pin).emit("participants-updated", room.participants);
      } catch (error) {
        console.error("disconnect error:", error.message);
      }
    });
  });
};

module.exports = socketHandler;
