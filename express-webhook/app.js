import express from "express";
import { createHmac, timingSafeEqual } from "crypto";

const port = process.env.PORT || 8000;
const webhookB64Key = process.env.WEBHOOK_B64KEY;
const maxAgeSeconds = process.env.MAX_REQUEST_AGE_SECONDS || 300;

const verifyWebhookSignature = function (signatures, timestamp, payload, base64Key, maxAgeSeconds) {
  const ageSeconds = (new Date().getTime() - Date.parse(timestamp)) / 1000;
  if (ageSeconds > maxAgeSeconds) {
    return false;
  }
  const key = Buffer.from(base64Key, "base64");
  const calculatedSignature = createHmac("sha256", key).update(`${payload}.${timestamp}`).digest();
  for (const signature of signatures.split(",")) {
    try {
      if (timingSafeEqual(calculatedSignature, Buffer.from(signature, "hex"))) {
        return true;
      }
    } catch {
      continue;
    }
  }
  return false;
};

const app = express();

app.use(
  express.json({
    verify: (req, _res, buf) => {
      req.rawBody = buf.toString();
    },
  })
);

app.post("/", (request, response) => {
  const signature = request.headers["webhook-signature"];
  const timestamp = request.headers["webhook-request-timestamp"];
  if (!signature || !timestamp) {
    response.status(400).send();
    return;
  }
  if (!verifyWebhookSignature(signature, timestamp, request.rawBody, webhookB64Key, maxAgeSeconds)) {
    response.status(401).send();
    return;
  }
  console.log("Verified webhook request");
  console.log(request.body);
  response.send();
});

app.listen(port, "0.0.0.0", () => {
  console.log(`Example app listening on port ${port}`);
});
