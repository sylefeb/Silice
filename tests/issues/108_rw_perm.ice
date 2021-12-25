algorithm main(output uint5 leds) {

   uint26 cnt = 0;

   subroutine out_led(input uint5 pattern, readwrites leds) {
      leds = pattern;
   }

   subroutine out_led_inverted(input uint5 pattern, calls out_led) {
      () <- out_led <- (~pattern);
   }

   while(1) {

      cnt = cnt + 1;

      () <- out_led_inverted <- (cnt[0,5]);
      // () <- out_led <- (cnt[0,5]);

$$if SIMULATION then
      __display("leds = %b",leds);
      if (cnt == 32) {
        __finish();
      }
$$end

   }
}
