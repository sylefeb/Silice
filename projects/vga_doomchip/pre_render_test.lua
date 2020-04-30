-- some testing
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
ray_y   = -3616+100
view_dx = 0
view_dy = 1
for i=1,w do
print('column ' .. i)
ray_dx = (i-160)*4
ray_dy = 320
top    = 200
btm    = 1
len    = math.sqrt(ray_dx*ray_dx+ray_dy*ray_dy)
ray_dx = ray_dx / len -- cos(angle)
ray_dy = ray_dy / len -- sin(angle)
queue = {}
queue_ptr = 1
queue[queue_ptr] = root
queue_ptr = queue_ptr + 1
while queue_ptr > 1 do
  n = queue[queue_ptr-1]
  queue_ptr = queue_ptr - 1
  if (n&(1<<15)) == 0 then
	lx  = nodes[1+n].x
	ly  = nodes[1+n].y
	ldx = nodes[1+n].dx
	ldy = nodes[1+n].dy
	r   = nodes[1+n].rchild
	l   = nodes[1+n].lchild
	-- which side are we?
	dx     = ray_x - lx
	dy     = ray_y - ly
	csl    = dx * ldy
	csr    = dy * ldx
	if csr > csl then
	  -- front
	  queue[queue_ptr] = nodes[1+n].rchild;
	  queue_ptr = queue_ptr + 1     
	  queue[queue_ptr] = nodes[1+n].lchild;
	  queue_ptr = queue_ptr + 1     
	else
	  -- back
	  queue[queue_ptr] = nodes[1+n].lchild;
	  queue_ptr = queue_ptr + 1     
	  queue[queue_ptr] = nodes[1+n].rchild;
	  queue_ptr = queue_ptr + 1     
	end
  else
	sec = (n&(~(1<<15)))
	-- print('sector ' .. sec)
	for s=0,ssectors[1+sec].num_segs-1 do
	  sid = 1 + ssectors[1+sec].start_seg + s
	  seg = segs[sid]
	  v0  = verts[1+seg.v0]
	  v1  = verts[1+seg.v1]
	  -- print('seg id=' .. sid .. ' ' .. v0.x ..',' .. v0.y .. ' to ' .. v1.x .. ',' .. v1.y)
	  -- check if solid
	  ldef = lines[1+seg.ldf]
	  other_sidedef = nil
	  if seg.dir == 0 then
      sidedef   = sides[1+ldef.right]
      if ldef.left < 65535 then
        other_sidedef = sides[1+ldef.left]
      end
	  else
      sidedef       = sides[1+ldef.left]
      other_sidedef = sides[1+ldef.right]
	  end
	  -- check for intersection
	  d0x = v0.x - ray_x
	  d0y = v0.y - ray_y
	  d1x = v1.x - ray_x
	  d1y = v1.y - ray_y
	  cs0 = d0x*ray_dy - d0y*ray_dx
	  cs1 = d1x*ray_dy - d1y*ray_dx
	  if (cs0<0 and cs1>=0) or (cs1<0 and cs0>=0) then
		-- compute distance
		y0 =    d0x * ray_dx + d0y * ray_dy
		y1 =    d1x * ray_dx + d1y * ray_dy
		x0 =  - d0x * ray_dy + d0y * ray_dx
		x1 =  - d1x * ray_dy + d1y * ray_dx
		d  = y0 + (y1 - y0) * ( - x0 ) / (x1 - x0)
		d  = d * (ray_dx*view_dx + ray_dy*view_dy) -- cos(alpha)
		if d > 0 then
		  sector       = sectors[1+sidedef.sec]
		  other_sector = nil
		  if other_sidedef then
			  other_sector = sectors[1+other_sidedef.sec]
		  end
		  -- hit!
		  f_h     = (sector.floor   - 40) * 128
		  c_h     = (sector.ceiling - 40) * 128
		  f_h     = 100 + f_h / d
		  c_h     = 100 + c_h / d
		  f_h     = math.floor(math.max(btm,math.min(top,f_h)))
		  c_h     = math.floor(math.max(btm,math.min(top,c_h)))
		  -- move floor and ceiling
		  for j=btm,f_h-1 do
			img[201-j][i] = 255
		  end
		  btm = f_h
		  for j=c_h+1,top do
			img[201-j][i] = 255
		  end
		  top = c_h
		  if sidedef.lwrT:sub(1, 1) ~= '-' then
			f_o = (other_sector.floor - 40) * 128
			f_o = 100 + f_o / d
			f_o = math.floor(math.max(btm,math.min(top,f_o)))
			for j=btm,f_o-1 do
			  img[201-j][i] = ((sid*173)&255) | (((sid*13)&255)<<8) | (((sid*7133)&255)<<16)
			end
			btm = f_o
		  end
		  if sidedef.uprT:sub(1, 1) ~= '-' then
			c_o = (other_sector.ceiling - 40) * 128
			c_o = 100 + c_o / d
			c_o = math.floor(math.max(btm,math.min(top,c_o)))
			for j=c_o+1,top do
			  img[201-j][i] = ((sid*173)&255) | (((sid*13)&255)<<8) | (((sid*7133)&255)<<16)
			end
			top = c_o
		  end
		  if sidedef.midT:sub(1, 1) ~= '-' then
			-- opaque wall
			for j=f_h,c_h do
			  img[201-j][i] = ((sid*173)&255) | (((sid*13)&255)<<8) | (((sid*7133)&255)<<16)
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
error('stop')
