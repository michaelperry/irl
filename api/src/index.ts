import { Hono } from "hono";
import { cors } from "hono/cors";
import { logger } from "hono/logger";
import auth from "./routes/auth.js";
import posts from "./routes/posts.js";
import profile from "./routes/profile.js";
import screentime from "./routes/screentime.js";
import reactions from "./routes/reactions.js";
import comments from "./routes/comments.js";
import safety from "./routes/safety.js";
import invites from "./routes/invites.js";
import activity from "./routes/activity.js";

import type { AppVariables } from "./types.js";

const app = new Hono<{ Variables: AppVariables }>().basePath("/api");

// Middleware
app.use("*", logger());
app.use("*", cors());

// Health check
app.get("/health", (c) => {
  return c.json({ status: "ok", app: "irl", version: "0.1.0" });
});

// Routes
app.route("/auth", auth);
app.route("/posts", posts);
app.route("/profile", profile);
app.route("/screen-time", screentime);
app.route("/reactions", reactions);
app.route("/comments", comments);
app.route("/safety", safety);
app.route("/invites", invites);
app.route("/activity", activity);

export default app;
