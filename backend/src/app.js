const express = require("express");
const cors = require("cors");
const roomRoutes = require("./routes/roomRoutes");

const app = express();

app.use(cors());

app.use(express.json());

app.use("/api/rooms",roomRoutes);

app.get("/",(req,res) => {
    res.send("Server Running");
});

module.exports = app;

