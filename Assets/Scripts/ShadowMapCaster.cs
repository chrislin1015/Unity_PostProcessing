using System.Collections.Generic;
using UnityEngine;

namespace LINKernel
{
    [RequireComponent(typeof(Camera))]
    [DisallowMultipleComponent]
    public class ShadowMapCaster : MonoBehaviour
    {
        public enum Quailty
        {
            High = 2048,
            Normal = 1024,
            Low = 512
        }

        public enum ShadowMapFormat
        {
            Rg16 = RenderTextureFormat.RG16,
            Rgba = RenderTextureFormat.ARGB32,
            R16 = RenderTextureFormat.R16,
            R32 = RenderTextureFormat.RFloat
        }

        static protected RenderTexture _shadowMapRenderTarget;
        static public RenderTexture shadowMapRenderTarget
        {
            get { return _shadowMapRenderTarget; }
        }

        static protected Matrix4x4 _lightSpaceMatrix = Matrix4x4.identity;
        static public Matrix4x4 lightSpaceMatrix
        {
            get { return _lightSpaceMatrix; }
        }

        static protected Vector3 _lightDir = Vector3.forward;
        static public Vector3 lightDir
        {
            get { return _lightDir; }
        }

        [SerializeField]
        protected Quailty _quailty = Quailty.Normal;

        [SerializeField]
        protected ShadowMapFormat _shadowMapFormat = ShadowMapFormat.Rgba;

        [SerializeField]
        protected Shader _shadowMapCasterShader;

        [SerializeField]
        protected Transform _followTarget;

        [SerializeField]
        protected Transform _lookTarget;

        [SerializeField]
        protected bool _fixedPoint = false;

        [SerializeField]
        protected LayerMask _layerMask;

        protected Camera _lightCamera;
        protected Transform _myTransform;
        protected List<Transform> _lightSources = new List<Transform>();

        void Awake()
        {
            _myTransform = transform;
            CameraSetting();
        }

        void OnDestroy()
        {
            RenderTexture.ReleaseTemporary(_shadowMapRenderTarget);
            _shadowMapRenderTarget = null;
            _lightSpaceMatrix = Matrix4x4.identity;
            _lightDir = Vector3.forward;
            _lightSources.Clear();
        }

        void Update()
        {
            if (_fixedPoint)
            {
                if (_lookTarget != null)
                {
                    _myTransform.forward = (_lookTarget.position - _myTransform.position).normalized;
                }
            }

            if (_followTarget != null)
            {
                Vector3 playerPos = _followTarget.position + (_followTarget.forward * 15.0f);

                float dis = 5.0f;

                if (!_fixedPoint)
                    _myTransform.position = playerPos + (-_myTransform.forward * dis);

                if (_lightCamera != null)
                {
                    float temp = Mathf.Max(dis * 2.0f, 15.0f);
                    _lightCamera.nearClipPlane = -temp;
                    _lightCamera.farClipPlane = temp;
                }
            }
        }

        void OnPreRender()
        {
            if (_lightCamera == null || _shadowMapCasterShader == null)
                return;

            CreateShadowMap();

            if (_shadowMapFormat == ShadowMapFormat.R16 || _shadowMapFormat == ShadowMapFormat.R32)
            {
                Shader.EnableKeyword("RFLOAT");
                Shader.DisableKeyword("RGBA8");
                Shader.DisableKeyword("RG16");
            }
            else if (_shadowMapFormat == ShadowMapFormat.Rgba)
            {
                Shader.EnableKeyword("RGBA8");
                Shader.DisableKeyword("RFLOAT");
                Shader.DisableKeyword("RG16");
            }
            else if (_shadowMapFormat == ShadowMapFormat.Rg16)
            {
                Shader.EnableKeyword("RG16");
                Shader.DisableKeyword("RFLOAT");
                Shader.DisableKeyword("RGBA8");
            }

            _lightCamera.ResetWorldToCameraMatrix();
            _lightCamera.SetReplacementShader(_shadowMapCasterShader, null );
        }

        void OnPostRender()
        {
            if (_lightCamera == null || _shadowMapCasterShader == null)
                return;

            _lightSpaceMatrix = GL.GetGPUProjectionMatrix(_lightCamera.projectionMatrix, false);
            _lightSpaceMatrix = _lightSpaceMatrix * _lightCamera.worldToCameraMatrix;
            _lightDir = _myTransform.forward;
        }

        void CameraSetting()
        {
            if (_lightCamera == null)
            {
                _lightCamera = GetComponent<Camera>();
                _lightCamera.depth = -1000;
                _lightCamera.backgroundColor = Color.white;
                _lightCamera.clearFlags = CameraClearFlags.SolidColor;
                _lightCamera.orthographic = true;
                _lightCamera.orthographicSize = 10;
                _lightCamera.nearClipPlane = 0.001f;
                _lightCamera.farClipPlane = 20;
                _lightCamera.cullingMask = _layerMask;
                _lightCamera.useOcclusionCulling = false;
                _lightCamera.allowHDR = false;
                _lightCamera.allowMSAA = false;
                _lightCamera.allowDynamicResolution = false;
            }
        }

        void CreateShadowMap()
        {
            int size = (int)_quailty;
            if (_shadowMapRenderTarget is null || _shadowMapRenderTarget.width != size)
            {
                if (!(_shadowMapRenderTarget is null))
                {
                    RenderTexture.ReleaseTemporary(_shadowMapRenderTarget);
                }

                if (SystemInfo.SupportsRenderTextureFormat((RenderTextureFormat)_shadowMapFormat))
                {
                    _shadowMapRenderTarget = RenderTexture.GetTemporary(size, size, 24, (RenderTextureFormat)_shadowMapFormat);
                }

                if (_shadowMapRenderTarget == null)
                {
                    _shadowMapFormat = ShadowMapFormat.Rgba;
                    _shadowMapRenderTarget = RenderTexture.GetTemporary(size, size, 24, RenderTextureFormat.ARGB32);
                }

                if (_shadowMapRenderTarget != null)
                {
                    _shadowMapRenderTarget.wrapMode = TextureWrapMode.Clamp;
                    _shadowMapRenderTarget.filterMode = FilterMode.Bilinear;
                    _shadowMapRenderTarget.autoGenerateMips = false;
                    _shadowMapRenderTarget.useMipMap = false;
                    _lightCamera.targetTexture = _shadowMapRenderTarget;
                }
            }
        }

        public void AddLightSource(Transform lightTransform)
        {
            if (lightTransform is null)
                return;

            if (_lightSources is null)
            {
                _lightSources = new List<Transform>();
            }

            _lightSources.Add(lightTransform);
        }

        public void RemoveLightSource(Transform lightTransform)
        {
            if (lightTransform is null)
                return;

            if (_lightSources is null)
                return;

            if (_lightSources.Contains(lightTransform))
                _lightSources.Remove(lightTransform);
        }

#if UNITY_EDITOR
            void OnValidate()
        {
            if (UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode)
                return;

            Awake();
        }

        void OnDrawGizmos()
        {
            if (_lightCamera == null)
                return;

            Gizmos.color = Color.cyan;
            float size = _lightCamera.orthographicSize;

            float near = _lightCamera.nearClipPlane;
            float far = _lightCamera.farClipPlane;
            Vector3 pos = transform.position;
            Vector3 up = transform.up;
            Vector3 forward = transform.forward;
            Vector3 right = transform.right;

            Vector3 tln = pos + forward * near - right * size + up * size;
            Vector3 bln = pos + forward * near - right * size - up * size;

            Vector3 trn = pos + forward * near + right * size + up * size;
            Vector3 brn = pos + forward * near + right * size - up * size;

            Vector3 tlf = tln + forward * far - forward * near;
            Vector3 blf = bln + forward * far - forward * near;

            Vector3 trf = trn + forward * far - forward * near;
            Vector3 brf = brn + forward * far - forward * near;

            // near
            Gizmos.DrawLine(bln, tln);
            Gizmos.DrawLine(tln, trn);
            Gizmos.DrawLine(trn, brn);
            Gizmos.DrawLine(brn, bln);
            // left
            Gizmos.DrawLine(tln, tlf);
            Gizmos.DrawLine(bln, blf);
            // right
            Gizmos.DrawLine(trn, trf);
            Gizmos.DrawLine(brn, brf);
            // far
            Gizmos.DrawLine(blf, tlf);
            Gizmos.DrawLine(tlf, trf);
            Gizmos.DrawLine(trf, brf);
            Gizmos.DrawLine(brf, blf);
        }
#endif
    }
}