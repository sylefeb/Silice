/*

Copyright 2019, (C) Sylvain Lefebvre and contributors
List contributors with: git shortlog -n -s -- <filename>

MIT license

Permission is hereby granted, free of charge, to any person obtaining a copy of 
this software and associated documentation files (the "Software"), to deal in 
the Software without restriction, including without limitation the rights to 
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so, 
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all 
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR 
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER 
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN 
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

(header_2_M)

*/

#include <LibSL/LibSL.h>

#include <tclap/CmdLine.h>
#include <tclap/UnlabeledValueArg.h>
#include <tclap/SwitchArg.h>

using namespace std;

MeshFormat_stl g_Stl;

// ----------------------------------------------------------------------

void toC(std::string fname,const TriangleMesh_generic<LibSL::Mesh::MeshFormat_stl::t_VertexData> *mesh)
{
  ofstream f(fname);
  f << "#define NVERTS " << mesh->numVertices() << "\n";
  f << "#define NTRIS  " << mesh->numTriangles() << "\n";
  f << "int pts[NVERTS*3] = {\n";
  for (int i = 0; i < (int)mesh->numVertices(); i++) {
    f << (int)round(mesh->posAt(i)[0]) << ',';
    f << (int)round(mesh->posAt(i)[1]) << ',';
    f << (int)round(mesh->posAt(i)[2]);
    if (i != mesh->numVertices() - 1) f << ',';
  }
  f << "};\n";
  f << "int idx[NTRIS*3] = {\n";
  for (int i = 0; i < (int)mesh->numTriangles(); i++) {
    f << mesh->triangleAt(i)[0] << ',';
    f << mesh->triangleAt(i)[1] << ',';
    f << mesh->triangleAt(i)[2];
    if (i != mesh->numTriangles() - 1) f << ',';
  }
  f << "};\n";
  f << "int inv_area[NTRIS] = {\n";
  for (int i = 0; i < (int)mesh->numTriangles(); i++) {
    v3f pts[3];
    for (int j = 0; j < 3; j++) {
      pts[j] = mesh->posAt(mesh->triangleAt(i)[j]);
    }
    float area = max(1.0f, length(cross(pts[1] - pts[0], pts[2] - pts[0]) / 2.0f));
    f << (int)round(65536 / area);
    if (i != mesh->numTriangles() - 1) f << ',';
  }
  f << "};\n";
  f.close();
}

// ----------------------------------------------------------------------

/// \brief Helper class to encode into 256 bits words
class UInt256
{
public:
  uint8_t data[32];
  UInt256() { memset(data, 0x00, 32); }
  void shift_or(uint32_t v, int shift) {
    int k       = shift / 8;
    int k_shift = shift & 7;
    ForIndex(i, 5) {
      data[k] = data[k] | (v << k_shift);
      k       += 1;
      v        = v >> (8 - k_shift);
      k_shift  = 0;
      if (k + i >= 32) break;
    }
  }
  void print()
  {
    ForIndex(i, 32) {
      uint8_t v = data[31-i];
      ForIndex(j, 8) {
        cout << (((v>>(7-j)) & 1) ? '1' : '0');
      }
    }
    cout << '\n';
  }
};

// ----------------------------------------------------------------------

void toC_flat(std::string fname, const TriangleMesh_generic<LibSL::Mesh::MeshFormat_stl::t_VertexData> *mesh)
{
  ofstream f(fname);
  f << "#define NTRIS  " << mesh->numTriangles() << "\n";
  f << "unsigned char tris[NTRIS*8*4+4] = {\n";
  // number of triangles
  uint numt = mesh->numTriangles();
  f << sprint("0x%02x,",  numt      & 255);
  f << sprint("0x%02x,", (numt>> 8) & 255);
  f << sprint("0x%02x,", (numt>>16) & 255);
  f << sprint("0x%02x,", (numt>>24) & 255);
  f << '\n';
  // triangles
  ForIndex(i, mesh->numTriangles()) {
    UInt256  tri256b;
    ForIndex(p, 3) {
      v3f      pt    = mesh->posAt(mesh->triangleAt(i)[p]);
      ForIndex(c, 3) {
        uint32_t v = (uint)(pt[c]);
        sl_assert(v < (1 << 28));
        tri256b.shift_or(v, 28 * c + 28 * 3 * p);
      }
    }
    ForIndex(b, 32) {
      f << sprint("0x%02x", tri256b.data[b]);
      if (b < 31) f << ',';
    }
    if (i + 1 != mesh->numTriangles()) f << ',';
    f << '\n';
  }
  f << "};\n";
  f.close();
}

// ----------------------------------------------------------------------

void toRaw(std::string fname, const TriangleMesh_generic<LibSL::Mesh::MeshFormat_stl::t_VertexData> *mesh)
{
  FILE *f = NULL;
  f = fopen(fname.c_str(), "wb");
  // write number of triangles
  uint numt = mesh->numTriangles();
  fwrite(&numt,sizeof(uint),1,f);
  // write triangles
  ForIndex(i, numt) {
    UInt256  tri256b;
    ForIndex(p, 3) {
      v3f      pt = mesh->posAt(mesh->triangleAt(i)[p]);
      ForIndex(c, 3) {
        uint32_t v = (uint)(pt[c]);
        sl_assert(v < (1 << 28));
        tri256b.shift_or(v, 28 * c + 28 * 3 * p);
      }
    }
    ForIndex(b, 32) {
      fwrite(&tri256b.data[b], sizeof(uchar), 1, f);
    }
  }
  fclose(f);
}

// ----------------------------------------------------------------------

int main(int argc,char **argv)
{
  try {
    
    TCLAP::CmdLine cmd(
      "STL to raw, rewrites STL 3D models as C headers or raw format images\n"
      "(c) Sylvain Lefebvre -- @sylefeb\n"
      , ' ', "0.1");

    TCLAP::UnlabeledValueArg<std::string> source("source", "Input source file (.stl)", true, "", "string");
    cmd.add(source);
    TCLAP::ValueArg<std::string> output("o", "output", "Output file (.h/.raw added automatically)", false, "model", "string");
    cmd.add(output);
    TCLAP::SwitchArg raw("r", "raw", "Output as raw file", false);
    cmd.add(raw);
    TCLAP::SwitchArg ctr("c", "center", "Center model", false);
    cmd.add(ctr);
    TCLAP::SwitchArg idx("i", "indexed", "Output as indexed mesh (C only)", false);
    cmd.add(idx);
    TCLAP::SwitchArg unit("u", "unit", "Make model unit size before scaling", false);
    cmd.add(unit);
    TCLAP::ValueArg<float> scale("s", "scale", "Scale to apply to the model before encoding as integer", false, 1.0f, "float");
    cmd.add(scale);

    cmd.parse(argc, argv);


    auto *mesh = loadTriangleMesh<MeshFormat_stl::t_VertexData,MeshFormat_stl::t_VertexFormat>(argv[1]);
    mesh->mergeVertices();

    auto     bx = mesh->bbox();
    float maxex = tupleMax(bx.extent());
    if (ctr.isSet()) {
      // put model with bbox center at origin
      mesh->applyTransform(translationMatrix(-bx.center()));
    } else {
      // put model with bbox corner at origin
      mesh->applyTransform(translationMatrix(-bx.minCorner()));
    }
    // make unit size?
    if (unit.isSet()) {
      mesh->applyTransform(scaleMatrix(v3f(1.0f / maxex)));
    }
    // rescale
    mesh->applyTransform(scaleMatrix(v3f(scale.getValue())));
    cerr << "scale factor : " << scale.getValue() << '\n';
    cerr << "mesh rescaled in " << mesh->bbox().minCorner() << 'x' << mesh->bbox().maxCorner() << '\n';

    if (!raw.isSet()) {
      if (idx.isSet()) {
        toC(output.getValue() + ".h", mesh);
      } else {
        toC_flat(output.getValue() + ".h", mesh);
      }
    } else {
      toRaw(output.getValue() + ".raw", mesh);
    }

    cerr << "done.\n\n";

  } catch (Fatal& f) {
    cerr << f.message() << '\n';
  }    
  return 0;
}

// ----------------------------------------------------------------------
