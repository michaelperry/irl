import type { schema } from "./db/index.js";

export type User = typeof schema.users.$inferSelect;

export type AppVariables = {
  userId: string;
  user: User;
  screenTimeRemaining: number;
};
