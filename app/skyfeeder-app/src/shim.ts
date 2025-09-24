import "fast-text-encoding";
import { Buffer } from "buffer";
import process from "process/browser";

// eslint-disable-next-line @typescript-eslint/no-explicit-any
if (!(global as any).Buffer) {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  (global as any).Buffer = Buffer;
}
// eslint-disable-next-line @typescript-eslint/no-explicit-any
(global as any).process = process;
