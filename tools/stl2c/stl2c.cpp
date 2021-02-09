#include <LibSL/LibSL.h>

using namespace std;

MeshFormat_stl g_Stl;

int main(int argc,char **argv)
{
  try {
    sl_assert(argc == 2);
    auto *mesh = loadTriangleMesh<MeshFormat_stl::t_VertexData,MeshFormat_stl::t_VertexFormat>(argv[1]);
    mesh->mergeVertices();
    auto bx = mesh->bbox();
    float maxex = tupleMax(bx.extent());
    mesh->applyTransform(
         scaleMatrix(v3f(190.0f/maxex))
       * translationMatrix(-bx.center())
       );
    cerr << "mesh rescaled in " << mesh->bbox().minCorner() << 'x' << mesh->bbox().maxCorner() << '\n';
    ofstream f("model3d.h");
    f << "#define NVERTS " << mesh->numVertices() << "\n";
    f << "#define NTRIS  " << mesh->numTriangles() << "\n";
    f << "int pts[NVERTS*3] = {\n";
    for (int i=0;i<mesh->numVertices();i++) {
      f << (int)round(mesh->posAt(i)[0]) << ',';
      f << (int)round(mesh->posAt(i)[1]) << ',';
      f << (int)round(mesh->posAt(i)[2]);
      if (i != mesh->numVertices() -1) f << ',';
    }
    f << "};\n";
    f << "int idx[NTRIS*3] = {\n";
    for (int i=0;i<mesh->numTriangles();i++) {
      f << mesh->triangleAt(i)[0] << ',';
      f << mesh->triangleAt(i)[1] << ',';
      f << mesh->triangleAt(i)[2];
      if (i != mesh->numTriangles() -1) f << ',';
    }
    f << "};\n";
    f << "int inv_area[NTRIS] = {\n";
    for (int i=0;i<mesh->numTriangles();i++) {
      v3f pts[3];
      for (int j=0;j<3;j++) {
        pts[j] = mesh->posAt(mesh->triangleAt(i)[j]);
      }
      float area = length(cross(pts[1]-pts[0],pts[2]-pts[0])/2.0f);
      f << round(65536/area);
      if (i != mesh->numTriangles() -1) f << ',';
    }    
    f << "};\n";
    f.close();
  } catch (Fatal& f) {
    cerr << f.message() << '\n';
  }    
  return 0;
}
