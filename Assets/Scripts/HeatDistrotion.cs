using System;
using UnityEngine;
using UnityEngine.Rendering.PostProcessing;

namespace Sigono.Framework
{
    [Serializable]
    [PostProcess(typeof(HeatDistrotionRenderer), PostProcessEvent.AfterStack, "LINK/HeatDistrotion")]
    public class HeatDistrotion : PostProcessEffectSettings
    {
        [Range(0.0f, 1.0f), Tooltip("Split RGB")]
        public FloatParameter splitRgb = new FloatParameter { value = 0.05f };

        [Range(0.0f, 1.0f), Tooltip("Strength")]
        public FloatParameter strength = new FloatParameter { value = 0.2f };

        public TextureParameter noiseTex = new TextureParameter { defaultState = TextureParameterDefault.Black };
    }

    public sealed class HeatDistrotionRenderer : PostProcessEffectRenderer<HeatDistrotion>
    {
        Shader _shader = Shader.Find("LINK/Post-Process/HeatDistrotion");

        public override void Render(PostProcessRenderContext context)
        {
            if (_shader == null || context == null)
                return;

            PropertySheet propertySheet = context.propertySheets.Get(_shader);
            if (propertySheet == null)
                return;

            propertySheet.properties.SetFloat("_SplitRGB", settings.splitRgb);
            propertySheet.properties.SetFloat("_Strength", settings.strength);

            Texture texParameter = settings.noiseTex.value;
            if (texParameter == null)
            {
                TextureParameterDefault def = settings.noiseTex.defaultState;
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
        }
    }
}