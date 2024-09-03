using System;
using UnityEngine;
using UnityEngine.Rendering.PostProcessing;

[Serializable]
[PostProcess(typeof(RadialBlurPpRenderer), PostProcessEvent.BeforeStack, "LINK/RadialBlur")]
public class RadialBlurPostProcess : PostProcessEffectSettings
{
    public Vector2Parameter center = new Vector2Parameter { value = new Vector2(0.5f, 0.5f) };

    [Range(0.0f, 2.0f), Tooltip("Sample Dist")]
    public FloatParameter dist = new FloatParameter { value = 1.0f };

    [Range(0.0f, 10.0f), Tooltip("Sample Strength")]
    public FloatParameter strength = new FloatParameter { value = 2.2f };
}

public sealed class RadialBlurPpRenderer : PostProcessEffectRenderer<RadialBlurPostProcess>
{
    Shader _shader = Shader.Find("LINK/Post-Process/RadialBlur");

    public override void Render(PostProcessRenderContext context)
    {
        if (_shader == null || context == null)
            return;

        PropertySheet propertySheet = context.propertySheets.Get(_shader);
        if (propertySheet == null)
            return;

        propertySheet.properties.SetVector("_Center",
            new Vector4(settings.center.value.x, settings.center.value.y, 0.0f, 0.0f));
        propertySheet.properties.SetFloat("_Dist", settings.dist);
        propertySheet.properties.SetFloat("_Strength", settings.strength);
        context.command.BlitFullscreenTriangle(context.source, context.destination, propertySheet, 0);
    }
}