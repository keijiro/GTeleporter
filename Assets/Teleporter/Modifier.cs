// Geometry teleporter effect
// https://github.com/keijiro/GTeleporter

using UnityEngine;
using System.Collections.Generic;

namespace GTeleporter
{
    [ExecuteInEditMode]
    [AddComponentMenu("Effects/GTeleporter/Modifier")]
    class Modifier : MonoBehaviour
    {
        #region Editable attributes

        [SerializeField] float _offset;
        [SerializeField] Transform _vanishingPoint;
        [SerializeField] Renderer[] _linkedRenderers;

        #endregion

        #region MonoBehaviour implementation

        MaterialPropertyBlock _sheet;

        void Update()
        {
            if (_linkedRenderers == null || _linkedRenderers.Length == 0) return;

            if (_sheet == null) _sheet = new MaterialPropertyBlock();

            var fwd = transform.forward / transform.localScale.z;
            var dist = Vector3.Dot(fwd, transform.position);

            _sheet.SetVector("_EffectVector",
                new Vector4(fwd.x, fwd.y, fwd.z, dist + _offset)
            );

            _sheet.SetVector("_EffectPoint",
                _vanishingPoint != null ? _vanishingPoint.position : Vector3.forward * 10
            );

            foreach (var r in _linkedRenderers) r.SetPropertyBlock(_sheet);
        }

        #endregion

        #region Editor gizmo implementation

        #if UNITY_EDITOR

        Mesh _gridMesh;

        void OnDestroy()
        {
            if (_gridMesh != null)
            {
                if (Application.isPlaying)
                    Destroy(_gridMesh);
                else
                    DestroyImmediate(_gridMesh);
            }
        }

        void OnDrawGizmos()
        {
            if (_gridMesh == null) InitGridMesh();

            if (_vanishingPoint != null)
            {
                Gizmos.color = Color.cyan;
                Gizmos.DrawWireSphere(_vanishingPoint.position, 0.1f);
            }

            Gizmos.matrix = transform.localToWorldMatrix;

            var p1 = Vector3.forward * _offset;
            var p2 = Vector3.forward * (_offset + 1);

            Gizmos.color = new Color(1, 1, 0, 0.5f);
            Gizmos.DrawWireMesh(_gridMesh, p1);
            Gizmos.DrawWireMesh(_gridMesh, p2);

            Gizmos.color = new Color(1, 0, 0, 0.5f);
            Gizmos.DrawWireCube((p1 + p2) / 2, new Vector3(0.02f, 0.02f, 1));
        }

        void InitGridMesh()
        {
            const float ext = 0.5f;
            const int columns = 10;

            var vertices = new List<Vector3>();
            var indices = new List<int>();

            for (var i = 0; i < columns + 1; i++)
            {
                var x = ext * (2.0f * i / columns - 1);

                indices.Add(vertices.Count);
                vertices.Add(new Vector3(x, -ext, 0));

                indices.Add(vertices.Count);
                vertices.Add(new Vector3(x, +ext, 0));

                indices.Add(vertices.Count);
                vertices.Add(new Vector3(-ext, x, 0));

                indices.Add(vertices.Count);
                vertices.Add(new Vector3(+ext, x, 0));
            }

            _gridMesh = new Mesh();
            _gridMesh.hideFlags = HideFlags.DontSave;
            _gridMesh.SetVertices(vertices);
            _gridMesh.SetNormals(vertices);
            _gridMesh.SetIndices(indices.ToArray(), MeshTopology.Lines, 0);
            _gridMesh.UploadMeshData(true);
        }

        #endif

        #endregion
    }
}
