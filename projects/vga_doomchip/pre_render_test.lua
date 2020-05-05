-- SL 2020-04-30

-- prepare image
w = 320
h = 200
img = {}
for j=1,h do
  img[j] = {}
  for i=1,w do
    img[j][i] = 0
  end
end

-- raycast
ray_x   = 1050
ray_y   = -3616 + 90 + 130

view_angle = math.pi/2

view_dx = math.cos(view_angle)
view_dy = math.sin(view_angle)
-- local outlog = assert(io.open(findfile('renderlog.txt'), 'w'))
for i=0,w-1 do
  alpha     = math.atan((w/2-i)*2/w)
  ray_angle = view_angle + alpha
  ray_dx    = math.cos(ray_angle)
  ray_dy    = math.sin(ray_angle)
  top       = 200
  btm       = 1
  queue     = {}
  queue_ptr = 1
  queue[queue_ptr] = root
  queue_ptr = queue_ptr + 1
  --outlog:write('column ' .. i ..'\n')
  --outlog:write('  alpha    =' .. alpha ..'\n')
  --outlog:write('  ray_angle=' .. ray_angle ..'\n')
  --outlog:write('  ray_dx   =' .. ray_dx ..'\n')
  --outlog:write('  ray_dy   =' .. ray_dy ..'\n')
  while queue_ptr > 1 do
    n = queue[queue_ptr-1]
    queue_ptr = queue_ptr - 1
    if (n&(1<<15)) == 0 then
      --outlog:write('  -> node ' .. n ..'\n')
      lx  = bspNodes[1+n].x
      ly  = bspNodes[1+n].y
      ldx = bspNodes[1+n].dx
      ldy = bspNodes[1+n].dy
      r   = bspNodes[1+n].rchild
      l   = bspNodes[1+n].lchild
      --outlog:write('    lx  = ' .. lx ..'\n')
      --outlog:write('    ly  = ' .. ly ..'\n')
      --outlog:write('    ldx = ' .. ldx ..'\n')
      --outlog:write('    ldy = ' .. ldy ..'\n')
      -- which side are we on?
      dx     = ray_x - lx
      dy     = ray_y - ly
      csl    = dx * ldy
      csr    = dy * ldx
      --outlog:write('    dx  = ' .. dx ..'\n')
      --outlog:write('    dy  = ' .. dy ..'\n')
      --outlog:write('    csl = ' .. csl ..'\n')
      --outlog:write('    csr = ' .. csr ..'\n')
      if csr > csl then
        -- front
        queue[queue_ptr] = bspNodes[1+n].rchild;
        queue_ptr = queue_ptr + 1     
        queue[queue_ptr] = bspNodes[1+n].lchild;
        queue_ptr = queue_ptr + 1     
      else
        -- back
        queue[queue_ptr] = bspNodes[1+n].lchild;
        queue_ptr = queue_ptr + 1     
        queue[queue_ptr] = bspNodes[1+n].rchild;
        queue_ptr = queue_ptr + 1     
      end
    else
      sec = (n&(~(1<<15)))
      --outlog:write('  -> ssector ' .. sec .. '(' .. n .. ')\n')
      sector = bspSSectors[1+sec]
      for s=0,sector.num_segs-1 do
        sid = 1 + sector.start_seg + s
        seg = bspSegs[sid]
        -- check for intersection
        d0x = seg.v0x - ray_x
        d0y = seg.v0y - ray_y
        d1x = seg.v1x - ray_x
        d1y = seg.v1y - ray_y
        cs0 = d0x*ray_dy - d0y*ray_dx
        cs1 = d1x*ray_dy - d1y*ray_dx
        --outlog:write('    d0x  = ' .. d0x ..'\n')
        --outlog:write('    d0y  = ' .. d0y ..'\n')
        --outlog:write('    d1x  = ' .. d1x ..'\n')
        --outlog:write('    d1y  = ' .. d1y ..'\n')
        --outlog:write('    cs0  = ' .. cs0 ..'\n')
        --outlog:write('    cs1  = ' .. cs1 ..'\n')
        if (cs0<0 and cs1>=0) or (cs1<0 and cs0>=0) then
          -- compute distance        
          y0 =    d0x * ray_dx + d0y * ray_dy
          y1 =    d1x * ray_dx + d1y * ray_dy
          x0 =  - d0x * ray_dy + d0y * ray_dx
          x1 =  - d1x * ray_dy + d1y * ray_dx
          --outlog:write('    x0  = ' .. x0 ..'\n')
          --outlog:write('    x1  = ' .. x1 ..'\n')
          --outlog:write('    y0  = ' .. y0 ..'\n')
          --outlog:write('    y1  = ' .. y1 ..'\n')
          --outlog:write('    div num        = ' .. ((y1 - y0) * ( - x0 )) ..'\n')
          --outlog:write('    div den        = ' .. (x1 - x0) ..'\n')
          --outlog:write('    div res        = ' .. ((y1 - y0) * ( - x0 ) / (x1 - x0)) ..'\n')
          d  = (y0 + (y1 - y0) * ( - x0 ) / (x1 - x0))  
          --outlog:write('    d              = ' .. d ..'\n')
          d  = math.cos(alpha) * d
          --outlog:write('    d *cos(alpha)  = ' .. d ..'\n')
          if d > 0 then
            -- hit!
            --outlog:write('    sector.f_h (1) = ' .. sector.f_h ..'\n')
            --outlog:write('    sector.c_h (1) = ' .. sector.c_h ..'\n')
            f_h     = (sector.f_h) * 196
            c_h     = (sector.c_h) * 196
            --outlog:write('    f_h (1) = ' .. f_h ..'\n')
            --outlog:write('    c_h (1) = ' .. c_h ..'\n')
            f_h     = 100 + f_h / d
            c_h     = 100 + c_h / d
            --outlog:write('    f_h (2) = ' .. f_h ..'\n')
            --outlog:write('    c_h (2) = ' .. c_h ..'\n')
            f_h     = math.floor(math.max(btm,math.min(top,f_h)))
            c_h     = math.floor(math.max(btm,math.min(top,c_h)))
            --outlog:write('    upr = ' .. seg.upr ..'\n')
            --outlog:write('    mid = ' .. seg.mid ..'\n')
            --outlog:write('    lwr = ' .. seg.lwr ..'\n')
            -- move floor and ceiling
            for j=btm,f_h-1 do
              img[201-j][1+i] = 255
            end
            btm = f_h
            for j=c_h+1,top do
              img[201-j][1+i] = 255
            end
            top = c_h
            if seg.lwr > 0 then
              f_o = (seg.other_f_h) * 196
              f_o = 100 + f_o / d
              f_o = math.floor(math.max(btm,math.min(top,f_o)))
              for j=btm,f_o-1 do
                img[201-j][1+i] = ((sid*173)&255) | (((sid*13)&255)<<8) | (((sid*7133)&255)<<16)
              end
              btm = f_o
            end
            if seg.upr > 0 then
              c_o = (seg.other_c_h) * 196
              c_o = 100 + c_o / d
              c_o = math.floor(math.max(btm,math.min(top,c_o)))
              for j=c_o+1,top do
                img[201-j][1+i] = ((sid*173)&255) | (((sid*13)&255)<<8) | (((sid*7133)&255)<<16)
              end
              top = c_o
            end           
            if seg.mid > 0 then
              -- opaque wall
              for j=f_h,c_h do
                img[201-j][1+i] = ((sid*173)&255) | (((sid*13)&255)<<8) | (((sid*7133)&255)<<16)
              end
              -- flush queue to stop
              queue_ptr = 1
              break
            end
          end
        end
      end
    end
  end
end
save_table_as_image(img,'test.tga')
-- error('stop')
