// SL 2020-07
// OLED display library for Silice
// ------------------------- 

$$ if ST7789 then
$include('oled_st7789.ice')
$$   oled_width      = 240
$$   oled_height     = 240
$$ elseif SSD1351 then
$include('oled_ssd1351.ice')
$$   oled_width      = 128
$$   oled_height     = 128
$$ else
$$error('[oled] please specify driver, either ST7789 or SSD1351\n                      (e.g. add ' .. string.char(36) .. string.char(36) .. 'ST7789=1 before including this file)')
$$ end

$$if not OLED then
$$error('no OLED support according to framework')
$$end

// ------------------------- 
