import Fastify from "fastify";
import rawBody from "fastify-raw-body";
import { createHmac, timingSafeEqual } from "crypto";

const port = process.env.PORT || 8000;
const webhookB64Key = process.env.WEBHOOK_B64KEY;
const maxAgeSeconds = process.env.MAX_REQUEST_AGE_SECONDS || 300;

const verifyWebhookSignature = function (signatures, timestamp, payload, base64Key) {
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

app.post("/", { config: { rawBody: true } }, (request, response) => {
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

app.listen({ host: "0.0.0.0", port }, function (err, _address) {
  if (err) {
    app.log.error(err);
    process.exit(1);
  }
});
