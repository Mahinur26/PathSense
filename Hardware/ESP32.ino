// Motor smoke test — XIAO ESP32-S3 + L298N (ENA jumper ON).
// Wiring (matches SmartCane_ESP32.ino): D1(GPIO2) -> IN2, D2(GPIO3) -> IN1, common GND.
// Power: 12V to L298N; XIAO via USB. Greartisan 12V 200RPM ~0.5A rated — fine for L298N.
//
// Arduino IDE: open this folder as its own sketch (File -> Open -> MotorL298N_Test.ino).

#include <Arduino.h>

static constexpr int kMotorForwardPin = 3;  // D2 on XIAO ESP32-S3
static constexpr int kMotorReversePin = 2;  // D1

static constexpr uint8_t kTestPwm = 140;     // ~55% duty; raise after it runs cleanly
static constexpr uint32_t kRunMs = 2500;
static constexpr uint32_t kPauseMs = 800;

static void motorStop() {
  analogWrite(kMotorForwardPin, 0);
  analogWrite(kMotorReversePin, 0);
}

static void motorForward(uint8_t pwm) {
  analogWrite(kMotorReversePin, 0);
  analogWrite(kMotorForwardPin, pwm);
}

static void motorReverse(uint8_t pwm) {
  analogWrite(kMotorForwardPin, 0);
  analogWrite(kMotorReversePin, pwm);
}

void setup() {
  Serial.begin(115200);
  delay(500);

  pinMode(kMotorForwardPin, OUTPUT);
  pinMode(kMotorReversePin, OUTPUT);
  motorStop();

  Serial.println();
  Serial.println("MotorL298N_Test: forward / reverse / pause loop");
  Serial.println("Ensure nothing touches the shaft; ready in 2s...");
  delay(2000);
}

void loop() {
  Serial.printf("FORWARD  PWM=%u  %lums\n", kTestPwm, static_cast<unsigned long>(kRunMs));
  motorForward(kTestPwm);
  delay(kRunMs);

  Serial.println("STOP (coast)");
  motorStop();
  delay(kPauseMs);

  Serial.printf("REVERSE  PWM=%u  %lums\n", kTestPwm, static_cast<unsigned long>(kRunMs));
  motorReverse(kTestPwm);
  delay(kRunMs);

  Serial.println("STOP");
  motorStop();
  delay(kPauseMs);
}
