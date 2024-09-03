Shader "LINK/Post-Process/AreaLight"
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
    uniform float4x4 _ViewProjectInverse;
    uniform float4x4 _InverseViewMatrix;
    uniform float4x4 _InverseProjectionMatrix;

    uniform int _LightCount;
    uniform float _Strength;

    //int MAX_LIGHT_COUNT = 8;

    //x = position.x, y = position.y, z = position.z, w = lighttype
    //LightType : Spot = 0, Directional = 1, Point = 2, Area = 3, Rectangle = 3, Disc = 4
    uniform float4 _LightPosition[16];

    uniform float4x4 _LightInverseMatrix[16];
    uniform float3 _LightDir[16];

    //x = light.range, y = light.areaSize.x(widtg), z = light.areaSize.y, w = light.bounceIntensity
    uniform float4 _LightParameter[16];

    //x = light.color.r, y = light.color.g, z = light.color.b, w = light.intensity
    uniform float4 _LightColor[16];

    /*uniform float4 _ShadowColor;
    uniform float  _ShadowStrength;
    TEXTURE2D_SAMPLER2D(_CustomShadowMap, sampler_CustomShadowMap);                 // shadow map 纹理
    uniform float4x4 _CustomShadowMapLightSpaceMatrix;  // shadow map 光源空间矩阵
    uniform float _ShadowBias;
    uniform float _ShadowPCFSpread;*/

    float DecodeFloatRG( float2 enc )
    {
	    float2 kDecodeDot = float2(1.0, 1.0/255.0);
	    return dot( enc, kDecodeDot );
    }

    float3 DecodeViewNormal( float4 enc4 )
    {
	    float kScale = 1.7777;
	    float3 nn = enc4.xyz*float3(2*kScale,2*kScale,0) + float3(-kScale,-kScale,1);
	    float g = 2.0 / dot(nn.xyz,nn.xyz);
	    float3 n;
	    n.xy = g*nn.xy;
	    n.z = g-1;
	    return n;
    }

    void DecodeDepthNormal( float4 enc, out float depth, out float3 normal )
    {
	    depth = DecodeFloatRG (enc.zw);
	    normal = DecodeViewNormal(enc);
    }

    //Returns World Position of a pixel from clipspace depth map
    //float4 SamplePositionMap (float2 uvCoord)
    //{
    //    float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, uvCoord);
    //    // H is the viewport position at this pixel in the range -1 to 1.
    //    float4 H = float4((uvCoord.x) * 2 - 1, (uvCoord.y) * 2 - 1, depth, 1.0);
    //    float4 D = mul(_ViewProjectInverse, H);
    //    return D;// / D.w;
    //}

    float3 GetWorldSpacePosition(float2 uv)
    {
        //float depth = _CameraDepthTexture.SampleLevel(sampler_CameraDepthTexture, UnityStereoTransformScreenSpaceTex(uv), 0).r;
        float depth = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, uv).r;
        float4 result = mul(_ViewProjectInverse, float4(2.0 * uv - 1.0, depth, 1.0));
        return result.xyz / result.w;
    }

    void GetViewSpacePositionByDepthNormal(float2 uv, out half outDepth, out half3 outNormal)
    {
        half4 depthnormal = SAMPLE_TEXTURE2D(_CameraDepthNormalsTexture, sampler_CameraDepthNormalsTexture, uv);
        //float4 depthnormal = _CameraDepthNormalsTexture.SampleLevel(sampler_CameraDepthNormalsTexture, UnityStereoTransformScreenSpaceTex(uv), 0);
        DecodeDepthNormal(depthnormal, outDepth, outNormal);
        //outDepth = Linear01Depth(outDepth);
        //float4 result = mul(_InverseProjectionMatrix, float4(2.0 * uv - 1.0, outDepth, 1.0));
        //return result.xyz / result.w;
    }

    half LightAttenuation(float4 lightparameter, float3 wtolpos, float intensity)
    {
        half attenuation = 1;
        float3 abstemp = abs(wtolpos);
        half len = length(wtolpos);

        half indirect = pow(lightparameter.a, 1);

        half minwidth = lightparameter.y * 0.5;
        half minheithg = lightparameter.z * 0.5;
        half minrange = 0;
        half maxwidth = lightparameter.y + indirect;
        half maxheight = lightparameter.z + indirect;
        half maxrange = pow(lightparameter.x, 0.5) + indirect;

        half xa = 1.0 - smoothstep(minwidth, maxwidth, abstemp.x);
        half ya = 1.0 - smoothstep(minheithg, maxheight, abstemp.y);
        half za = 1.0 - smoothstep(minrange, maxrange, abstemp.z);
        half minv = min(minwidth, minrange);
        half maxv = max(maxwidth, maxrange);
        half lena = 1 - smoothstep(min(maxrange, intensity + indirect), maxrange + indirect, len);

        attenuation = xa * ya * za;
        return attenuation;
    }

    half LightAttenuation2(float4 lightparameter, float3 wtolpos, float intensity)
    {
        half attenuation = 1;
        float3 abstemp = abs(wtolpos);
        half len = length(wtolpos);

        half indirect = pow(lightparameter.a, 0.5);

        half minwidth = 0;
        half minheithg = 0;
        half minrange = 0;

        half sss = pow(lightparameter.y * lightparameter.z, 0.25);

        half maxwidth = pow(lightparameter.y, 0.5) + indirect;
        half maxheight = pow(lightparameter.z, 0.5) + indirect;
        half maxrange = pow(lightparameter.x, 0.5) + indirect;

        half xa = 1.0 - smoothstep(minwidth, maxwidth, abstemp.x);
        half ya = 1.0 - smoothstep(minheithg, maxheight, abstemp.y);
        half za = 1.0 - smoothstep(0, maxrange, abstemp.z);

        half lena = 1.0 - pow(smoothstep(0, lightparameter.x * sss, len), 0.1);

        attenuation = (xa*ya*za) + lena;

        return attenuation;
    }

    half DiscLightAttenuation(float4 lightparameter, float3 wtolpos)
    {
        half attenuation = 1;
        half len = length(wtolpos);

        half minwidth = lightparameter.y * 0.5;
        half minrange = lightparameter.x * 0.5;
        half maxwidth = lightparameter.y * 1.0 + lightparameter.a;
        half maxrange = lightparameter.x * 1.0 + lightparameter.a;

        half minv = min(minwidth, minrange);
        half maxv = max(maxwidth, maxrange);
        attenuation = 1.0 - smoothstep(minv, maxv, len);
        return attenuation;
    }

    half PointLightAttenuation(float4 lightparameter, float3 wtolpos)
    {
        half len = length(wtolpos);
        half attenuation = pow(1 - smoothstep(0, lightparameter.x, len), 1.0);
        return attenuation;
    }

    half GetExposureMultiplier(half avgLuminance)
    {
        avgLuminance = max(EPSILON, avgLuminance);
        half keyValue = 1.03 - (2.0 / (2.0 + log2(avgLuminance + 1.0)));
        half exposure = keyValue / avgLuminance;
        return exposure;
    }

/*
    float3 ShadowAtten(float4 worldPos, float lum)
    {
        float4 shadowCoord = mul(_CustomShadowMapLightSpaceMatrix, worldPos);
        float2 uv =  shadowCoord.xy / shadowCoord.w;
        uv = uv * 0.5 + 0.5;

        if (uv.x > 1 || uv.y > 1 || uv.x < 0 || uv.y < 0)
            return float3(1, 1, 1);

        float fragDepth = shadowCoord.z / shadowCoord.w;
#if defined (SHADER_TARGET_GLSL)
        fragDepth = fragDepth * 0.5 + 0.5; // (-1,1)->(0,1)
#elif defined (UNITY_REVERSED_Z)
        fragDepth = 1 - fragDepth; // (1,0)->(0,1)
#endif

#if (PCF_SHADOW)
        float atten = 1;
        float2 offset = 0;
        float minus_step = _ShadowStrength / 9.0;
        for(int i = -1; i < 2; ++i)
        {
            for(int j = -1; j < 2; ++j)
            {
                offset = float2(i, j) * _ShadowPCFSpread;
                float shadowMapDepth = DecodeFloatRG(SAMPLE_TEXTURE2D(_CustomShadowMap, sampler_CustomShadowMap, uv + offset).xy);
                if (fragDepth - _ShadowBias > shadowMapDepth)
                {
                    atten -= minus_step;
                }
            }
        }
#else
        float shadowMapDepth = DecodeFloatRG(SAMPLE_TEXTURE2D(_CustomShadowMap, sampler_CustomShadowMap, uv));//tex2D(_CustomShadowMap, uv).xy);
        float atten = 1;
        if (fragDepth - _ShadowBias > shadowMapDepth)
        {
            atten = lerp(1, 0, _ShadowStrength + lum);
        }
#endif

        return lerp(_ShadowColor, float3(1, 1, 1), atten);//fragDepth;//atten;
    }
*/

    half4 Frag(VaryingsDefault inputData) : SV_Target
    {
        half3 normal;
        float depth;
        GetViewSpacePositionByDepthNormal(inputData.texcoord, depth, normal);
        half3 worldNormal = mul((float3x3)_InverseViewMatrix, normalize(normal));
        float3 worldPosition = GetWorldSpacePosition(inputData.texcoord);//mul(_InverseViewMatrix, float4(GetWorldSpacePosition(inputData.texcoord), 1.0));//mul(_InverseViewMatrix, float4(position, 1.0));

        half4 color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, inputData.texcoord);

        half3 flatWorldNormal = normalize(cross( ddy( worldPosition ), ddx( worldPosition ) ) );

        //half nn = saturate(dot(flatWorldNormal, float3(0, 0, -1)));
//#if (SCREEN_SPACE_SHADOW_MAP)        
//        half l = Luminance(color.xyz);
//        color.xyz *= ShadowAtten(worldPosition, l);//inputData.texcoord);// * _ShadowColor;
//#endif

        half4 finalColor = 0;
        for (int j = 0; j < _LightCount; ++j)
        {
            half attenuation = 0;
            half3 ldir = _LightPosition[j].xyz - worldPosition.xyz;
            
            float4 wtolpos = mul(_LightInverseMatrix[j], float4(worldPosition.xyz, 1.0));

            ldir = normalize(ldir);

            half ndotl = saturate(dot(worldNormal, ldir));//smoothstep(-0.1, 1, dot(worldNormal, ldir));
            ndotl += saturate(dot(flatWorldNormal, ldir));
            ndotl *= 0.5;

            if (_LightPosition[j].w == 2)
            {
                attenuation = PointLightAttenuation(_LightParameter[j], wtolpos);
                finalColor.xyz += attenuation * (ndotl) * _LightColor[j].rgb * _LightColor[j].a;
            }
            else
            {
                half ldirDot = pow(smoothstep(0.1, 1, dot(_LightDir[j].xyz, -ldir)), 0.5);
                half3 ldirrt = (_LightPosition[j].xyz + float3(_LightParameter[j].yz, 0)) - worldPosition.xyz;
                half3 ldirlb = (_LightPosition[j].xyz + float3(-_LightParameter[j].yz, 0)) - worldPosition.xyz;

                half ndotllt = smoothstep(-0.1, 1, dot(worldNormal, ldirrt));
                half ndotlrb = smoothstep(-0.1, 1, dot(worldNormal, ldirlb));
                ndotl = (ndotl + ndotllt + ndotlrb) / 3;

                if (_LightPosition[j].w == 3)
                    attenuation = LightAttenuation2(_LightParameter[j], wtolpos, _LightColor[j].a);
                else if (_LightPosition[j].w == 4)
                    attenuation = DiscLightAttenuation(_LightParameter[j], wtolpos);

                finalColor.xyz += attenuation * (ndotl * ldirDot) * _LightColor[j].rgb * _LightColor[j].a;
            }
        }

        //return half4(saturate(finalColor.xyz), 1);
#if (REALTIMEL_LIGHT)
        half lum = Luminance(finalColor.xyz);
        half expo = GetExposureMultiplier(lum);
        //finalColor.xyz = NeutralTonemap(finalColor.xyz);
        finalColor.xyz = finalColor.xyz * (_Strength + expo/*(lum * expo)*/) * color.xyz;
#else
        finalColor.xyz *= color.xyz;
#endif

        finalColor.xyz += color.xyz;// * saturate(dot(flatWorldNormal, float3(0, 0, -1)));

        return half4(saturate(finalColor.xyz), 1);
    }

    ENDHLSL

    SubShader
    {
        // No culling or depth
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            HLSLPROGRAM
            #pragma target 4.0
            #pragma vertex VertDefault
            #pragma fragment Frag
            #pragma multi_compile _ REALTIMEL_LIGHT
            //#pragma multi_compile _ SCREEN_SPACE_SHADOW_MAP
            //#pragma multi_compile _ PCF_SHADOW
            #define SOURCE_DEPTHNORMALS
            ENDHLSL
        }
    }
}
