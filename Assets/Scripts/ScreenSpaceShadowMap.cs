using System;
using UnityEngine;
using UnityEngine.Rendering.PostProcessing;

namespace LINKernel
{
    [Serializable]
    [PostProcess(typeof(ScreenSpaceShadowMapRenderer), PostProcessEvent.BeforeTransparent, "LINK/SSSM")]
    public class ScreenSpaceShadowMap : PostProcessEffectSettings
    {
        [DisplayName("PCF Shadow")]
        public BoolParameter isBlur = new BoolParameter { value = false };

        [DisplayName("Color")]
        public ColorParameter shadowColor = new ColorParameter { value = Color.gray };

        [Range(0.0f, 1.0f), Tooltip("Strength")]
        public FloatParameter strength = new FloatParameter { value = 0.5f };

        [Range(0.001f, 0.1f)]
        public FloatParameter shadowBias = new FloatParameter { value = 0.05f };

        [Range(0.001f, 0.005f)]
        public FloatParameter shadowPcfSpread = new FloatParameter { value = 0.001f };
    }

    public class ScreenSpaceShadowMapRenderer : PostProcessEffectRenderer<ScreenSpaceShadowMap>
    {
        Shader _shader = Shader.Find("LINK/Post-Process/ScreenSpaceShadowMap");

        public override DepthTextureMode GetCameraFlags()
        {
            return DepthTextureMode.DepthNormals | DepthTextureMode.Depth;
        }

        public override void Render(PostProcessRenderContext context)
        {
#if UNITY_EDITOR
            if (!Application.isPlaying)
                return;
#endif
            if (ShadowMapCaster.shadowMapRenderTarget == null)
                return;

            if (_shader == null || context == null)
                return;

            PropertySheet propertySheet = context.propertySheets.Get(_shader);
            if (propertySheet == null)
                return;

            propertySheet.ClearKeywords();
            Matrix4x4 projectionMatrix = GL.GetGPUProjectionMatrix(context.camera.projectionMatrix, false);
            propertySheet.properties.SetMatrix(Shader.PropertyToID("_InverseProjectionMatrix"), projectionMatrix.inverse);
            propertySheet.properties.SetMatrix(Shader.PropertyToID("_InverseViewMatrix"), context.camera.cameraToWorldMatrix);
            propertySheet.properties.SetMatrix(Shader.PropertyToID("_InverseViewProjectionMatrix"), Matrix4x4.Inverse(projectionMatrix * context.camera.worldToCameraMatrix));

            if (settings.isBlur.value)
            {
                propertySheet.EnableKeyword("PCF_SHADOW");
            }
            else
            {
                propertySheet.DisableKeyword("PCF_SHADOW");
            }
            propertySheet.properties.SetMatrix("_CustomShadowMapLightSpaceMatrix", ShadowMapCaster.lightSpaceMatrix);
            propertySheet.properties.SetColor("_ShadowColor", settings.shadowColor.value);
            propertySheet.properties.SetFloat("_ShadowStrength", settings.strength.value);
            propertySheet.properties.SetTexture("_CustomShadowMap", ShadowMapCaster.shadowMapRenderTarget);
            propertySheet.properties.SetFloat("_ShadowBias", settings.shadowBias.value);
            propertySheet.properties.SetFloat("_ShadowPCFSpread", settings.shadowPcfSpread.value);
            propertySheet.properties.SetVector("_LightDir", ShadowMapCaster.lightDir);

            context.command.BlitFullscreenTriangle(context.source, context.destination, propertySheet, 0);
        }
    }
}