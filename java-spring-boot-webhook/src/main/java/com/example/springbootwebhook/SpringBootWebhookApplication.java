package com.example.springbootwebhook;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.OffsetDateTime;
import java.util.Base64;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import org.apache.commons.codec.binary.Hex;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.RestController;

@RestController
@SpringBootApplication
public class SpringBootWebhookApplication {

  @Value("${WEBHOOK_B64KEY}")
  private String base64Key;

  @Value("${MAX_REQUEST_AGE_SECONDS:500}")
  private long maxAgeSeconds;

  @RequestMapping(
      value = "/",
      method = RequestMethod.POST,
      consumes = MediaType.APPLICATION_JSON_VALUE)
  public ResponseEntity<String> webhook(
      @RequestBody String body,
      @RequestHeader(value = "webhook-signature") String signatures,
      @RequestHeader(value = "webhook-request-timestamp") String timestamp) {

    if (!SpringBootWebhookApplication.signatureIsValid(
        signatures, timestamp, body, this.base64Key, this.maxAgeSeconds)) {
      return new ResponseEntity(HttpStatus.UNAUTHORIZED);
    }
    return new ResponseEntity(HttpStatus.OK);
  }

  public static boolean signatureIsValid(
      String sigHeader, String tsHeader, String payload, String base64Key, long maxAgeSeconds) {
    try {
      OffsetDateTime t = OffsetDateTime.parse(tsHeader);
      if (t.plusSeconds(maxAgeSeconds).isBefore(OffsetDateTime.now())) {
        return false;
      }
      byte[] key = Base64.getDecoder().decode(base64Key);
      Mac mac = Mac.getInstance("HmacSHA256");
      mac.init(new SecretKeySpec(key, "HmacSHA256"));
      mac.update(payload.getBytes(StandardCharsets.UTF_8));
      mac.update(".".getBytes(StandardCharsets.UTF_8));
      mac.update(tsHeader.getBytes(StandardCharsets.UTF_8));
      byte[] calculatedSignature = mac.doFinal();

      for (String sig : sigHeader.split(",")) {
        try {
          if (MessageDigest.isEqual(calculatedSignature, Hex.decodeHex(sig))) {
            return true;
          }
        } catch (Exception ex) {
          continue;
        }
      }
      return false;
    } catch (Exception ex) {
      return false;
    }
  }

  public static void main(String[] args) {
    SpringApplication.run(SpringBootWebhookApplication.class, args);
  }
}
