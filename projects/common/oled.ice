// SL 2020-07
// OLED display library for Silice
// ------------------------- 
// ST7789 options
// st7789_no_cs     => true if CS is always grounded and CS pin used or backlight
// st7789_transpose => true to transpose column/rows
// ------------------------- 

$$ if ST7789 then
$$   -- st7789_no_cs     = true
$$   -- st7789_transpose = true
$include('oled_st7789.ice')
$$   if not oled_width then
$$     oled_width      = 240
$$     oled_height     = 320
$$   end
$$   if st7789_transpose then
$$     oled_width,oled_height = oled_height,oled_width
$$   end
$$   print('[oled] ST7789 driver on ' .. oled_width .. 'x' .. oled_height .. ' display')
$$ elseif SSD1351 then
$include('oled_ssd1351.ice')
$$   if not oled_width then
$$     oled_width      = 128
$$     oled_height     = 128
$$   end
$$   print('[oled] SSD1351 driver on ' .. oled_width .. 'x' .. oled_height .. ' display')
$$ else
$$error('[oled] please specify driver, either ST7789 or SSD1351\n                      (e.g. add ' .. string.char(36) .. string.char(36) .. 'ST7789=1 before including this file)')
$$ end

$$if not OLED then
$$error('no OLED support according to framework')
$$end

// ------------------------- 
