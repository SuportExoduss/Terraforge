using UnityEngine;

namespace Terraforge.World
{
    /// <summary>
    /// Substitui a esfera primitiva da Unity (~770 triângulos, silhueta
    /// facetada) por uma esfera gerada por código na resolução desejada
    /// (técnica do "cubo normalizado": 6 faces de grade projetadas na
    /// esfera — distribuição uniforme, sem polos espremidos).
    /// Mantém o raio local 0.5 da primitiva: a escala do objeto continua
    /// mandando no tamanho, e nada mais no jogo muda.
    /// </summary>
    [RequireComponent(typeof(MeshFilter))]
    public sealed class SmoothSphereMesh : MonoBehaviour
    {
        // Quadrados por aresta de cada face do cubo: 48 → ~27 mil
        // triângulos (35x a primitiva), silhueta lisa mesmo em raio 100.
        [SerializeField] [Range(8, 96)] private int _resolution = 48;

        private static readonly Vector3[] FaceNormals =
        {
            Vector3.up, Vector3.down, Vector3.left,
            Vector3.right, Vector3.forward, Vector3.back
        };

        private void Awake()
        {
            GetComponent<MeshFilter>().mesh = BuildSphere(_resolution);
        }

        private static Mesh BuildSphere(int resolution)
        {
            int verticesPerFace = (resolution + 1) * (resolution + 1);
            var vertices = new Vector3[FaceNormals.Length * verticesPerFace];
            var normals = new Vector3[vertices.Length];
            var triangles = new int[FaceNormals.Length * resolution * resolution * 6];

            int vertexIndex = 0;
            int triangleIndex = 0;

            foreach (Vector3 faceNormal in FaceNormals)
            {
                // Dois eixos perpendiculares que "varrem" a face do cubo.
                var axisA = new Vector3(faceNormal.y, faceNormal.z, faceNormal.x);
                Vector3 axisB = Vector3.Cross(faceNormal, axisA);
                int faceStart = vertexIndex;

                for (int y = 0; y <= resolution; y++)
                {
                    for (int x = 0; x <= resolution; x++)
                    {
                        // Ponto na face plana do cubo (-1..1) projetado na esfera.
                        Vector2 percent = new(x / (float)resolution, y / (float)resolution);
                        Vector3 pointOnCube =
                            faceNormal +
                            (percent.x - 0.5f) * 2f * axisA +
                            (percent.y - 0.5f) * 2f * axisB;

                        Vector3 pointOnSphere = pointOnCube.normalized;
                        vertices[vertexIndex] = pointOnSphere * 0.5f;
                        normals[vertexIndex] = pointOnSphere;

                        bool hasQuad = x < resolution && y < resolution;
                        if (hasQuad)
                        {
                            int row = resolution + 1;
                            int corner = faceStart + y * row + x;

                            // Ordem horária vista de fora = face visível externa.
                            triangles[triangleIndex++] = corner;
                            triangles[triangleIndex++] = corner + row + 1;
                            triangles[triangleIndex++] = corner + row;
                            triangles[triangleIndex++] = corner;
                            triangles[triangleIndex++] = corner + 1;
                            triangles[triangleIndex++] = corner + row + 1;
                        }

                        vertexIndex++;
                    }
                }
            }

            var mesh = new Mesh
            {
                name = "SmoothSphere",
                indexFormat = UnityEngine.Rendering.IndexFormat.UInt32
            };
            mesh.SetVertices(vertices);
            mesh.SetNormals(normals);
            mesh.SetTriangles(triangles, 0);
            return mesh;
        }
    }
}
