algorithm main(output uint8 leds)
{
  always {
    uint24 cnt(0);

    leds[0,8] = cnt[16,8];
    cnt       = cnt + 1;
  }
}
