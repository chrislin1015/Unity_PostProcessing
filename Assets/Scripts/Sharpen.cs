using System;
using UnityEngine;
using UnityEngine.Rendering.PostProcessing;

public enum QualityType
{
    Low,
    High
}

[Serializable] public sealed class QualityTypeParameter : ParameterOverride<QualityType> { }

[Serializable]
[PostProcess(typeof(SharpenRenderer), PostProcessEvent.BeforeTransparent, "LINK/Sharpen")]
public class Sharpen : PostProcessEffectSettings
{
    public Vector4Parameter parameters = new Vector4Parameter { value = new Vector4(0.6f, 0.05f, 1.0f, 1.0f) };

    public BoolParameter isAntiAliasing = new BoolParameter { value = true };

    [DisplayName("Quality Type")]
    public QualityTypeParameter qualityTypeParameter = new QualityTypeParameter { value = QualityType.Low };

    [Range(0.0f, 1.0f), Tooltip("Edge")] public FloatParameter edge = new FloatParameter { value = 1.0f };

    [Range(0.01f, 1.0f), Tooltip("Threshold")]
    public FloatParameter threshold = new FloatParameter { value = 0.1f };

    [Range(0.0312f, 0.0833f), Tooltip("Contrast Threshold")]
    public FloatParameter contrastThreshold = new FloatParameter { value = 0.05f };

    [Range(0.063f, 0.333f), Tooltip("Relative Threshold")]
    public FloatParameter relativeThreshold = new FloatParameter { value = 0.163f };

    [HideInInspector] [Range(0.0f, 1.0f), Tooltip("Compare Slider")]
    public FloatParameter compareSlider = new FloatParameter { value = 1.0f };

    public BoolParameter fixedParameter = new BoolParameter { value = true };
}

public sealed class SharpenRenderer : PostProcessEffectRenderer<Sharpen>
{
    [SerializeField] Camera _camera;
    Shader _shader = Shader.Find("LINK/Post-Process/Sharpen");
    RenderTexture _renderTexture = null;

    public override DepthTextureMode GetCameraFlags()
    {
        return DepthTextureMode.DepthNormals;
    }

    public override void Init()
    {
        if (_camera != null)
        {
            _renderTexture = _camera.targetTexture;
        }
    }

    public override void Render(PostProcessRenderContext context)
    {
        if (_shader == null || context == null)
            return;

        PropertySheet propertySheet = context.propertySheets.Get(_shader);
        if (propertySheet == null)
            return;

        propertySheet.ClearKeywords();

        if (settings.isAntiAliasing.value)
            propertySheet.EnableKeyword("AA_ENABLE");
        else
            propertySheet.DisableKeyword("AA_ENABLE");

        if (settings.qualityTypeParameter.value == QualityType.Low)
        {
            propertySheet.EnableKeyword("LOW_Q");
            propertySheet.DisableKeyword("HIGH_Q");
        }
        else if (settings.qualityTypeParameter.value == QualityType.High)
        {
            propertySheet.EnableKeyword("HIGH_Q");
            propertySheet.DisableKeyword("LOW_Q");
        }
        else
        {
            propertySheet.DisableKeyword("LOW_Q");
            propertySheet.DisableKeyword("HIGH_Q");
        }

        float px = (1.0f / (float)Screen.width) * settings.parameters.value.z;
        float py = (1.0f / (float)Screen.height) * settings.parameters.value.w;
        if (_renderTexture != null)
        {
            propertySheet.properties.SetVector("_MainTex_TexelSize",
                new Vector4(1.0f / _renderTexture.width, 1.0f / _renderTexture.height, 0, 0));
            px = (1.0f / (float)_renderTexture.width) * settings.parameters.value.z;
            py = (1.0f / (float)_renderTexture.height) * settings.parameters.value.w;
        }
        else
            propertySheet.properties.SetVector("_MainTex_TexelSize", new Vector4(1.0f / 1920.0f, 1.0f / 1080.0f, 0, 0));

        propertySheet.properties.SetVector("_Params",
            new Vector4(settings.parameters.value.x, settings.parameters.value.y, px, py));

        propertySheet.properties.SetFloat("_Edge", settings.edge.value);
        if (settings.fixedParameter.value)
        {
            propertySheet.properties.SetFloat("_Threshold", 0.01f);
            propertySheet.properties.SetFloat("_ContrastThreshold", 0.0312f);
            propertySheet.properties.SetFloat("_RelativeThreshold", 0.063f);
        }
        else
        {
            propertySheet.properties.SetFloat("_Threshold", settings.threshold.value);
            propertySheet.properties.SetFloat("_ContrastThreshold", settings.contrastThreshold.value);
            propertySheet.properties.SetFloat("_RelativeThreshold", settings.relativeThreshold.value);
        }

        //propertySheet.properties.SetFloat("_CompareSlider", settings.compareSlider.value);

        context.command.BlitFullscreenTriangle(context.source, context.destination, propertySheet, 0);
    }
}