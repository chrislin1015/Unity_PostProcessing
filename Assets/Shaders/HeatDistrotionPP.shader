Shader "LINK/Post-Process/HeatDistrotion"
{
    Properties
    {
        _SplitRGB("Split RGB", Float) = 0.005
        _Strength("Strength", Float) = 0.2
        _NoiseTex("Noise Texture", 2D) = "" {}
    }

    HLSLINCLUDE

    #include "Packages/com.unity.postprocessing/PostProcessing/Shaders/StdLib.hlsl"

    TEXTURE2D_SAMPLER2D(_MainTex, sampler_MainTex);
    TEXTURE2D_SAMPLER2D(_NoiseTex, sampler_NoiseTex);
    uniform float _SplitRGB;
    uniform float _Strength;

    float4 Frag(VaryingsDefault i) : SV_Target
    {
        float2 noisePan = i.texcoord + _Time.y * float2(0, -0.2);
        float3 noise = SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, noisePan);

        float2 screenUV = float2(((noise.r * 0.2 + -0.1) * _Strength), ((noise.r * 0.2 + -0.1) * _Strength)) + i.texcoord;

        _SplitRGB *= 0.01;
        float2 splitRUV = screenUV + float2(_SplitRGB, _SplitRGB);
        float2 splitGUV = screenUV + float2(_SplitRGB, -_SplitRGB);
        float2 splitBUV = screenUV + float2(-_SplitRGB, -_SplitRGB);

        float r = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, splitRUV).r;
        float g = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, splitGUV).g;
        float b = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, splitBUV).b;

        float4 color = float4(r, g, b, 1.0);

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
