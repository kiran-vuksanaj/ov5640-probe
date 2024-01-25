void setup() {
  // put your setup code here, to run once:
  Serial.begin(9600);
  Serial.println("Starting");

  // set settings to match selected mode
  switch(MODE) {
    case QVGA:
      settings = settings_qvga;
      total_settings = length_qvga;
      break;
    case HD:
      settings = settings_hd;
      total_settings = length_hd;
      break;
    case EXP:
      settings = settings_exp;
      total_settings = length_exp;
      break;
  }

  pinMode(led,OUTPUT);
  pinMode(0,INPUT);
  Wire.begin();
  digitalWrite(led,HIGH);
  program();
  delay(1000);
  digitalWrite(led,LOW);
}
  

void loop() {
  // put your main code here, to run repeatedly:digitalWrite(led, HIGH);   // turn the LED on (HIGH is the voltage level)
//  if (Serial.available() > 0) {
//    while (Serial.available() > 0) {
//      Serial.read();
//    }
    // just indicate that the microcontroller is like. alive. don't do anything, only reprogram on power cycle of microcontroller
    digitalWrite(led,HIGH);
    delay(1000);
    digitalWrite(led,LOW);
    delay(1000);
//    program();
}
