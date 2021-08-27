// SL 2021-01-22 @sylefeb
 
// MIT license, see LICENSE_MIT in Silice repo root

// trigonometry (fixed precision: 7 bits - a unit = 128)
extern int costbl[256]; // 256 entries
int fxcos(int angle);   // angles in [0,255]
int fxsin(int angle);

// matrix transforms (fixed precision: 7 bits - a unit = 128)
void rotX  (int *M, int angle);
void rotY  (int *M, int angle);
void rotZ  (int *M, int angle);
void scale (int *M, int sc);
void scale3(int *M,int sx,int sy,int sz);
void mulM  (int *M, const int *A,const int *B);

// draw a triangle (fixed precision: 5 bits - a unit = 32)
// color: base palette color
// shade: if 0, disabled, if 1 uses triangle area to shade from index color in [color,color+16(recheck)]
void draw_triangle(char color,char shade,int px0,int py0,int px1,int py1,int px2,int py2);

// clear screen (uses triangles)
void clear(char color,int xm,int ym,int xM,int yM);
