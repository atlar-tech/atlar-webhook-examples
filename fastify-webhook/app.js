import Fastify from "fastify";
import rawBody from "fastify-raw-body";
import { createHmac, timingSafeEqual } from "crypto";

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

const app = Fastify({
  logger: true,
});

// Register raw body plugin so that routes can opt in to use it.
await app.register(rawBody, {
  field: "rawBody", // change the default request.rawBody property name
  global: false, // add the rawBody to every request. **Default true**
  encoding: "utf8", // set it to false to set rawBody as a Buffer **Default utf8**
  runFirst: true, // get the body before any preParsing hook change/uncompress it. **Default false**
  routes: [], // array of routes, **`global`** will be ignored, wildcard routes not supported
});

app.post(
  "/",
  {
    config: {
      rawBody: true,
    },
  },
  function (request, response) {
    if (!request.headers["webhook-signature"] || !request.headers["webhook-request-timestamp"]) {
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
    response.send("ok");
  }
);

app.listen({ host: "0.0.0.0", port }, function (err, _address) {
  if (err) {
    app.log.error(err);
    process.exit(1);
  }
});
