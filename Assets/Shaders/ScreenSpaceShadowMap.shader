Shader "LINK/Post-Process/ScreenSpaceShadowMap"
{
    Properties
    {
    }

    HLSLINCLUDE

    #include "Packages/com.unity.postprocessing/PostProcessing/Shaders/StdLib.hlsl"
    #include "Packages/com.unity.postprocessing/PostProcessing/Shaders/Colors.hlsl"
    
    TEXTURE2D_SAMPLER2D(_MainTex, sampler_MainTex);
    TEXTURE2D_SAMPLER2D(_CameraDepthTexture, sampler_CameraDepthTexture);
    TEXTURE2D_SAMPLER2D(_CameraDepthNormalsTexture, sampler_CameraDepthNormalsTexture);
    uniform float4x4 _InverseViewMatrix;
    uniform float4x4 _InverseProjectionMatrix;
    uniform float4x4 _InverseViewProjectionMatrix;

    uniform float3 _LightDir;
    uniform float4 _ShadowColor;
    uniform float  _ShadowStrength;
    TEXTURE2D_SAMPLER2D(_CustomShadowMap, sampler_CustomShadowMap);
    uniform float4x4 _CustomShadowMapLightSpaceMatrix;
    uniform float _ShadowBias;
    uniform float _ShadowPCFSpread;

    float DecodeFloatRGBA(float4 enc)
    {
	    float4 kDecodeDot = float4(1.0, 1 / 255.0, 1 / 65025.0, 1 / 16581375.0);
	    return dot( enc, kDecodeDot );
    }

    half DecodeFloatRG(half2 enc)
    {
	    half2 kDecodeDot = half2(1.0, 1.0 / 255.0);
	    return dot( enc, kDecodeDot );
    }

    half3 DecodeViewNormal(half4 enc4)
    {
	    half kScale = 1.7777;
	    half3 nn = enc4.xyz * half3(2 * kScale, 2 * kScale, 0) + half3(-kScale, -kScale, 1);
	    half g = 2.0 / dot(nn.xyz,nn.xyz);
	    half3 n;
	    n.xy = g * nn.xy;
	    n.z = g - 1;
	    return n;
    }

    void DecodeDepthNormal( half4 enc, out half depth, out half3 normal )
    {
	    depth = DecodeFloatRG (enc.zw);
	    normal = DecodeViewNormal(enc);
    }

    float3 GetWorldSpacePosition(half2 uv)
    {
        float depth = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, uv).r;
        float4 result = mul(_InverseViewProjectionMatrix, float4(2.0 * uv - 1.0, depth, 1.0));
        return result.xyz / result.w;
    }

    void GetViewSpacePositionByDepthNormal(half2 uv, out half outDepth, out half3 outNormal)
    {
        half4 depthnormal = SAMPLE_TEXTURE2D(_CameraDepthNormalsTexture, sampler_CameraDepthNormalsTexture, uv);
        DecodeDepthNormal(depthnormal, outDepth, outNormal);
        outDepth = Linear01Depth(outDepth);
    }

    float SampleShadowMap(half2 uv)
    {
#if (RFLOAT)
        float shadowMapDepth = SAMPLE_TEXTURE2D(_CustomShadowMap, sampler_CustomShadowMap, uv).x;
#elif (RGBA8)
        float shadowMapDepth = DecodeFloatRGBA(SAMPLE_TEXTURE2D(_CustomShadowMap, sampler_CustomShadowMap, uv));
#elif (RG16)
        float shadowMapDepth = DecodeFloatRG(SAMPLE_TEXTURE2D(_CustomShadowMap, sampler_CustomShadowMap, uv).xy);
#else
        float shadowMapDepth = DecodeFloatRGBA(SAMPLE_TEXTURE2D(_CustomShadowMap, sampler_CustomShadowMap, uv));
#endif       

       return shadowMapDepth;
    }

    half3 ShadowAtten(float4 worldPos, half lum, half3 worldNormal)
    {
        float4 shadowCoord = mul(_CustomShadowMapLightSpaceMatrix, worldPos);
        half2 uv =  shadowCoord.xy / shadowCoord.w;
        uv = uv * 0.5 + 0.5;

        if (uv.x >= 1 || uv.y >= 1 || uv.x <= 0 || uv.y <= 0)
            return half3(1, 1, 1);

        float fragDepth = shadowCoord.z / shadowCoord.w;
#if defined(SHADER_API_GLES) || defined(SHADER_API_GLES3) || defined (SHADER_TARGET_GLSL)
        fragDepth = fragDepth * 0.5 + 0.5; // (-1,1)->(0,1)
#elif defined (UNITY_REVERSED_Z)
        fragDepth = 1 - fragDepth; // (1,0)->(0,1)
#endif

        if (fragDepth < 0 || fragDepth > 1)
            return half3(1, 1, 1);

        half wdy = saturate(dot(worldNormal, float3(0, 1, 0)));

#if (PCF_SHADOW)
        half atten = 1;
        half2 offset = 0;
        half minus_step = _ShadowStrength / 9.0;
        for(int i = -1; i < 2; ++i)
        {
            for(int j = -1; j < 2; ++j)
            {
                offset = uv + half2(i, j) * _ShadowPCFSpread;

                float shadowMapDepth = SampleShadowMap(offset);
                if (fragDepth - lerp(_ShadowBias, 0.001, wdy) > shadowMapDepth)
                {
                    atten -= minus_step;
                }
            }
        }
#else
        float shadowMapDepth = SampleShadowMap(uv);
        half atten = 1;
        if (fragDepth - lerp(_ShadowBias, 0.001, wdy) > shadowMapDepth)
        {
            atten = lerp(1, 0, _ShadowStrength + lum);
        }
#endif

        return lerp(half3(_ShadowColor.rgb), half3(1, 1, 1), atten);
    }

    half4 Frag(VaryingsDefault i) : SV_Target
    {
        half3 normal;
        half depth;
        GetViewSpacePositionByDepthNormal(i.texcoord, depth, normal);
        float3 position = GetWorldSpacePosition(i.texcoord);
        half3 worldNormal = mul((half3x3)_InverseViewMatrix, normalize(normal));

        half ndl = saturate(dot(worldNormal, -_LightDir));
         
        float4 worldPosition = float4(position, 1.0);

        half4 color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord);
     
        half l = Luminance(color.xyz);
        half3 sc = color.rgb * ShadowAtten(worldPosition, l, worldNormal);//i.texcoord);// * _ShadowColor;
        color.rgb = lerp(color.rgb, sc.rgb, ndl);
        return half4(color.rgb, 1);
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
            #pragma multi_compile _ PCF_SHADOW
            #pragma multi_compile _ RFLOAT RGBA8 RG16
            ENDHLSL
        }
    }
}
