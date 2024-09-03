using System;
using UnityEngine;
using UnityEngine.Rendering.PostProcessing;

[Serializable]
[PostProcess(typeof(DirectionalBlurRenderer), PostProcessEvent.AfterStack, "LINK/DirectionalBlur")]
public class DirectionalBlur : PostProcessEffectSettings
{
    //public Shader shader;
    public Vector2Parameter direction = new Vector2Parameter { value = new Vector2(0.0f, 0.0f) };

    public Vector2Parameter depthRange = new Vector2Parameter { value = new Vector2(0.0f, 0.0f) };

    [Range(0.0f, 10.0f), Tooltip("Samples")]
    public IntParameter samples = new IntParameter { value = 0 };

    [Range(0.0f, 1.0f), Tooltip("Strength")]
    public FloatParameter strength = new FloatParameter { value = 0.1f };

    [Range(0.0f, 3.0f), Tooltip("Flow Speed")]
    public FloatParameter flowSpeed = new FloatParameter { value = 1.0f };

    public TextureParameter flowTex = new TextureParameter { defaultState = TextureParameterDefault.White };
}

[UnityEngine.Scripting.Preserve]
public sealed class DirectionalBlurRenderer : PostProcessEffectRenderer<DirectionalBlur>
{
    Shader _shader = Shader.Find("LINK/Post-Process/DirectionalBlur");

    public override DepthTextureMode GetCameraFlags()
    {
        return DepthTextureMode.Depth;
    }

    public override void Render(PostProcessRenderContext context)
    {
        if (_shader == null || context == null)
            return;

        PropertySheet propertySheet = context.propertySheets.Get(_shader);
        if (propertySheet == null)
            return;

        UnityEngine.Rendering.CommandBuffer cmd = context.command;
        cmd.BeginSample("DirectionalBlur");

        Vector2 tempDir = new Vector2(settings.direction.value.x + 0.001f, settings.direction.value.y + 0.001f);
        tempDir.Normalize();
        propertySheet.properties.SetVector(
            "_DirectionDepth", 
            new Vector4(tempDir.x, tempDir.y, settings.depthRange.value.x, settings.depthRange.value.y));

        int tempSamples = Mathf.Abs(settings.samples);
        propertySheet.properties.SetInt("_Samples", tempSamples);

        float tempStrength = settings.strength * 0.01f;
        propertySheet.properties.SetFloat("_Strength", tempStrength);

        propertySheet.properties.SetFloat("_FlowSpeed", settings.flowSpeed);

        Texture texParameter = settings.flowTex.value;
        if (texParameter == null)
        {
            TextureParameterDefault def = settings.flowTex.defaultState;
            switch (def)
            {
                case TextureParameterDefault.Black:
                    texParameter = RuntimeUtilities.blackTexture;
                    break;
                case TextureParameterDefault.White:
                    texParameter = RuntimeUtilities.whiteTexture;
                    break;
                case TextureParameterDefault.Transparent:
                    texParameter = RuntimeUtilities.transparentTexture;
                    break;
            }
        }
        propertySheet.properties.SetTexture("_NoiseTex", texParameter);
        context.command.BlitFullscreenTriangle(context.source, context.destination, propertySheet, 0);

        cmd.EndSample("DirectionalBlur");
    }
}