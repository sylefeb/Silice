#include <LibSL/LibSL.h>

using namespace std;

MeshFormat_stl g_Stl;

int main(int argc,char **argv)
{
  try {
    sl_assert(argc == 2);
    auto *mesh = loadTriangleMesh<MeshFormat_stl::t_VertexData,MeshFormat_stl::t_VertexFormat>(argv[1]);
    mesh->mergeVertices();
    ofstream f("model3d.h");
    f << "#define NVERTS " << mesh->numVertices() << "\n";
    f << "#define NTRIS  " << mesh->numTriangles() << "\n";
    f << "int pts[NVERTS*3] = {\n";
    for (int i=0;i<mesh->numVertices();i++) {
      f << (int)round(2*mesh->posAt(i)[0]) << ',';
      f << (int)round(2*mesh->posAt(i)[1]) << ',';
      f << (int)round(2*mesh->posAt(i)[2]);
      if (i != mesh->numVertices() -1) f << ',';
    }
    f << "};\n";
    f << "int idx[NTRIS*3] = {\n";
    for (int i=0;i<mesh->numTriangles();i++) {
      f << 3*mesh->triangleAt(i)[0] << ',';
      f << 3*mesh->triangleAt(i)[1] << ',';
      f << 3*mesh->triangleAt(i)[2];
      if (i != mesh->numTriangles() -1) f << ',';
    }
    f << "};\n";
    f.close();
  } catch (Fatal& f) {
    cerr << f.message() << '\n';
  }    
  return 0;
}