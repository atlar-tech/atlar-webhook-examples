import express from "express";
import { createHmac } from "crypto";

const port = process.env.PORT || 8000;
const webhookB64Key = process.env.WEBHOOK_B64KEY;

const verifyWebhookSignature = function (signatures, timestamp, payload, base64Key) {
  const ageSeconds = (new Date().getTime() - Date.parse(timestamp)) / 1000;
  const ageHours = ageSeconds / 60 / 60;
  if (ageHours > 1) {
    console.error("Warning: Webhook request timestamp is older than expected", ageHours);
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
  if (!request.get("webhook-signature") || !request.get("webhook-request-timestamp")) {
    response.status(400).send();
    return;
  }
  const signatures = request.headers["webhook-signature"];
  const timestamp = request.headers["webhook-request-timestamp"];
  if (!verifyWebhookSignature(signatures, timestamp, request.rawBody, webhookB64Key)) {
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
