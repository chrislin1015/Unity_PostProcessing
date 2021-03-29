Shader "LINK/Post-Process/RadialBlur"
{
    Properties
    {
        _Center("Center", Vector) = (0.5, 0.5, 0.0, 0.0)
        _Dist("Dist", Float) = 1.0
        _Strength("Strength", Float) = 2.0
    }

    HLSLINCLUDE

    #include "Packages/com.unity.postprocessing/PostProcessing/Shaders/StdLib.hlsl"

    TEXTURE2D_SAMPLER2D(_MainTex, sampler_MainTex);
    uniform float2 _Center;
    uniform float _Dist;
    uniform float _Strength;

    float luminance(float4 color)
    {
        return 0.2125 * color.r + 0.7154 * color.g + 0.0721 * color.b;
    }

    float4 Frag(VaryingsDefault i) : SV_Target
    {
        float samples[10] = {-0.08, -0.05, -0.03, -0.02, -0.01, 0.01, 0.02, 0.03, 0.05, 0.08};
        float2 dir = _Center - i.texcoord;
        float dist = length(dir);
        dir = normalize(dir);

        float4 color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord);
        float4 sum = color;
        float lum = luminance(color);

        for (int j = 0; j < 10; ++j)
        {
            sum += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord + (dir * samples[j] * _Dist));
        }
        sum /= 11.0f;

        sum = pow(sum, clamp(1.0 - (lum), 0.5, 1.0));
        float t = clamp(dist * _Strength, 0.0f, 1.0f);
        color = lerp(color, sum, t);
        return color;
    }

    ENDHLSL

    SubShader
    {
        // No culling or depth
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            HLSLPROGRAM
            #pragma vertex VertDefault
            #pragma fragment Frag
            ENDHLSL
        }
    }
}
