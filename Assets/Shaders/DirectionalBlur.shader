Shader "LINK/Post-Process/DirectionalBlur"
{
    Properties
    {
        _DirectionDepth ("DirectionDepth", Vector) = (0, 0, 0, 0)
        _Samples ("Samples", Int) = 0
        _Strength ("Strength", Float) = 0.1
        _FlowSpeed ("Flow Speed", Float) = 1.0
        _NoiseTex("Noise Texture", 2D) = "white" {}
    }

    HLSLINCLUDE

    #include "Packages/com.unity.postprocessing/PostProcessing/Shaders/StdLib.hlsl"

    TEXTURE2D_SAMPLER2D(_MainTex, sampler_MainTex);
    TEXTURE2D_SAMPLER2D(_CameraDepthTexture, sampler_CameraDepthTexture);
    TEXTURE2D_SAMPLER2D(_NoiseTex, sampler_NoiseTex);
    uniform float4 _DirectionDepth;
    uniform int _Samples;
    uniform float _Strength;
    uniform float _FlowSpeed;

    float4 Frag(VaryingsDefault i) : SV_Target
    {
        //float depth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, i.texcoord).r);
        //float d = saturate(sign(depth - _DirectionDepth.z) + sign(_DirectionDepth.w - depth));

        float2 dir = normalize(_DirectionDepth.xy);
        float4 color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord);

        float2 flowuv = i.texcoord.xy + _Time.y * -dir * _FlowSpeed;
        if (dir.x > 0.0 || dir.y > 0.0)
        {
            float2x2 rotationMatrix = float2x2( dir.x, -dir.y, dir.y, dir.x);
            flowuv = mul( flowuv.xy, rotationMatrix );
        }
        float3 noise = SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, flowuv);

        UNITY_LOOP
        for (int k = -_Samples; k < _Samples; k++)
        {
            float2 uv = i.texcoord - (dir * k * _Strength * noise.x);
            color += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv);
        }
        
        return color / ((_Samples * 2) + 1);
    }

    ENDHLSL

    SubShader
    {
        // No culling or depth
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex VertDefault
            #pragma fragment Frag
            ENDHLSL
        }
    }
}
